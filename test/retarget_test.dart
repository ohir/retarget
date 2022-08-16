@Timeout(Duration(seconds: 5))

import 'dart:io';
import 'dart:typed_data';

import 'package:retarget/retarget.dart';
import 'package:retarget/rtconf.dart';
import 'package:retarget/walker.dart';
import 'package:test/test.dart';

/// test cases operate on --sample string, using --init flags @main
class TaskOf {
  final String tna; // test name
  final String cli; // commandline
  final String ers; // linter errs, if given
  final String chg; // changes string form
  TaskOf(this.tna, this.cli, this.ers, this.chg);
  bool chgDiffers(TaskRes r) => chg != r.chg;
  bool ersDiffers(TaskRes r) => ers != r.ers;
}

class TaskRes {
  String ers; // linter errs, if given
  String chg; // changes string form (bytepos, character)
  TaskRes(this.chg, this.ers);
}

/* --init @main config, to apply on --sample file in tests
main: +dev *loud =lbe *i18n !🦄 !release       # +lbe -🦄 -release forced
main: .?os .apos .+droid .lin .win .web        # platform knob
main: .?screen .desk .=mobile .tv              # display knob
main: .?store .fibase .icloud .dsql .+locbe    # storage knob, +dev uses +locbe
main: .?native .amd .+arm .losong .mips        # for NDK includes generator
*/
var rtInp = <TaskOf>[
  TaskOf('pristine', '', '', 'nochg'),
  TaskOf('os.lin', 'os.lin', '', ' BW1'),
  TaskOf('os.win', 'os.win', '',
      ' BW1 1522* 1525/ 2366/ 2367* 2481* 2482/ 2602/ 2603/'),
  //TaskOf('set.', 'os.lin', '', ''),
  TaskOf('unset.dev', '-dev', '', ' BW1 1990/ 1991* 2107* 2108/ 2225/ 2226/'),
  TaskOf('set.i18n', '+i18n', '',
      ' BW1 1732/ 1733/ 1849/ 1850/ 1990/ 1991* 2107* 2108/ 2225/ 2226/'),
  TaskOf(
    'screen.desk',
    'screen.desk',
    '  - [cli] "screen.mobile" is forced in "@main"\n',
    '',
  ),
  TaskOf(
    'force.screen.desk',
    'screen.=desk',
    '',
    ' BW1 2733/ 2734/ 2860/ 2861* 2991/ 2992/',
  ),
  TaskOf(
    'force.screen.tv',
    'screen.=tv',
    '',
    ' BW1 2860/ 2861/ 2991* 2992/ 3114/ 3115/',
  ),
];

late int sampleLast;

void main() {
  var bu = u8co.encoder.convert(samplePragmas);
  sampleLast = bu.lengthInBytes - 1;
  var cfl =
      sampleFlagsBig.split('\n').map((e) => e.split(' #')[0].trim()).toList();

  /// Integrity test for the apply engine
  test('Wholesale regression test', () {
    for (var ti in rtInp) {
      var arg = ti.cli.isNotEmpty ? ti.cli.split('\n').toList() : <String>[];
      var cfgLines = CfgLines('main', cfl, arg, false);
      var ers = cfgLines.err.toString();
      expect(ers, equals(ti.ers));
      if (ers.isEmpty) {
        var cfg = Config(
          dir: Directory('/nonexistent'),
          cfl: cfgLines,
          clibuf: null,
          dry: false,
          force: false,
          loud: false,
          fixG: false,
          diags: false,
          silent: false,
        );
        var ofs = '/testing/${ti.tna}';
        var res =
            fchgAsStr(parseBufferSync(cfg, Uint8List.view(bu.buffer), ofs));
        expect(res, equals(ti.chg), reason: ofs);
      }
    }
  });
}

String fchgAsStr(FileChanges fchg) {
  var rc = StringBuffer();
  int last = sampleLast;
  if (fchg.chlist == null) return 'nochg';
  for (var chg in fchg.chlist!) {
    int at = chg & 0x3fffffff;
    int i = chg >> 30;
    if (chg < 0) return 'INVALID change came [$chg]';
    while (i > 0) {
      int o = (i >> 7) & 0x1ff;
      int c = i & 127;
      if (at + o > last) return 'INVALID change past EOF [$chg]';
      i >>= 16;
      if (c <= blockWrite4 && c >= blockWrite1) {
        switch (c) {
          case blockWrite1:
            if (at + 257 > last) return 'INVALID block change past EOF [$chg]';
            rc.write(' BW1');
            break;
          case blockWrite2:
            rc.write(' BW2');
            break;
          case blockWrite3:
            rc.write(' BW3');
            break;
          case blockWrite4:
            rc.write(' BW4');
            break;
        }
      } else {
        rc.write(' ${at + o}');
        rc.writeCharCode(c);
      }
    }
  }
  return rc.toString();
}
