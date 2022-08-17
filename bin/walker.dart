//❌RT
/* Copyright © 2022 Wojciech S. Czarnecki aka Ohir Ripe. All Rights Reserved.
Below code is dual licensed either under CC BY-ND for the general population, or
under BSD 3-clause license for all sponsors of "retarget" project. Both licenses
text is to be found in the LICENSE file in the project's root directory.

If you, your team, or your company is shipping smaller and more robust Flutter
apps with retarget's help, please share a one programmer-hour per month to
support `retarget` maturing, and possibly my other future tools. Thank you.
Support links are avaliable at https://github.com/ohir/retarget project site */

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'psetop.dart';
import 'rtconf.dart';
import 'retarget.dart';

const dec8 = Utf8Decoder(allowMalformed: true);

class FileChanges {
  final String path;
  final FileSystemException? ferr;
  List<ChgItem>? chlist;
  List<PragSet>? places;
  List<int>? _scope;
  List<PragSet>? _seen;
  PragSet? _fails;
  PragSet? _pgall;
  bool willChange = false;
  bool hasErrors = false;
  bool excluded = false;
  bool complete = false;
  int _sP = -1;
  FileChanges({
    required this.path,
    this.ferr,
    this.excluded = false,
    this.hasErrors = false,
  });

  /// destructor, yep.
  void seal(Uint8List bu, Config cfg) {
    if (_pgall == null || _pgall!.parts.isEmpty) {
      _seen = null;
      _pgall = null;
      return; // nothing went in
    }
    var all = _pgall!.parts;
    int end = all.length;
    int i = 0;
    int lastNLpos = -1;
    int lastLno = 0;
    int lastAt = 0;
    int lno(int at) {
      // Pragmas we usually have a few, lines we have a plenty.
      // CI needs no lines, only humans do. So better be lazy.
      if (at == lastAt) return lastLno;
      if (at < lastAt) {
        lastLno = 0;
        lastAt = 0;
        lastNLpos = -1;
      }
      lastAt = at;
      int nlpos = lastNLpos;
      if (nlpos >= bu.lengthInBytes) return lastLno;
      int lno = lastLno;
      do {
        lno++;
        nlpos = bu.indexOf(0xa, nlpos + 1);
      } while (nlpos >= 0 && nlpos < at);
      if (nlpos < 0) lastNLpos = bu.lengthInBytes;
      lastLno = lno;
      lastNLpos = nlpos;
      return lno;
    } // Function lno

    // final chores: complete go to places, incomplete go to r.bad
    if (_seen != null && _seen!.isNotEmpty) {
      places ??= <PragSet>[];
      for (var pset in _seen!) {
        if (pset.parts.isEmpty) {
          throw ('PARTS EMPTY');
        } else if (!pset.complete) {
          for (var b in pset.parts) {
            b.err = PgErr.eIncomplete;
            bad = b;
          }
        } else {
          var pge = pset._willChange(bu, cfg);
          if (pge == PgErr.eNone) {
            if (!cfg.silent && !cfg.fixG) {
              places!.add(pset);
            }
          } else {
            for (var b in pset.parts) {
              bad = b;
            }
          }
        }
      }
      if (places!.isEmpty) places = null;
    } // if _seen
    // make diags
    if (cfg.loud || cfg.diags) {
      for (i = 0; i < end; i++) {
        var p = all[i];
        p.lno = lno(p.at);
        p._diag(Uint8List.view(bu.buffer));
      }
    }
    // collect changes
    assert(chlist == null, 'CHLIST PRESENT, it should not');
    if (!hasErrors) {
      var chl = <ChgItem>[];
      for (i = 0; i < end; i++) {
        var a = all[i];
        if (a.err != null) {
          hasErrors = true;
          break;
        }
        if (a.chg == 0 && a.fix == null) continue;
        if (a.chg != 0) chl.add(a.chg);
        if (a.fix == null) continue;
        for (int i = 0; i < a.fix!.length; i++) {
          chl.add(a.fix![i]);
        }
      }
      if (!hasErrors && chl.isNotEmpty) chlist = chl;
    }

    // We may not hold on to big chunks of memory allocated in the isolate
    // as these would have been copied out otherwise
    _pgall = null;
    _scope = null;
    _seen = null;
    assert(
        !cfg.silent || places == null, "Places may not return on a silent op");
    if (chlist != null) willChange = true;
    complete = true;
    return;
  }

  set bad(Pragma a) {
    if (_fails != null) {
      _fails!.parts.add(a);
    } else {
      hasErrors = true;
      _fails = PragSet._empty();
      _fails!.parts.add(a);
    }
  }

  List<Pragma>? get failed => _fails?.parts;

  set seen(PragSet ps) {
    _seen ??= <PragSet>[];
    _seen!.add(ps);
  }

  List<PragSet> get pastSeen {
    _seen ??= <PragSet>[];
    return _seen!;
  }

  PragSet freshPset() {
    var ps = PragSet._empty();
    return ps;
  }

  bool pushGuard(int g) {
    if (g == 1) return true; // skip singles
    _scope ??= <int>[];
    if (_sP == _scope!.length - 1) _scope!.add(0);
    _sP++;
    _scope![_sP] = g;
    return true;
  }

  bool inScope(int g) {
    if (g == 1) return true; // singles are ok in any scope
    if (_scope == null || _scope!.isEmpty) return false;
    return g == _scope![_sP];
  }

  // List.remove(obj) removes _first_ occurence. Gotcha!
  // so we need to implement ol'pale stack by hand
  bool popGuard(int g) {
    if (g == 1) return true; // skip singles
    if (_scope == null || _scope!.isEmpty) return false;
    if (_scope![_sP] != g) return false;
    _scope![_sP] = 0;
    if (_sP > 0) _sP--;
    return true;
  }

  Pragma freshPg(Uint8List bu, int at, Config cfg) {
    var a = Pragma._new(bu, at, cfg);
    _pgall ??= PragSet._empty();
    _pgall!.parts.add(a);
    return a;
  }
} // class FileChanges

/// check is in proper guard characters set
bool isGuardChar(int i) => // ^_`a-z @A-Z 0-9:
    (i > 0x5d && i < 0x7b) || (i > 0x3f && i < 0x5b) || (i > 0x2f && i < 0x3b);

/// pragma parts together
class PragSet {
  bool complete = false; // #efi seen
  int guard = 0;
  PgErr? err;
  late final List<Pragma> parts;

  PragSet._empty() {
    parts = <Pragma>[];
  } // PragSet.empty

  /// returns false if could not add a due to errors
  /// rejected Pragma err is set to reason
  bool add(Pragma a, Uint8List bu) {
    if (complete) {
      a.err = PgErr.eSurplusCopyOfPart;
      return false;
    }
    var e = parts.isEmpty ? a._canIBeAfter(null) : a._canIBeAfter(parts.last);
    if (e != PgErr.eNone) {
      a.err = e;
      return false;
    }
    if (parts.isEmpty) {
      guard = a.guard;
    }
    if (a.eop) {
      if (a.to > maxFS) {
        a.err = PgErr.eTooBigFile;
        return false;
      }
      complete = true;
    }
    parts.add(a);
    return true;
  }

  /// called from seal for each opening pragma. Make this wrapper to keep
  /// all ops enntries in a single place
  PgErr _willChange(Uint8List bu, Config cfg) {
    if (!complete) return PgErr.eIncomplete; // completeness can be late
    switch (parts[0].type) {
      case PgType.isIf:
        return psoIf(this, bu, cfg);
      case PgType.isSwth:
      case PgType.isSwdf:
        return psoSw(this, bu, cfg);
      case PgType.isLine:
        return psoLi(this, bu, cfg);
      case PgType.isTag:
        return psoTag(this, bu, cfg);
      case PgType.isBcon:
        return psoBc(this, bu, cfg);
      default:
        return pso(this, bu, cfg);
    }
  }

  @override
  String toString() {
    var rs = StringBuffer('  PragSet: $hashCode\n');
    for (var v in parts) {
      rs.write(v.toString());
    }
    return rs.toString();
  }
} // class PragSet

class Pragma {
  final int at; //    pragma start
  int fl = 0; //      flags start
  int ss = 0; //      select bar start (switch)
  int to = 0; //      pragma end
  int guard = 0;
  int lno = 0; //     filled if error
  ChgItem chg = 0; // simple change
  List<ChgItem>? fix; // optional fix changes
  PgType type = PgType.unk; // unk if not recogized
  String? offext; //  build constraints provided .ext
  String? diag; //    details for human to see
  PgErr? err; //      reason
  bool sOP = false; // Ima starting pragma
  bool eop = false; // Ima closing pragma

  /// This is a private constructor to be called only from our
  /// parser. Hence we are sure that bu.end >= 18 + 10 from bu[at]
  Pragma._new(Uint8List bu, this.at, Config cfg) {
    var r = bu[at + 8];
    // 0  3    8      16 18      _first marker is at 26
    // /* // { xxB7d___: #ifconf +apple    first 18 + 8 }
    for (var i = 9; i < 13; i++) {
      r <<= 8;
      r |= bu[at + i];
    }
    guard = r;
    compl:
    while (true) {
      var end = bu.lengthInBytes;
      var i = at; // at pragma 0 (#-18)
      switch (bu[i + 15]) {
        case 0x5f: // _ #ifconf
          i += 25;
          type = PgType.isIf;
          sOP = true;
          break;
        case 0x60: // ` #else
          i += 25;
          type = PgType.isElse;
          break;
        case 0x5e: // ^ #efi, #esw
          i += 24;
          switch (bu[i]) {
            case 0x21: // #efi @!
              type = PgType.isEfi;
              break;
            case 0x40: // #efi @@
              type = PgType.isFi;
              break;
            case 0x46: // #esw OF .bar
              type = PgType.isEsw;
              ss = i + 2;
              break;
            default:
              to = i;
              type = PgType.unk;
              err = PgErr.eShape;
              break compl;
          }
          eop = true;
          i++;
          break;
        case 0x2e:
          i += 25;
          type = PgType.isSwth; // may switch to Swdf later
          sOP = true;
          break;
        case 0x2d: // - #caseof
          i += 25;
          type = PgType.isCase;
          break;
        case 0x2a: // // +Flag***: # */
          i += 19; // SL pragma has only # */
          sOP = true;
          eop = true; // single is both
          type = PgType.isLine;
          break;
        case 0x3a: // : file or target
          if (bu[i + 8] == 0x3a &&
              bu[i + 9] == 84 && // :T
              i < bu.lengthInBytes - 256) {
            type = PgType.isTag;
            sOP = true;
            eop = true; // single line pragma
            fl = i + 19;
            i += 256;
            to = i;
            if (bu[i - 2] != 43 && bu[i - 1] != 47) {
              err = PgErr.eWrongTagSize;
            }
            break compl; // no conditions to check
          } else if (bu[i + 8] != 70 || bu[i + 9] != 105) {
            type = PgType.unk;
            i += 19; // let human see
            to = i;
            break;
          }
          type = PgType.isBcon;
          offext:
          for (; i < end; i++) {
            switch (bu[i]) {
              case 0xa:
                to = i;
                err = PgErr.eIncomplete;
                break compl;
              case 0x20:
                fl = i;
                to = i;
                break offext; // OK, at sp after #name
              default:
                if (bu[i] > 0x60 && bu[i] < 0x7b) {
                  continue offext; // a-z
                }
                to = i;
                err = PgErr.eBadCh;
                break compl; // Err: offext uses lowercase ascii
            }
          }
          sOP = true;
          eop = true; // single line pragma
          break; // expects "flags" ie. +branches or -branches
        default:
          to = i;
          sOP = true; // single specimen
          eop = true; // orphaned or misplaced
          err = PgErr.eGuardPadUnk;
          break compl; // Err: bad guard padding, end the loop
      }
      // i points at space before punct marker .-+*
      if (i > end - 3 || bu[i] != 0x20) {
        to = i;
        err = PgErr.eBadSp;
        break compl;
      }
      int dots = 0;
      fl = ++i; // flags start
      to = i; // set end for case we'll fail down the line
      if (bu[i] != 0x2b && bu[i] != 0x2d && bu[i] != 0x2a && bu[i] != 0x2e) {
        err = PgErr.eBadMark;
        break compl;
      }
      var flag = false; // .-+* is where it should be, but we check for nl
      pgl: // pragma ends at nl or at a first space not followed by .-+*
      for (--i; i < end - 1; i++) {
        // --i move back to space
        switch (bu[i]) {
          case 0xa:
            if (!flag) {
              to = i;
              err = PgErr.eNoFlag;
              break compl; // Err: no flags on pragma
            }
            break pgl;
          case 0x20:
            // #caseof .os.dro from .os
            //         .      ^     .+6
            if (i < end - 11 && // .x.y
                bu[i + 1] == 102 && // f
                bu[i + 2] == 114 && // r
                bu[i + 3] == 111 && // o
                bu[i + 4] == 109 && // m
                bu[i + 5] == 32 &&
                bu[i + 6] == 46) {
              if (bu[i - 1] == 42) {
                if (type == PgType.isSwth) {
                  type = PgType.isSwdf;
                } else {
                  err = PgErr.eCaseDefault;
                }
              }
              ss = i + 6; // .bar.chain.starts
              i += 5;
            }
            break;
          case 0x2e: // opt: do not repeat dot-hunt in psetop
            if (ss != 0 && i > ss) {
              dots++;
              chg <<= 7;
              chg |= (i - ss + 1) & 127;
            }
            if (dots > 8) err = PgErr.eTooManyVariantsInBar;
            continue pgl;
          default:
            continue pgl;
        }
        switch (bu[i + 1]) {
          case 0x2b: // +
          case 0x2d: // -
          case 0x2a: // *
          case 0x2e: // .
            flag = true;
            continue pgl;
        }
        break pgl;
      }
      to = i; // i is at ' ' past flags or at NL
      if (type != PgType.isSwth && type != PgType.isSwdf) chg = 0; // correct
      if (!flag) {
        err = PgErr.eNoFlag;
        break compl; // Err: no flags on pragma
      }
      if (type == PgType.isBcon) {
        err = _chkBranchList(bu); // lists should be homogenous +++ or ---
        _soffext(bu); // make the ext string form while we still have bu
      }
      break;
    }
    err ??= _chkCondition(bu, cfg);
  } // Pragma._new(Uint8List bu, this.at)

  /// returns null on success
  PgErr? _chkCondition(Uint8List bu, Config cfg) {
    switch (type) {
      // xTODO check conditions for file(branch list), and switches
      // filefor + + +/- - - here
      case PgType.isCase: // linted in psetop
      case PgType.isEsw: // linted in psetop
      case PgType.isTag: // linted in recognizer
      case PgType.isLine:
        return null;
      case PgType.isSwth: // knobs
      case PgType.isSwdf: // check if varbar is in order
        // lint: varbar order must agree with one defined in .flags
        // dot-hunt takes place here, too, to not repeat work at psetop
        int kdot = fl + 1;
        while (kdot < ss && bu[kdot] != 46) {
          kdot++;
        }
        chg <<= 7;
        chg &= ~(1 << 63);
        chg |= (kdot - fl + 1) & 127; // we will pop it first
        int dot = ss + 1;
        int pdot = dot;
        while (dot < to && bu[dot] != 46) {
          dot++;
        }
        int knob = cfg.ccIndexOfRange(bu, pdot, dot);
        if (knob < 0) return PgErr.eUnknownKnobName;
        var ili = cfg.cconf;
        knob++; // to 1st variant
        dot++; // past dot
        pdot = dot;
        int cfi = 0;
        for (; dot <= to; dot++) {
          if (bu[dot] != 46 && dot < to) continue;
          for (int i = dot - 1; i >= pdot; i--) {
            int c = bu[i];
            if (c > 64 && c < 91) c |= 32; // lc
            cfi <<= 8;
            cfi |= c;
          }
          if (ili[knob] >> 7 != cfi) return PgErr.eBadFromVariantsInfo;
          pdot = dot + 1;
          knob++;
          cfi = 0;
        }
        if (knob < ili.length && !ili[knob].isKnobName()) {
          return PgErr.eIncompleteVariantsInfo;
        }
        return null;
      default: // flags
        var f = cfg.bFlags;
        if (to - fl != f.lengthInBytes) {
          return PgErr.eBadFlags;
        }
        var i = fl;
        var j = 0;
        while (i < to) {
          switch (bu[i]) {
            case 0x2a: // *
              break;
            case 0x2b: // +
              if (f[j] == 0x2b) break;
              if (f[j] != 0x2d) continue bad;
              break;
            case 0x2d: // -
              if (f[j] == 0x2d) break;
              if (f[j] != 0x2b) continue bad;
              break;
            bad:
            default:
              if (bu[i] != f[j]) {
                return PgErr.eBadFlags;
              }
          }
          i++;
          j++;
        }
        return null;
    }
  }

  /// may I follow an "other" precedestor? errNone if I may
  PgErr _canIBeAfter(Pragma? other) {
    if (other != null && other.err != null) {
      return PgErr.ePrecedingHasErr;
    }
    if (err != null) return PgErr.eNotBelongsMyErr;
    if (other == null) {
      if (type == PgType.isCase ||
          type == PgType.isElse ||
          type == PgType.isEfi ||
          type == PgType.isEsw ||
          type == PgType.isFi) {
        // must have precedestors
        return PgErr.eOrphaned;
      } // others need not to
      if (at < 1) return PgErr.eCantBeAtFirstByte;
      return PgErr.eNone;
    } // non-null precedestor below
    if (other.err != null || other.type == PgType.unk) {
      return PgErr.ePrecedingHasErr;
    }
    switch (type) {
      case PgType.unk:
        return PgErr.eUnknown;
      case PgType.isTag: // Singles and openings may not follow
      case PgType.isBcon: //
      case PgType.isLine: //
      case PgType.isIf: // so #if should not, unless C&P misplaced
      case PgType.isSwth: // neither #switch exhausting
      case PgType.isSwdf: // nor #switch w/defaults
        return PgErr.eMisplaced;
      case PgType.isFi:
        if (other.type != PgType.isIf) {
          return PgErr.eMisplacedFi;
        }
        break;
      case PgType.isElse:
        if (other.type != PgType.isIf) {
          return PgErr.eMisplacedElse;
        }
        break;
      case PgType.isEfi:
        if (other.type != PgType.isElse) {
          return PgErr.eMisplacedEfi;
        }
        break;
      case PgType.isCase:
        if (other.type == PgType.isCase ||
            other.type == PgType.isSwth ||
            other.type == PgType.isSwdf) {
          break;
        }
        return PgErr.eMisplacedCase;
      case PgType.isEsw:
        if (other.type == PgType.isCase || other.type == PgType.isSwdf) {
          break;
        } // after at least a single case, or lump var.* default
        return PgErr.eMisplacedEsw; // at least single case required
    }
    if (guard != other.guard) return PgErr.eGuardNotMatch;
    return PgErr.eNone;
  }

  @override
  String toString() {
    var s = StringBuffer('');
    if (diag != null) {
      var ty = type.toString().replaceFirst('PgType.is', '');
      s.write('   Pragma: "$ty" at bytes $at..$fl..$to |$guard|');
      if (offext != null) {
        s.write('\n     fext: $offext');
      }
      if (err != null) {
        var er = err.toString().replaceFirst('PgErr.e', '');
        s.write('\n    Error: $er');
      }
      s.write('\n of shape: $diag');
      if (lno != 0) {
        s.write('\n  in line: $lno');
      }
      s.writeln('\n  --------');
    } else {
      s.write('Pragma $type at byte $at');
      if (lno != 0) s.write(' line $lno');
      if (offext != null) s.write(' [FileExt $offext]');
      if (err != null) s.write(' Error: $err');
    }
    return s.toString();
  }

  void _diag(Uint8List bu) {
    if (lno == 0) lno = 1; // correct single line 0
    var o = StringBuffer();
    o.write(dec8.convert(bu, at, to));
    int fr = 0;
    switch (type) {
      case PgType.isIf:
      case PgType.isFi:
      case PgType.isEfi:
      case PgType.isElse:
        fr = fl;
        break;
      case PgType.isSwth:
      case PgType.isSwdf:
      case PgType.isCase:
      case PgType.isEsw:
        fr = ss;
        break;
      case PgType.isBcon:
      case PgType.isLine:
      case PgType.isTag:
      case PgType.unk:
        fr = at;
        break;
    }
    if (fix != null && fr == fl) {
      // TODO fix printing fixes, so far just turn it off for knobs
      o.write('\n    fixes: ');
      int opo = 0;
      int pos = 0;
      while (opo < fr - at) {
        o.writeCharCode(0x02D9);
        opo++;
      }
      opo = 0; // now from fr
      for (int n = 0; n < fix!.length; n++) {
        int i = fix![n] >> 30;
        while (i != 0) {
          pos = ((i >> 7) & 0x1ff) - 1;
          while (opo < pos) {
            o.writeCharCode(0x02D9);
            opo++;
          }
          opo = pos + 1;
          o.writeCharCode(i & 127);
          i >>= 16;
        }
      }
      while (opo < to - fr) {
        o.writeCharCode(0x02D9);
        opo++;
      }
    }
    if (chg != 0) {
      o.write('\n   change: ');
      o.writeCharCode(bu[at]);
      o.writeCharCode(bu[at + 1]);
      o.write(' => ');
      int i = chg >> 30;
      while (i != 0) {
        o.writeCharCode(i & 127);
        i >>= 16;
      }
    }
    diag = o.toString();
  }

  /// make ext str from bu
  void _soffext(Uint8List bu) {
    offext = dec8.convert(bu, at + 19, fl - 1);
  }

  PgErr _chkBranchList(Uint8List bu) {
    // TODO _chkBranchList +++ ---
    return PgErr.eListConditionsDiffer;
  }
} // class Pragma

/// parseSingleSync is intended to be run on its own Isolate
FileChanges parseSingleSync(Config cfg, File f) {
  late final Uint8List bu;
  try {
    bu = f.readAsBytesSync();
  } on FileSystemException catch (e) {
    return FileChanges(path: f.absolute.path, ferr: e);
  }
  if (bu.lengthInBytes < pragmaLength) {
    return FileChanges(path: f.absolute.path);
  } else if (bu[0] == 47 && // /   rt-exclude marker
      bu[1] == 47 && // /   not advertised
      bu[2] == 226 && // ❌
      bu[3] == 157 &&
      bu[4] == 140 &&
      bu[5] == 82 && // R
      bu[6] == 84) {
    return FileChanges(path: f.absolute.path, excluded: true);
  }
  return parseBufferSync(cfg, Uint8List.view(bu.buffer), f.absolute.path);
}

FileChanges parseBufferSync(Config cfg, Uint8List bu, String path) {
  var i = -1;
  var end = bu.lengthInBytes;
  final r = FileChanges(path: path);
  var seen = r.pastSeen;
  pgNext:
  while ((i = bu.indexOf(0x23, i + 1)) >= 0) {
    // check 8 bytes, this costs less than retracting in recognizer
    // (where we also will have these bytes hot in L1 cpu cache)
    if (i < 18 ||
        end - i < 10 || // not enough for a #ifconf *f|ag
        bu[i - 15] != 0x2f || //
        bu[i - 14] > 0x2f || // enough  ( can be / or * )
        bu[i - 16] != 0x20 ||
        (bu[i - 17] != 0x2f && bu[i - 17] != 0x2a) || /* // ** */
        (bu[i - 18] != 0x2f && bu[i - 18] != 0x2a) || /* // ** */
        bu[i - 11] != 0x20 ||
        bu[i - 2] != 0x3a || // sentinel colon
        bu[i - 1] != 0x20) {
      continue;
    } // got pragma head
    var pgn = r.freshPg(Uint8List.view(bu.buffer), i - 18, cfg);
    i = pgn.to > i ? pgn.to : i; // corrupted pragma, skip past #
    if (pgn.err != null) {
      r.bad = pgn;
      continue;
    }
    var pset = r.freshPset();
    if (pgn.sOP) {
      // Singular entities need no guard, all have 1
      if (pgn.type == PgType.isLine ||
          pgn.type == PgType.isBcon ||
          pgn.type == PgType.isTag) {
        pgn.guard = 1;
      } else {
        for (int sP = 0; sP < seen.length; sP++) {
          if (pgn.guard == seen[sP].guard) {
            pgn.err ??= PgErr.eGuardNotUniq;
            r.bad = pgn;
            continue pgNext; // bad bad, get rid of it
          }
        }
      }
      if (!pset.add(pgn, bu)) {
        r.bad = pgn;
        continue pgNext;
      }
      r.pushGuard(pgn.guard); // new scope opens
      r.seen = pset;
    } else {
      var dbl = false;
      var got = false;
      for (int sP = 0; sP < seen.length; sP++) {
        if (pgn.guard == seen[sP].guard) {
          if (!got) {
            pset = seen[sP];
            got = true;
          } else {
            dbl = true;
          }
        }
      }
      if (dbl || !got) {
        pgn.err = dbl ? PgErr.eGuardNotUniq : PgErr.eOrphaned;
        r.bad = pgn;
        continue pgNext;
      }
      if (!pgn.eop && !r.inScope(pgn.guard)) {
        pgn.err = PgErr.eMisplacedScope;
        r.bad = pgn;
        continue pgNext;
      }
      if (!pset.add(pgn, bu)) {
        r.bad = pgn;
        continue pgNext;
      }
      if (pgn.eop && !r.popGuard(pgn.guard)) {
        pgn.err = PgErr.eOverlappingScope;
        r.bad = pgn;
        continue pgNext;
      }
    }
  }
  // do final chores, release as much memory as possible
  r.seal(Uint8List.view(bu.buffer), cfg);
  return r;
}

// Future<void> findWork(Config cfg) async {
// we need no async here, really, unlesssome  future version will
// start to spawn isolate workers for events on the stream.
List<FileSystemEntity> findWorkSync(Config cfg) {
  final files = <FileSystemEntity>[];
  void add(FileSystemEntity fi) => files.add(fi);
  for (var ourd in ourSubdirs) {
    var dir = Directory('${cfg.dir.path}$osSEP$ourd');
    if (!dir.existsSync()) continue;
    dir
        .listSync(followLinks: false, recursive: true)
        .where((x) => isServicedFile(x))
        .forEach(add);
  }
  return files;
}

bool _canOpenSync(File f, {bool trywrite = false}) {
  // check perms by bludgeon as dart:io is lying to us about permissions
  // https://github.com/dart-lang/sdk/issues/41012
  // even on POSIX dart:io has not a faintest idea of ACLs.
  try {
    var h = f.openSync(mode: FileMode.append);
    int last = h.lengthSync() - 1;
    if (last < 1) {
      h.closeSync(); // no 0 files, Luke
      return false; // should never happen in walk
    }
    h.setPositionSync(last);
    int b = h.readByteSync();
    h.setPositionSync(last);
    if (trywrite) {
      h.writeByteSync(b);
      h.flushSync();
    }
    h.closeSync();
  } catch (_) {
    return false;
  }
  return true;
}

List<FileChanges> parseWorkSync(List<FileSystemEntity> files, Config cfg) {
  var obs = StringBuffer();
  var r = <FileChanges>[];
  bool loud = cfg.loud;
  bool diag = cfg.diags;
  bool err = false;
  if (cfg.silent) {
    // we're in CI, errcode is all we can say, so just exit early
    for (var i = 0; i < files.length; i++) {
      var fchg = parseSingleSync(cfg, files[i] as File);
      if (fchg.ferr != null) exit(50);
      if (fchg.hasErrors) exit(51);
      if (!cfg.dry || cfg.force) {
        // XXX for CI we should trywrite even on a dry-run, but this might be
        // confusing. Lets do it by --force so avid manual readers may check
        if (fchg.willChange && !_canOpenSync(File(fchg.path), trywrite: true)) {
          exit(52);
        }
      }
      r.add(fchg);
    } // CI silent
  } else {
    // normal cli
    var path = '';
    nextfile:
    for (var f in files) {
      var fchg = parseSingleSync(cfg, f as File);
      path = trimPath(f);
      if (fchg.hasErrors) err = true;
      do {
        if (fchg.willChange) {
          if (fchg.places == null) throw ('NULL MAY NOT CHANGE! ${f.path}');
          if (diag) {
            obs.writeln('\nPLACES in: $path');
            for (var e in fchg.places!) {
              obs.write(e.toString());
            }
          } // else silent
          // --force forces a single byte write with -n|--dry-run
          if (!cfg.dry || cfg.force) {
            if (!_canOpenSync(File(fchg.path), trywrite: true)) {
              obs.writeln('WriteError: $path');
              err = true;
              continue nextfile;
            }
          }
          if (!err) r.add(fchg);
        } else if (loud) {
          obs.write(' Unchanged: $path');
        } // else silent

        if (err) {
          obs.writeln(
              '\n Giving up! Will not apply even a single change due to');
          if (fchg.failed != null) {
            if (diag || loud) {
              obs.writeln('\nERRORS in: $path');
              for (var e in fchg.failed!) {
                obs.write(e.toString());
              }
              break;
            } else {
              obs.writeln('\n ERRORS in: $path');
              obs.write('  re-run with -v or --verbose to see more.');
            }
          } else if (fchg.ferr != null) {
            obs.write('\n  => ${fchg.ferr}');
          } else {
            obs.write('UNKNOWN ERROR! Please fill in bug report!');
          }
        }
      } while (false);
    }
  }
  print(obs);
  return err ? <FileChanges>[] : r;
}

/// returns message for the user
String applyWorkSync(List<FileChanges> tochg, Config cfg) {
  var obs = StringBuffer();
  var path = trimPath(cfg.dir);
  var loud = cfg.loud || cfg.diags;
  var diag = cfg.diags;
  if (tochg.isEmpty) {
    if (loud) obs.write('Nothing to do in $path!');
    return obs.toString();
  }
  for (var fchg in tochg) {
    var f = File(fchg.path);
    try {
      path = loud ? trimPath(f) : '';
      var fh = f.openSync(mode: FileMode.append);
      int last = fh.lengthSync() - 1;
      if (last < pragmaLength) throw ('TOO SHORT file for pragma: $path');
      if (cfg.dry) {
        if (loud) obs.write('DRY: test for $path');
        fh.setPositionSync(last);
        int c = fh.readByteSync();
        // --force forces test write even on -n (check ACL on ntfs, xfs, zfs)
        if (cfg.force) {
          fh.setPositionSync(last);
          fh.writeByteSync(c);
          if (loud) obs.write(' OK: forced write test for $path');
        }
      } else {
        int cnt = 0;
        for (var chg in fchg.chlist!) {
          if (chg < 0) {
            fh.flushSync();
            fh.closeSync();
            throw 'INVALID change came [$chg]';
          }
          int at = chg & 0x3fffffff;
          int i = chg >> 30;
          while (i > 0) {
            int o = (i >> 7) & 0x1ff;
            int c = i & 127;
            if (at + o > last) {
              fh.flushSync();
              fh.closeSync();
              throw 'INVALID change past EOF [$chg]';
            }
            i >>= 16;
            cnt++;
            if (c <= blockWrite4 && c >= blockWrite1) {
              // special writes here. 1: 256B of Tag pragma
              switch (c) {
                case blockWrite1:
                  if (at + 257 > last) {
                    fh.flushSync();
                    fh.closeSync();
                    throw 'INVALID block change past EOF [$chg]';
                  }
                  fh.setPositionSync(at + 1);
                  fh.writeFromSync(cfg.bTargt);
                  cnt += 256;
                  break;
                case blockWrite2:
                case blockWrite3:
                case blockWrite4:
                  break;
              }
            } else {
              fh.setPositionSync(at + o);
              fh.writeByteSync(c);
            }
          }
          if (diag) obs.writeCharCode(10);
        }
        if (loud) obs.writeln('changes in: $path (${cnt}B)');
      }
      fh.flushSync();
      fh.closeSync();
      // } catch (e, s) {
      // obs.write('XXX $e\n$s');
    } catch (e) {
      obs.write(
          '\n\n!WRITE FAILED! TREE IS NOT CONSISTENT!\n  File: $path err: ${e.toString()}');
      return obs.toString();
    }
  }
  return loud ? obs.toString() : '';
}

bool isServicedFile(FileSystemEntity x) {
  if (x is! File) return false;
  do {
    var dpo = x.path.lastIndexOf(osSEP);
    var epo = x.path.lastIndexOf('.');
    if (dpo < 0 || epo <= 0 || dpo > epo || x.path.length - epo < 2) break;
    if (epo > 0 && x.path.codeUnitAt(epo - 1) == osSEPcu) break;
    var ext = x.path.substring(epo);
    if (ourFileExt.contains(ext)) return true;
  } while (false);
  return false;
}

extension NonDec on ChgItem {
  String toHex() => _i2h(this);
  String asChpos({int sep = 32}) {
    var o = StringBuffer();
    int i = 0;
    if (this < 0) return 'invalid';
    var at = this & 0x3fffffff;
    o.write('${_i2h(this, wide: true)} at: $at (');
    i = this >> 30;
    while (i > 0) {
      o.write('+${(i >> 7) & 0x1ff}');
      i >>= 16;
    }
    o.writeCharCode(41);
    o.writeCharCode(32);
    i = this >> 30;
    while (i > 0) {
      o.write(':${at + ((i >> 7) & 0x1ff)}:');
      i >>= 16;
    }
    o.writeCharCode(32);
    o.writeCharCode(124);
    o.writeCharCode(32);

    o.write(_i2h(this & 0x3fffffff, wide: false));
    o.writeCharCode(32);
    i = this >> 30;
    while (i > 0) {
      o.writeCharCode(i & 127);
      i >>= 16;
    }
    o.writeCharCode(sep);
    return o.toString();
  }

  String toFlOffsets() {
    var o = StringBuffer();
    var rev = <int>[]; // reversed!
    int i = this;
    while (i > 0) {
      rev.add(i & 127);
      i >>= 7;
    }
    o.writeAll(rev.reversed, ' '); // show layout
    return o.toString();
  }
}

/// wrap for public
String asHex(int inp, {bool wide = false, bool ox = true}) =>
    _i2h(inp, wide: wide, ox: ox);

String _i2h(int inp, {bool wide = false, bool ox = true}) {
  List<int> ol = List.filled(18, 32);
  if (inp < 0) return 'negative';
  int i;
  int c;
  i = ol.length - 1;
  while (inp > 0) {
    c = inp & 15;
    ol[i] = c < 10 ? c + 48 : c + 87;
    inp >>= 4;
    i--;
  }
  if (wide) {
    while (i > 1) {
      ol[i] = 48;
      i--;
    }
  }
  if (ox && i > 0) {
    ol[i--] = 120;
    ol[i] = 48;
  }
  var o = StringBuffer();
  for (var e in ol) {
    o.writeCharCode(e);
  }
  return o.toString().trim();
}
