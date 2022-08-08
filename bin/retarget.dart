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
import 'package:retarget/cmd.dart' as cmd;

void main(List<String> argi) {
  exitCode = 0;
  var dDBG = Platform.environment['RT_DEBUG'] == null ? false : true;
  if (argi.isNotEmpty && argi[0] == '--debug') {
    dDBG = true;
    argi = argi.sublist(1);
  }
  try {
    cmd.dispatch(argi);
  } catch (e, s) {
    if (dDBG) {
      print(e);
      print(s);
      exit(0);
    } else {
      print(topfail);
    }
  }
}

const topfail = '''

Hi, retarget author here,

Obviously something went wrong!

Usually you see this message because your retarget.flags file is corrupt.
We do rudimentary checks on it, but we will not waste time/money to guard
against any fancy mismatch that could somewhen be put there.
Read the docs!

TL;DR - make sure that:
 - every element is separated by a single space (NOT a tab character!)
 - branch: entries must start at column 1 (start of the line)
 - # whole line comment should also begins the line
 - # to-end-of-line comment must be separated by a space

Other common reason for failure is when ' -- *' is given as for "all files"
and os throws at retarget also binary, json and anything. '-- file,file,...'
is for CI and IDE plugins use. You should not pick it "because i can glob".
Retarget tool is meant for Dart code. It normally pick files by itself, but
when you throw at it binary blobs it possibly will choke.

If you really are sure you're ok and retarget is not ok, use --debug
AS THE FIRST argument, rerun, see a stack trace, PREPARE reproduction
case - then report bug opening issue at retarget site:
    https://github.com/ohir/retarget/issues

C'ya there. Ohir.

''';
