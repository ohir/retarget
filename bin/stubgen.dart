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

import 'cmline.dart';
import 'retarget.dart';
import 'rtconf.dart';

enum StubKind {
  iffi,
  elfi,
  bcon,
  line,
  swca,
  swth,
  tagt,
}

void out({required Cmline cm}) {
  var s = StringBuffer();
  int tn = 0;
  String ts = '';
  String code = cm.cfg.stdinStr ?? '';
  var oCode = code;
  if (cm.stubkind == StubKind.swca) {
    // --stubca is special
    do {
      bool ise = false;
      code = code.trim();
      var ps = code.indexOf('^: #esw OF ');
      if (ps < 0) {
        ise = true;
        ps = code.indexOf('^: #efi @@ ');
      }
      if (code.isEmpty || ps < 0) {
        s.writeln('// Error: neither "#efi @@" nor "#esw OF" line given.');
        break;
      }
      if (ps != 15) {
        s.writeln('// Error: code prepends closing pragma given. That\'s bad.');
        break;
      }
      var g = code.substring(ps - 7, ps - 2);
      if (ise) {
        var rest = code.substring(ps + 11);
        if (code.codeUnitAt(ps - 15) == 47) {
          s.writeln('/* //}{ $g```: #else ! $rest');
          s.writeln('*/ // } $g^^^: #efi @! $rest');
        } else {
          s.writeln('*/ //}{ $g```: #else ! $rest');
          s.writeln('// // } $g^^^: #efi @! $rest');
        }
        stdout.write(s.toString());
        return;
      }
      // switch case
      var cAct = // //
          code.codeUnitAt(ps - 15) == 47 && code.codeUnitAt(ps - 14) == 47;
      if (!cAct && !cm.cfg.force) {
        s.writeln(
            '// Error: case can be added ONLY under *active* code. Ie. #esw line must');
        s.writeln(
            '//        start with "// ".  If you\'ll --force it, then do --apply ASAP.');
        break;
      }
      var fro = code.substring(ps + 11).split(' ').first;
      var usel = cm.cfgLines.stubKnobParts(clivar: true).join('');
      var barli = cm.cfgLines.stubKnobParts(ucdef: true);
      if (usel.isEmpty || barli.isEmpty) {
        s.writeln(
            '// Error: likely no knob.variant was provided or it was wrong.');
        break;
      }
      if (!fro.startsWith(barli[0])) {
        s.writeln('// Error: requested variant does NOT match #esw line.');
        break;
      }
      var ucbar = barli.join('');
      var lcbar = ucbar.toLowerCase();
      s.writeln('${cAct ? '/*' : '*/'} //}{ $g---: #caseof $usel from $ucbar');
      s.writeln('       /* Here goes your "$usel" variant code... */$osNL');
      s.writeln('${cAct ? '*/' : '//'} // } $g^^^: #esw OF $lcbar');
      stdout.write(s.toString());
      return;
      // ignore: dead_code
    } while (false);
    s.write(oCode);
    stdout.write(s.toString());
    return;
  }
  String fls = cm.cfl.stubFlags;
  String ecode = '';
  if (code.isEmpty && cm.stubcode != null) {
    var sa = cm.stubcode!;
    if (sa.startsWith('X')) {
      var x = sa.substring(1);
      var c =
          ' ${cm.cfgLines.stubFlags.split(' ').where((e) => !e.startsWith('-')).join(' ')}';
      code = "print('$x active for: $c');\n";
      ecode = "print('$x inactive for: $c');\n";
    } else {
      code = sa;
      ecode = sa;
    }
  } else if (code.isEmpty &&
      cm.stubcode == null &&
      (cm.stubkind == StubKind.iffi || cm.stubkind == StubKind.elfi)) {
    code = '      /* Here goes your "condition is true" code. */$osNL';
    ecode = '      /* Here goes your "condition is false" code. */$osNL';
  } else {
    ecode = code;
  }
  if (!cm.zebra) {
    ecode = '';
  }
  var el = code.isEmpty || code.endsWith(osNL) ? '' : osNL;
  var g = cm.guard;
  // var g = _guard();
  generator:
  switch (cm.stubkind) {
    case StubKind.elfi:
      s.writeln('// // { ${g}___: #ifconf $fls');
      s.write(code);
      s.write(el);
      s.writeln('/* //}{ $g```: #else ! $fls');
      s.write(ecode);
      s.write(el);
      s.writeln('*/ // } $g^^^: #efi @! $fls');
      break;
    case StubKind.iffi:
      s.writeln('// // { ${g}___: #ifconf $fls');
      s.write(code);
      s.write(el);
      s.writeln('// // } $g^^^: #efi @@ $fls');
      break;
    case StubKind.tagt:
      s.writeln(cm.cfgLines.targetPragma);
      break;
    case StubKind.bcon:
      var ext = 'filext';
      var bra = cm.cfgLines.branches.join(' +');
      var ubr = '';
      var co = cm.stubco;
      ext = co.isEmpty ? 'filext' : co[0];
      if (co.length > 1) {
        var jn = co[1][0] == '+'
            ? co[1][0]
            : co[1][0] == '-'
                ? co[1][0]
                : '+';
        ubr = cm.stubco
            .sublist(1)
            .map((e) => !e.startsWith(jn) ? '$jn$e' : e)
            .toList()
            .join(' ');
      }
      s.writeln('// // @ FileFor:: #$ext ${ubr.isEmpty ? '// +$bra' : ubr}');
      break;
    case StubKind.line:
      code = code.isEmpty
          ? ' Here goes your code. Must be short!'
          : code.trimRight();
      var fl = cm.arg.isEmpty ? '+Flag' : cm.arg[0];
      if (fl.codeUnitAt(0) != 43 && fl.codeUnitAt(0) != 45) {
        s.writeln('// Error: only -flag or +flag supported!');
        s.write(oCode);
        break generator;
      }
      int fllen = fl.toBytes().lengthInBytes;
      if (fllen < 2 || fllen > maxFlagLen + 1) {
        s.writeln('// Error: use shorter flag - "$fl" is over 7bytes long!');
        s.write(oCode);
        break generator;
      }
      if (!cm.zebra && code.contains(osNL)) {
        s.writeln('// Error: only single line can be provided for Line stub!');
        s.write(oCode);
        break generator;
      } // zebra can do more lines at once
      var cmult = code.split(osNL); // TODO CRLF issue (#211)
      for (var cl in cmult) {
        // line pragma is shorter by 6 as it has #nothing past sharp
        if (cl.length + pragmaLength - 6 > 79) {
          s.writeln(
              '// Error: pragma + code must be shorter than 79 characters!');
          s.writeln('// /* @ +Flag***: # */');
          s.write(oCode);
          break generator;
        }
      }
      // cmdline @branch checks should make sure we have +-flag of @branch set
      while (fllen < maxFlagLen) {
        fl += '*';
        fllen++;
      }
      String hOdd;
      String zOdd;
      if (!cm.zebra) {
        hOdd = fl.codeUnitAt(0) == 43 ? '/* // @' : '// /* @';
        zOdd = fl;
        s.writeln('$hOdd $zOdd*: # */ ${cmult[0]}');
        break;
      }
      zOdd = '+${fl.substring(1)}';
      hOdd = fl.codeUnitAt(0) == 43 ? '/* // @' : '// /* @';
      var zEvn = '-${fl.substring(1)}';
      var hEvn = fl.codeUnitAt(0) != 43 ? '/* // @' : '// /* @';
      for (var cl in cmult) {
        s.writeln('$hOdd $zOdd*: # */ $cl');
        s.writeln('$hEvn $zEvn*: # */ $cl');
      }
      break;
    case StubKind.swca: // already serviced at top
      break;
    case StubKind.swth:
      var usel = cm.cfgLines.stubKnobParts(clivar: true);
      var parts = cm.cfgLines.stubKnobParts();
      var pvars = parts.sublist(1);
      var kn = parts[0];
      if (usel.isEmpty || usel[0].isEmpty || parts.isEmpty) {
        s.writeln(
            '// Error: likely no knob.variant was provided or it was wrong.');
        s.write(oCode);
        break generator;
      }
      var ucom = usel.join('');
      var from = parts.join('');
      var fRoM = pvars.map((e) => e == usel[1] ? e : e.toUpperCase()).join('');
      var frOm = pvars.map((e) => e == usel[1] ? e.toUpperCase() : e).join('');
      var fill = code.isEmpty;
      if (fill) {
        el = osNL;
        code = '       /* Here goes your "default" case code... */$osNL';
        ecode = '       /* Here goes your "$ucom" variant code... */$osNL';
      }
      if (usel[1].codeUnitAt(1) != 42) {
        s.writeln('/* // { $g...: #switch ${usel[0]}.* from $kn$fRoM');
        s.write(code);
        s.write(el);
        s.writeln('*/ //}{ $g---: #caseof $ucom from $kn$frOm');
        s.write(ecode);
        s.write(el);
        s.writeln('// // } $g^^^: #esw OF $from');
        break;
      } // else exhaustive
      int next(int i) {
        i++;
        if (i >= parts.length) return 0;
        var uv = parts[i];
        ucom = '${parts[0]}$uv';
        frOm = parts.map((e) => e == uv ? e.toUpperCase() : e).join('');
        if (fill) {
          code = '       /* Here goes your "$ucom" variant code... */$osNL';
        }
        return i;
      }
      next(0); // 1st goes to switch
      s.writeln('// // { $g...: #switch $ucom from $frOm');
      s.write(code);
      s.write(el);
      next(1);
      s.writeln('/* //}{ $g---: #caseof $ucom from $frOm');
      s.write(code);
      s.write(el);
      for (var i = next(2); i > 0; i = next(i)) {
        s.writeln('// //}{ $g---: #caseof $ucom from $frOm');
        s.write(code);
        s.write(el);
      }
      s.writeln('*/ // } $g^^^: #esw OF $from');
      break;
    case null:
      s.writeln('// Retarget Internal Error: Not a known stub kind');
  }
  ts = ts; // if temp not used
  tn = tn;
  stdout.write(s.toString());
}
