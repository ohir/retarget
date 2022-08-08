//❌RT
/* Copyright © 2022 Wojciech S. Czarnecki aka Ohir Ripe. All Rights Reserved.
Below code is dual licensed either under CC BY-ND for the general population,
or under BSD 3-clause license for major sponsors of the "retarget" project.
Both licenses text is to be found in the LICENSE file.
...
If you, your team, or your company is shipping smaller and more robust Flutter
apps with retarget's help, please share a one programmer-hour per month to
support `retarget` maturing, and possibly my other future tools. Thank you.
Support links are avaliable at https://github.com/ohir/retarget project site */

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'retarget.dart';

const u8co = Utf8Codec(allowMalformed: true);

class Config {
  late final Uint64List _cconf; // codeconfig itself
  late final Uint8List _pglead; // pragma leads
  late final Uint8List bFlags; // condition flags
  late final Uint8List bTargt; // target
  late final int bTgtCR; // windows correction
  final Directory dir; // code tree root
  final Uint8List? clibuf; // !=null if data came from stdin
  final bool dry; // dry-run, no changes allowed
  final bool fixG; // fix guards (works only with clibuf)
  final bool loud; // make short messages on progress
  final bool force; // force *some* operations
  final bool diags; // return pragmas description for human use
  final bool silent; // supress even err diags, no one will watch em

  Config(
      {required CfgLines cfl,
      required this.dir,
      required this.clibuf,
      required this.dry,
      required this.fixG,
      required this.loud,
      required this.force,
      required this.diags,
      required this.silent}) {
    bTargt = cfl.targetPragma.toBytes();
    bTgtCR = (((bTargt.indexOf(124) + 1) << 7) | osCR) << 46; // compute once
    bFlags = cfl.selFlags.trim().toBytes();
    _pglead = '/////**/// !=%-+'.toBytes();
    _cconf = ByteData(cfl.actitems.length * 8).buffer.asUint64List();
    for (int i = 0; i < cfl.actitems.length; i++) {
      cconf[i] = cfl.actitems[i];
    } // cconf.forEach(((i) => print(i.toStrItem(wType: true))));
  }
  String? get stdinStr {
    return (clibuf == null) ? null : u8co.decoder.convert(clibuf!);
  }

  Uint8List get pglead => Uint8List.view(_pglead.buffer);
  //Uint64List get cconf => Uint64List.view(_cconf.buffer);
  Uint64List get cconf => Uint64List.view(_cconf.buffer);
  String get branch => cconf[0].toStrItem();

  /// returns null if iby is not known, then true if it is set
  bool? isNameSet(Uint8List iby) {
    if (iby.lengthInBytes > 7) return null;
    CfgItem ci = binItem(iby, 0);
    int i = ci.indexIn(cconf);
    if (i < 0) return null;
    return cconf[i].isCfgSet();
  }

  /// finds iby name in cconf, returns -1 if not found
  int ccIndexOf(Uint8List iby) {
    if (iby.lengthInBytes > 7) return -1;
    CfgItem ci = binItem(iby, 0);
    return ci.indexIn(cconf);
  }

  /// finds iby name in cconf, returns -1 if not found
  int ccIndexOfRange(Uint8List bu, int start, int end) {
    if (end - start > 7) return -1;
    int ite = 0;
    while (end > start) {
      end--;
      ite <<= 8;
      ite |= bu[end];
    }
    ite <<= 7;
    return ite.indexIn(Uint64List.view(cconf.buffer));
  }
} // class Config

int itemOfRange(Uint8List bu, int start, int end) {
  if (end - start > 7) return -1;
  int ite = 0;
  while (end > start) {
    end--;
    ite <<= 8;
    ite |= bu[end];
  }
  ite <<= 7;
  return ite;
}

int itemOfRangeNAC(Uint8List bu, int start, int end) {
  if (end - start > 7) return -1;
  int ite = 0;
  int c = 0;
  while (end > start) {
    end--;
    ite <<= 8;
    c = bu[end];
    if (c > 64 && c < 91) c |= 32; // lc
    ite |= c;
  }
  ite <<= 7;
  return ite;
}

int binItem(Uint8List bfo, int icf) {
  int ite = 0;
  for (int by in bfo.reversed) {
    ite <<= 8;
    ite |= by;
  }
  ite <<= 7;
  ite |= icf & 0x7f;
  return ite;
}

/// Check, clean and preprocess config lines from file. Lint for:
///  - uniqueness of configuration item names, as future code maintainer should
///    be spared guessing which 'linux' perpetes to this or that condition.
///  - equality of branches (all config pieces must be present on each)
///  - count of items (7) - also to guard future maintainers of a branched code
///  - length (7 bytes), to inform users of non-ascii scripts about limits.
///  - forced per-branch state (configured in retarget.flags) being respected
///  Not done: repeating contradictory predicates on a single cli line
///  Not done: Line with improper shape - to be seen when users start to put
///            unicorns on them ;)
class CfgLines {
  final String forbranch;
  final List<String> inli;
  final List<String> cli;
  final bool stub;
  final List<CfgItem> actitems = <CfgItem>[]; // just + or -, cli taken into
  final List<CfgItem> clitems = <CfgItem>[]; // CfgItems provided on cli
  final List<CfgItem> items = <CfgItem>[]; // current CfgItems
  final idseen = <String, int>{}; // seen identifiers, up to 7*8
  final curcon = <String, int>{}; // chosen branch configuration
  final curcln = <String>[]; // chosen branch lines
  final branches = <String>[];
  final StringBuffer err = StringBuffer(); // errors

  CfgLines(this.forbranch, this.inli, this.cli, this.stub) {
    final RegExp reCfg =
        RegExp(r'^([a-zA-Z0-9\u0080-\ufffe]+):\s+(([*+-=!.]).*)');

    // linter state to close over, linter itself works on a stream
    final StringBuffer uns = StringBuffer(); // unique strings check
    bool current = false;
    bool defseen = false;
    bool gotknob = false;
    int pbc = 0;
    void _clearLinter() {
      pbc = 0;
      uns.clear();
      gotknob = false;
      defseen = false;
    }

    // returns item massaged for human see, empty string on error
    String _lintItem(String id, int ln, {bool reg = false, bool cli = false}) {
      pbc++;
      CfgItem icf = ln << 7; // make room for type flagbits
      if (pbc > maxFlags) {
        err.writeln('  - [$ln] "$id" is a one too much (max is $maxFlags)');
      }
      if (!isLcAsciiOrUnicode(id)) {
        err.writeln(
            '  - [$ln] "$id" contains uppercase ascii, it might be confuding');
      }
      // ignore: unnecessary_string_interpolations
      var cid = '$id'; // real copy, please
      // spare | cffile |  code conf  | bucket of consts would make us none wiser
      //       | ! % =  |  +  -  *  .         2: * on knob is knob name
      //       | br fo  | 43 45 42 46         1:knob, variant has +-
      //     6 |  5  4  |  3  2  1  0         0:branch is 0
      // spare | 32 16  |  8  4  2  1         33! 37% 61=  force - * +
      var c0 = id.codeUnitAt(0); // register id type
      if (c0 == 61) icf |= 16 + 8; // +flag, =forced
      if (c0 == 33) icf |= 16 + 4; // -flag, !forced
      if (c0 == 37) icf |= 16 + 2; // *flag, *forced
      if (c0 == 43) icf |= 8; //      +flag
      if (c0 == 45) icf |= 4; //      -flag
      if (c0 == 42) icf |= 2; //      *flag
      var cs = 1; // one to strip
      if (c0 == 46) {
        c0 = id.codeUnitAt(1); //         .knob
        if (c0 == 61) icf |= 16 + 8; //  .=knob, forced default variant
        if (c0 == 33) icf |= 16 + 4; //  .!knob, forbidden variant
        if (c0 == 43) icf |= 8; //       .+knob, default variant
        if (c0 == 63) icf |= 2; //       .?knob, knob name
        if (icf & 127 != 0) {
          cs++; // two to strip
        } else if (cli) {
          icf |= 8; // .+knob - as given on a cli
        } else if (icf & 8 != 0) {
          icf |= 4; // .-knob
        }
        icf |= 1; // mark knob
        if (!cli && (c0 == 61 || c0 == 43)) {
          if (defseen) {
            err.writeln('  - [$ln] only single default variant can be set');
          }
          defseen = true;
        }
        if (c0 == 63) {
          if (!cli && gotknob) {
            err.writeln('  - [$ln] only single knob name can be set in line');
          }
          gotknob = true;
        }
        if (!gotknob) {
          err.writeln(
              '  - [$ln] knob name is not known (no .?name in defaults?)');
        }
        c0 = 46; // restore .
      }
      if (icf & 127 == 0) {
        err.writeln(
            '  - [$ln] invalid "$id" - it does not start with any of . ? + - * = !');
        cs = 0; // zero to strip, but it really should never happen
      }
      cid = cid.substring(cs);
      if (!isLcAsciiOrUnicode(cid)) {
        err.writeln('  - [$ln] "$id" contains uppercase ascii, its wrong');
      }
      var pre = idseen[cid];
      uns.write(cid);
      uns.writeCharCode(6);
      var bfo = cid.toBytes();
      CfgItem bItem = binItem(bfo, icf);
      if (bfo.lengthInBytes > maxFlagLen) {
        err.writeln('  - [$ln] "$id" has more bytes than $maxFlagLen!');
      } // max is 7, we do not want do utf8 transformations further in parser
      if (reg) {
        if (pre != null) {
          err.writeln(
              '  - [$ln] "$cid" not unique (previously seen in line ${pre >> 8})');
          return ''; // error;
        } else {
          idseen[cid] = icf;
          if (current) {
            curcon[cid] = bItem;
            items.add(bItem);
          }
        }
      } else if (cli) {
        if (cli && stub && cid == '*') {
          clitems.add(bItem); // allow for stub
        } else if (curcon[cid] == null) {
          err.writeln('  - [cli] "$cid" name is not recognized');
        } else {
          clitems.add(bItem);
        }
      } else if (current) {
        curcon[cid] = bItem;
        items.add(bItem);
      }
      return icf.toStrItem();
    }

    var cubra = '';
    final brseen = <String, int>{};
    final kfseen = <String>{};
    var brprev = '';
    var ckr = ''; // check results temp
    int cnt = 0;

    nextLine:
    for (var origline in inli) {
      cnt++;
      // ignore: unnecessary_string_interpolations
      var v = '$origline';
      if (v.isEmpty) continue;
      if (v.startsWith('--- END ---')) {
        // if (err.isNotEmpty) print(err);
        break; // unadevertised .flags breaker
      }
      final lparts = reCfg.matchAsPrefix(v);
      if (lparts == null) {
        continue nextLine;
      }
      // Oh dear Perl! How do I miss you... :((
      // $branch, $lnrest, $ofkind = v =~/(re)(ge)(xp)/;
      final branch = lparts.group(1)?.trimRight() ?? '';
      final lnrest = lparts.group(2)?.trimRight() ?? '';
      final ofkind = lparts.group(3)?.trimRight() ?? '';
      bool knob = ofkind.codeUnitAt(0) == 46; // should throw on a wrong RE

      // branch name lints
      if (branch.toBytes().lengthInBytes > maxFlagLen) {
        err.writeln(
            '  - [$cnt] "$branch" has more bytes than $maxFlagLen allowed');
      }
      if (branch != brprev) {
        branches.add(branch);
        current = branch == forbranch;
        var pbl = brseen[branch];
        if (pbl != null) {
          err.writeln(
              '  - [$cnt] duplicated definition for "$branch". Previous was at $pbl');
        } else {
          brseen[branch] = cnt;
        }
        if (current) {
          cubra = branch;
          CfgItem bi = branch.toCfgItem();
          curcon[branch] = bi;
          items.add(bi);
          if (curcln.isNotEmpty) {
            err.writeln(
                '  - [$cnt] spread "$branch" lines. Branch configs must be contignous');
          }
          if (knob) {
            err.writeln('  - [$cnt] "$branch" must define flags first');
          }
          curcln.add(origline);
        }
        brprev = branch;
      }

      // do lint
      _clearLinter();
      var jn = knob ? '' : ' ';
      var mb = branch == 'main';
      ckr = lnrest.split(' ').map((e) => _lintItem(e, cnt, reg: mb)).join(jn);
      if (knob && pbc < 3) {
        err.writeln(
            '  - [$cnt] too few knob variants. Switch needs at least 2 to work.');
      }
      if (knob && !defseen) {
        err.writeln(
            '  - [$cnt] No default variant marked for knob. Use + or = to mark default.');
      }
      if (kfseen.contains(uns.toString())) {
        if (mb) err.writeln('  - [$cnt] already defined: $ckr');
      } else {
        if (mb) {
          kfseen.add(uns.toString());
        } else {
          err.writeln('  - [$cnt] not in "main" template: $ckr');
        }
      }
    }
    if (cubra.isEmpty) {
      err.writeln('  - branch "$forbranch" is not configured yet');
      return;
    }

    _clearLinter();
    cnt = 0;
    for (var v in cli) {
      var cdot = v.split('.');
      if (cdot.length > 2) {
        err.writeln(
            '  - [cli] "$v" is wrong. Only single knob variant can be valid');
      } else if (cdot.length == 2 && cdot[0].isNotEmpty && cdot[1].isNotEmpty) {
        _lintItem('.?${cdot[0]}', cnt, cli: true);
        _lintItem('.${cdot[1]}', cnt, cli: true);
      } else if (v.contains('.')) {
        err.writeln('  - [cli] "$v" is wrong. Knob variant must be known');
      } else if (v.codeUnitAt(0) < 47 || v.codeUnitAt(0) == 61) {
        _lintItem(cdot[0], cnt, cli: true);
      } else {
        err.writeln('  - [cli] unrecognized name "$v"');
      }
    }
    // make actitems
    actitems.add((items.isNotEmpty) ? items[0] : 'invalid'.toCfgItem());
    foritems:
    for (var n = 1; n < items.length; n++) {
      CfgItem d = items[n];
      int i = d.indexIn(clitems);
      if (i < 0) {
        actitems.add(d.getClean()); // take default, remove forced
        continue;
      }
      var u = clitems[i];
      var kn = '';
      if (d.isKnobName() && i < clitems.length - 1 && n < items.length - 1) {
        actitems.add(d.getClean()); // add knob name
        u = clitems[i + 1]; // variant
        if (u.isForced()) {
          for (n++; n < items.length && items[n].isKnobVar(); n++) {
            if (u.isEqualTo(items[n])) {
              actitems.add(u.getAsSet()); // add active knob
            } else {
              actitems.add(items[n].getAsUnset()); // add inactive
            }
          }
          n--;
          continue foritems;
        }
        var forb = 0;
        var fdef = 0;
        var eq = 0;
        var k = n + 1;
        for (; k < items.length && items[k].isKnobVar(); k++) {
          var cuv = items[k];
          if (fdef == 0 && cuv.isKnobDef() && cuv.isForced()) fdef = cuv;
          if (forb == 0 &&
              cuv.isForced() &&
              cuv.isCfgUnset() &&
              cuv.isEqualTo(u)) {
            forb = cuv;
          }
          if (eq == 0 && cuv.isEqualTo(u)) eq = cuv;
        } // hereafter u is NOT forced
        if (fdef != 0) {
          kn = d.toStrItem(bare: true);
          err.writeln(
              '  - [cli] "$kn${fdef.toStrItem()}" is forced in "@$cubra"');
        } else if (forb != 0) {
          kn = d.toStrItem(bare: true);
          err.writeln(
              '  - [cli] "$kn${forb.toStrItem()}" may not be set for "@$cubra"');
        } else {
          for (n++; n < items.length && items[n].isKnobVar(); n++) {
            var cuv = items[n];
            if (cuv.isEqualTo(u)) {
              actitems.add(u);
              continue;
            }
            actitems.add(cuv.getAsUnset());
          }
          n--;
          continue foritems;
        } // fdef/forb not overriden = take defaults
        for (n++; n < items.length && items[n].isKnobVar(); n++) {
          actitems.add(items[n].getClean());
        }
        n--;
        continue foritems;
      } else if (!d.isForced()) {
        actitems.add(u.getClean()); // not forced - take it
      } else {
        if (u.isForced()) {
          actitems.add(u.getClean());
        } else if (!stub && u.isCfgFlux()) {
          err.writeln(
              '  - [cli] "${u.toStrItem()}" has meaning only in stubs. Use "+" or "-" for apply');
        } else if (u & 15 == d & 15) {
          actitems.add(d.getClean()); // both agree
        } else if (!stub && d.isCfgFlux() && !u.isCfgFlux()) {
          actitems.add(u.getClean());
        } else {
          if (d.isCfgSet() && u.isCfgUnset()) {
            err.writeln('  - [cli] "${d.toStrItem()}" must stay in "@$cubra"');
          } else if (d.isCfgUnset() && u.isCfgSet()) {
            err.writeln(
                '  - [cli] "${u.toStrItem()}" may not be set in "@$cubra"');
          } else if (stub && d.isCfgFlux() && !u.isCfgFlux()) {
            err.writeln(
                '  - [cli] "@$cubra" may not depend on "${d.toStrItem(bare: true)}"');
          } else {
            actitems.add(u.getClean()); // lints done, add item (then pray ;)
          }
        }
      }
    }
    if (actitems.length > 64) {
      err.writeln('''
  - Way too many expression items in project. Original defaults at 7:7:7 make for
    105413504 (over 100M) code variants! Are you ready to code 100M+ test cases?!''');
    }
  } // CfgLines constructor

  String get defcf {
    var o = StringBuffer('--defcf "');
    for (var v in actitems) {
      o.write(v.toStrItem(wType: true));
      o.writeCharCode(32);
    }
    o.writeCharCode(34);
    return o.toString();
  }

  /// returns a string with flags predicate (for stub)
  String get defFlags {
    var o = StringBuffer('');
    for (var v in items) {
      if (!v.isFlag()) continue;
      o.write(v.toStrItem());
      o.writeCharCode(32);
    }
    return o.toString();
  }

  /// returns a string with flags selected for current codeconfig
  String get selFlags {
    var o = StringBuffer('');
    for (var v in actitems) {
      if (!v.isFlag()) continue;
      o.write(v.toStrItem(sel: true));
      o.writeCharCode(32);
    }
    return o.toString();
  }

  /// returns flags part from defaults, modified by flags given on the cli
  String get stubFlags {
    var o = StringBuffer('');
    for (var v in actitems) {
      if (!v.isFlag()) continue;
      o.write(v.toStrItem());
      o.writeCharCode(32);
    }
    return o.toString();
  }

  /// returns list of items that belong to first knob given on the cli
  /// empty list on err (knob not given). If kvar is true, returns just
  /// cli selected parts ([name,variant])
  List<String> stubKnobParts({bool clivar = false, bool ucdef = false}) {
    CfgItem u = 0;
    int i = 0;
    got:
    for (; i < clitems.length; i++) {
      u = clitems[i];
      if (clivar) {
        if (u.isKnobName() && i < clitems.length - 1) {
          return [u.toStrItem(), clitems[i + 1].toStrItem()];
        }
        if (u.isKnobName() && i == clitems.length - 1) {
          return [u.toStrItem(), '*'];
        }
      }
      if (u.isKnobName()) break got;
      return [''];
    }
    i = u.indexIn(actitems); // config should have been be vetted, no checks
    var r = <String>[];
    r.add(u.toStrItem());
    for (i++; i < actitems.length; i++) {
      u = actitems[i];
      if (!u.isKnobVar()) break;
      r.add(actitems[i].toStrItem(ucdef: ucdef));
    }
    return r;
  }

  String get targetPragma {
    var o = StringBuffer('/* // @ :Target:: # @');
    var k = StringBuffer();
    bool kb = false;
    for (var v in actitems) {
      if (v.isBranch()) {
        o.write(v.toStrItem());
        continue;
      }
      if (!kb && v.isKnob()) kb = true;
      if (v.isKnob() && !v.isKnobSet()) continue;
      if (kb) {
        if (!v.isKnobVar()) k.writeCharCode(32);
        k.write(v.toStrItem());
      } else {
        o.writeCharCode(32);
        o.write(v.toStrItem(sel: true));
      }
    }
    k.writeCharCode(32);
    int fl = o.toString().toBytes().lengthInBytes;
    int kl = k.toString().toBytes().lengthInBytes;
    while (fl % 3 != 0) {
      o.writeCharCode(32);
      fl++;
    }
    while (kl % 3 != 0) {
      k.writeCharCode(32);
      kl++;
    }
    while (fl + kl < 256 - 6) {
      if (o.length <= k.length) {
        o.writeCharCode(pgFillCh);
        fl += 3;
      } else {
        k.writeCharCode(pgFillCh);
        kl += 3;
      }
    }
    // XXX in psetop look either for | or \r then decide according to
    // line endings as found in file - win users MAY work with bare \n
    // or \r\n, then autoformatter can change endings too...
    // Unfortunately we may expect ending */ to float +-1 anyway. TBD
    // if (osNL.length < 2) o.writeCharCode(124);
    o.write('|\n'); // correction may happen only at the apply stage
    o.write(k.toString());
    o.write('*/');
    return o.toString();
  }

  /// use appliedConfiguration for --loud --apply
  String get appliedConfiguration {
    var o = StringBuffer('Applied code configuration:\n @');
    int ple = o.length;
    int knc = 0;
    int flf = 0;
    for (var v in actitems) {
      if (v.isBranch()) {
        flf = o.length;
        o.write(v.toStrItem());
        continue;
      }
      if (!v.isCfgSet() && !v.isKnobName()) continue;
      if (v.isKnobName()) {
        if (flf > 0) {
          while (o.length - flf < ((maxFlags + 1) * (maxFlagLen + 2)) + 2) {
            o.writeCharCode(32);
          }
          o.writeln('|');
          flf = -1;
        } else {
          o.writeln('');
        }
        knc++;
        ple = o.length;
        o.writeCharCode(32);
        o.write(v.toStrItem());
        continue;
      }
      if (v.isKnobVar()) {
        o.write(v.toStrItem());
        while (o.length - ple < 30) {
          o.writeCharCode(32);
        }
        o.writeCharCode(124);
        ple = o.length;
        continue;
      }
      if (!v.isKnobVar()) o.writeCharCode(32);
      o.write(v.toStrItem(sel: true));
    }
    if (knc < maxFlags) {
      o.writeln('');
      for (; knc < maxFlags; knc++) {
        o.write(' .                          ');
        if (knc < maxFlags - 1) o.writeln('  |');
      }
    }
    o.writeln('  | Docs: https://github.com/ohir/retarget');
    return o.toString();
  }

  String get target {
    var o = StringBuffer('@');
    for (var v in actitems) {
      if (v.isBranch()) {
        o.write(v.toStrItem());
      }
      if (!v.isCfgSet() && !v.isKnobName()) continue;
      if (!v.isKnobVar()) o.writeCharCode(32);
      o.write(v.toStrItem().toLowerCase());
    }
    return o.toString();
  }

  String get activeKnobVariants {
    var o = StringBuffer('');
    for (var v in actitems) {
      if (!v.isKnob() || v.isCfgUnset()) continue;
      if (!v.isKnobVar()) o.writeCharCode(32);
      o.write(v.toStrItem());
    }
    return o.toString();
  }

  String get allKnobs {
    var o = StringBuffer('');
    for (var v in actitems) {
      if (!v.isKnob()) continue;
      if (!v.isKnobVar()) o.writeCharCode(32);
      o.write(v.toStrItem());
    }
    return o.toString();
  }
}

extension ItemFlags on CfgItem {
// spare | cffile |  code conf  |
//       | ! % =  |  +  -  *  . | 2: * on knob is knob name
//       | br fo  | 43 45 42 46 | 1:knob, variant has +-
//     6 |  5  4  |  3  2  1  0 | 0:branch is 0
// spare | 32 16  |  8  4  2  1 | 33! 37% 61=  force - * +
  bool isEqualTo(CfgItem other) => this >> 7 == other >> 7;
  bool isFlag() => this & 31 != 0 && this & 1 == 0;
  bool isForced() => this & 16 != 0;
  bool isCfgSet() => this & 8 != 0;
  bool isBranch() => this & 127 == 0 || this & 127 == 32;
  bool isCfgFlux() => this & 2 != 0;
  bool isKnob() => this & 1 != 0;
  bool isKnobDef() => this & 9 == 9; //
  bool isKnobVar() => this & 1 != 0 && this & 2 == 0;
  bool isKnobVarSet() => this & 1 != 0 && this & 2 == 0 && this & 8 != 0;
  bool isKnobName() => this & 3 == 3;
  bool isKnobSet() => this & 3 == 3 || this & 9 == 9; // name || varSet
  bool isCfgUnset() => this & 4 != 0;
  CfgItem getClean() => this & 0x7fffffffffffff8f;
  CfgItem getAsUnset() => (this & 0x7fffffffffffff87) | 4;
  CfgItem getAsSet() => (this & 0x7fffffffffffff8B) | 8;
  int indexIn(List<CfgItem> hay) {
    int pin = this >> 7;
    int i = 0;
    for (; i < hay.length; i++) {
      if (hay[i] >> 7 == pin) break;
    }
    return i < hay.length ? i : -1;
  }

  /// wType adds ^type sufix, ucdef uppercases active item (if set)
  /// bare strips predicate, sel show for-select state predicate
  String toStrItem({
    bool wType = false,
    bool ucdef = false,
    bool bare = false,
    bool sel = false, // sel true turns * to -
  }) {
    var bu = BytesBuilder();
    int rc = this >> 7;
    if (isKnob()) {
      if (!bare) bu.addByte(46);
      while (rc != 0) {
        int c = rc & 255;
        if (ucdef && isCfgSet() && c > 96 && c < 123) c &= 95;
        bu.addByte(c);
        rc >>= 8;
      }
    } else {
      if (!bare) {
        if (isCfgSet()) bu.addByte(43);
        if (isCfgUnset()) bu.addByte(45);
        if (isCfgFlux()) bu.addByte(sel ? 45 : 42);
      }
      while (rc != 0) {
        int c = rc & 255;
        if (c > 64 && c < 91) c |= 32; // lc
        bu.addByte(c);
        rc >>= 8;
      }
    }
    if (wType) {
      bu.addByte(94);
      bu.addByte((this & 31) + (this & 16 != 0 ? 65 : 97));
    }
    return u8co.decoder.convert(bu.toBytes());
  }
}

extension CfgItemManipulations on String {
  /// toBytes returns utf8 encoded Uint8List
  Uint8List toBytes() => u8co.encoder.convert(this);

  /// returns uint64 form of a short string (item), with optional type t
  CfgItem toCfgItem([int t = 0]) => binItem(u8co.encoder.convert(this), t);

  /// quoteItems quotes *!= for shell use
  String quoteItems() =>
      replaceAllMapped(RegExp(r'\s([*!=]\S+)'), (Match m) => ' \\${m[1]}');
}

extension BufferUtils on Uint8List {
  String strFromBytes([int start = 0, int? end]) {
    end ??= lengthInBytes;
    while (this[start] > 127 && this[start] < 0xc0) {
      start++; // to valid utf
    }
    while (this[end! - 1] > 127 && this[end - 1] < 0xc0) {
      end--; // to valid utf
    }
    if (end - start <= 0) return 'invalid range';
    return u8co.decoder.convert(this, start, end);
  }

  Uint8List slice(int start, [int? end]) {
    end ??= lengthInBytes;
    return Uint8List.sublistView(this, start, end);
  }

  Uint8List ro([int start = 0, int? end]) {
    end ??= lengthInBytes;
    return Uint8List.sublistView(this, start, end) as UnmodifiableUint8ListView;
  }

  /// compute reverse cit base (no type shift)
  int back2dot(int fro, int to) {
    int cit = 0;
    for (; to > fro; to--) {
      int c = this[to];
      if (c == 46) return cit;
      cit <<= 8;
      cit |= c;
    }
    return cit;
  }

  /// so far up to 7B of pin
  /// ohirs fast search of short pin in a long hay (poor Dart solution)
  /// both in same pile of hay. Just needed version, case-ins, stop on
  /// dot, stop inclusive. We will search for up to 7B long ".pin"
  int indexOfDotPin({
    // required int pinS,
    required int pinE,
    required int hayS,
    required int hayE,
    // bool cased = false,
    // bool stopinc = true,
    // int stop = 0, // pin-stop
  }) {
    int i = pinE;
    int pin = 0;
    for (i = pinE - 1; i > pinE - 8; i--) {
      int c = this[i];
      if (c == 46) break; // exclusive, test for dot later
      if (c < 91 && c > 64) c |= 32; // lc
      // if (c == 46) break; // inclusive
      // !oops, dart has no notion of uint, world will burn if we shift b63 down
      pin <<= 8;
      pin |= c;
    } // got pin
    int p = pin;
    int ppo = hayS;
    for (i = hayS; i < hayE; i++) {
      int c = this[i];
      if (c < 91 && c > 64) c |= 32; // lc
      if (p & 255 == c) {
        p >>= 8;
        if (p == 0 &&
            ppo > 0 &&
            this[ppo - 1] == 46 &&
            (i == hayE || (i < hayE - 1 && this[i + 1] == 46))) {
          return ppo << 4 | i & 15; // .pin.
        }
      } else {
        p = pin;
        i = ppo;
        ppo++;
      }
    }
    return -1;
  }

  /// cased: true turns on ascii-case-sensitive comparisons,
  /// codepoints over ascii range are always case-sensitive
  bool rangesEqual({
    required int from,
    required int to,
    required int from2,
    required int to2,
    bool cased = false,
  }) {
    if (to - from != to2 - from2 || to < from || to2 < from2) return false;
    if (to >= lengthInBytes || to2 >= lengthInBytes) return false; // throw?
    if (to - from == 0) return true;
    int j = from;
    int k = from2;
    if (cased) {
      while (j < to) {
        if (this[j] != this[k]) return false;
        j++;
        k++;
      }
    } else {
      while (j < to) {
        if ((this[j] > 64 && this[j] < 91) || (this[j] > 96 && this[j] < 123)) {
          if (this[j] & 0xDF != this[k] & 0xDF) return false;
        } else {
          if (this[j] != this[k]) return false;
        }
        j++;
        k++;
      }
    }
    return true;
  }
}

bool isLcAsciiOrUnicode(String v) {
  for (var e in v.codeUnits) {
    if (e < 65 || e > 90) {
      continue; // bark on A-Z only
    }
    return false;
  }
  return true;
}

bool isTTypeByte(int e) => ((e > 96 && e < 123) ||
    (e > 47 && e < 58) ||
    (e > 64 && e < 91) ||
    e == 32 ||
    e == 46);

bool isTTypeOnly(String v) {
  for (var e in v.codeUnits) {
    if (isTTypeByte(e)) continue;
    return false;
  }
  return true;
}
