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

import 'walker.dart' as walk;
import 'stubgen.dart' as stub;
import 'retarget.dart';
import 'cmline.dart';

void dispatch(List<String> argi) {
  final cm = Cmline(argi);
  dp = cm.dp; // have cmdline processed, now set error priter (global)
  if (!cm.pkgOk) {
    exit(dp(33, 'Something went wrong!'));
  }
  if (cm.stubkind != null) {
    stub.out(cm: cm);
    exit(0);
  }

  var forfi = cm.files.isNotEmpty ? cm.files.join(' ') : '';
  var actva = cm.cfl.activeKnobVariants;
  if (cm.cfg.diags) {
    print('\n\n\n---------------- ${DateTime.now()} ----------------');
    print('''
 Applying configuration @${cm.cfg.branch} in
     dir: ${trimPath(cm.cfg.dir.absolute)}
   flags: ${cm.cfgLines.selFlags}
   knobs: ${actva.isNotEmpty ? actva : 'not used'}
 cmfiles: ${forfi.isNotEmpty ? forfi : 'not provided'}
''');
  } else if (cm.cfg.loud) {
    print('Applying @${cm.cfg.branch} in ${trimPath(cm.cfg.dir)}');
  }
  var work = walk.findWorkSync(cm.cfg);
  var done = walk.parseWorkSync(work, cm.cfg);
  var rmsg = walk.applyWorkSync(done, cm.cfg);
  if (rmsg.isNotEmpty) print(rmsg.trim());
  if (cm.cfg.diags) {
    print('---------------- ${DateTime.now()} ----------------');
  }
}

/// stub function called with -Q
void quickdevel(List<String>? clifla, {bool cfg = false}) async {}
