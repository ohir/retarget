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

// TODO nag
// TODO goldenfile hash based tests
// TODO refactor sublisting to creating views
// as in var kname = Uint8List.sublistView(bu, a.fl + 1, i);
// sublist does a copy _immediately_, it is not a COW (why ah why?)

const _max = 7; // this can only be set lower. Better DO NOT TOUCH!
/* Why 7?  1st: to not require changes in default dartfmt settings
           2nd: for the code maintainers' sake. (2^7*7^7 = 105413504)
           3rd: code-config bsob fits nicely in 8 cpu cache lines */
const maxFlags = _max;
const maxFlagLen = _max;
const pragmaLength = 18 + 10; // pgLine is 21 but makes no sense w/o following
const maxFS = (1 << 30) - 1;
const pgFillCh = 0x16eb; // ᛫
const blockWrite1 = 17; // used for Tag (:Target::)
const blockWrite2 = 18;
const blockWrite3 = 19;
const blockWrite4 = 20;

// vim zebra :'<,'>!retarget -z @ -win
// /* @ +win****: # */ const osNL = '\r\n';
/* // @ -win****: # */ const osNL = '\n';
// /* @ +win****: # */ const osSEP = '\\';
/* // @ -win****: # */ const osSEP = '/';
// /* @ +win****: # */ const osSEPcu = 92;
/* // @ -win****: # */ const osSEPcu = 47;
const osCR = 13; // file may use LF endings on windows, or CRLF on unix

/* NOTES section
   late final UnmodifiableUint8ListView pglead; This is advertised,
   it does have docs, but it is *for internal Google use only*
   (for use as a wrapper for the native vm kernel code under).
 */

// globals
final List<String> ourSubdirs = <String>['lib', 'bin', 'test'];
final List<String> ourFileExt = <String>['.dart', '.rtoff', '.rtdart', '.yaml'];

// enums
enum PgType {
  unk,
  isIf,
  isFi,
  isEfi,
  isElse,
  isBcon,
  isLine,
  isSwth,
  isSwdf,
  isCase,
  isEsw,
  isTag,
}

enum PgErr {
  eNone,
  eOther,
  eEmpty,
  eNoFlag,
  eBadCh,
  eBadSp,
  eBadFlags,
  eBadMark,
  eCaseDefault,
  ePrevious,
  eShape,
  eOrphaned,
  eSurplusCopyOfPart,
  eMisplaced,
  eMisplacedIf,
  eMisplacedFi,
  eMisplacedElse,
  eMisplacedEfi,
  eMisplacedSw,
  eMisplacedCase,
  eMisplacedSwDef,
  eMisplacedEsw,
  eMisplacedScope,
  eIncomplete,
  eBadFinal,
  eTooBigFile,
  eOverlap,
  eOverlappingScope,
  eUnknown,
  eMisspelledKnobName,
  eUnknownKnobName,
  eUnknownVarName,
  eTooManyVariantsInBar,
  eBadFromVariantsInfo,
  eIncompleteVariantsInfo,
  eNoCodeToActivate,
  eNotAllCasesGiven,
  eDefaultOnExhaustiveSw,
  eTooManyCaseofs,
  eCulprit, // set on culprit in pragsets
  eBcNotFirst,
  eGuardNotMatch,
  eGuardNotUniq,
  eGuardPadUnk,
  eNotBelongs,
  eNotBelongsMyErr,
  ePrecedingHasErr,
  eCantBeAtFirstByte,
  eListConditionsDiffer,
  eWrongTagSize,
  eTooMuchToFix,
}

typedef ChgItem = int;
typedef CfgItem = int;
typedef DPf = int Function(int ec, String v);
DPf dp = (ec, _) => ec;

String trimPath(FileSystemEntity f) {
  var path = f.absolute.path;
  var tn = path.indexOf('$osSEP.$osSEP');
  if (tn >= 0) path = path.substring(tn + 3);
  return path;
}

void phere([String s = '']) {
  print('Here: $s');
}

const sampleFlagsBig = '''# retarget.flags
# This sample flags file is for a really big shop. Play a bit with it then
# stick to two flags (eg. +dev +loc) and two knobs (eg. .os, .screen).
# Two plus two equals sixty! Ie. that many integration test cases you might
# need (4 states from two flags, × 5 states of .os knob, × 3 screen sizes).
# This configuration template works with `--sample > lib/filename.dart` test.
#
# Flags:
#     +dev   under development - +dev code may have dragonbugs lurking.
#    +loud   turns on firehose of logs (makes app to crawl on older devices)
#     +lbe   in-house backend, forced. Unset for flytests on AWS/Azure/GCE
#     +18n   apply only to the stable parts of the app (after translations
#            for a given feature were loaded to the cloud and vetted)
#      !🦄   You may not do unicorns until you're able to make ordinary ponies
#            happy.   Ie. "would be nice to have" big features are behind +🦄.
# !release   +release enables production backends, & guards local dev secrets.
#            You can not pass code to release signer pipeline unless you
#            override forced -release state (set +18n -loud -lbe -dev too).
#            Read the docs, and release rules, Luke!
#
main: +dev *loud =lbe +i18n !🦄 !release       # +lbe -🦄 -release forced
main: .?os .apos .+droid .lin .win .web        # platform knob
main: .?screen .desk .=mobile .tv              # display knob
main: .?store .fibase .icloud .dsql .+locbe    # storage knob, +dev uses +locbe
main: .?native .amd .+arm .losong .mips        # for NDK includes generator

### iOS/macOS
apdev: +dev *loud =lbe *i18n !🦄 !release      #
apdev: .?os .=apos .droid .lin .win .web       # iOS/macOS forced
apdev: .?screen .desk .+mobile .tv             # phone/tablet
apdev: .?store .!fibase .icloud .!dsql .+locbe # icloud only
apdev: .?native .amd .+arm .!losong .!mips     # amd/arm only

### Android
drodev: +dev *loud =lbe *i18n !🦄 !release     #
drodev: .?os .!apos .+droid .lin .!win .!web   # +lin allowed
drodev: .?screen .desk .+mobile .tv            # phone/tablet
drodev: .?store .fibase .!icloud .dsql .+locbe # icloud excluded
drodev: .?native .amd .+arm .losong .mips      # all cpus

### DeskOS
desk: +dev *loud =lbe +i18n !🦄 !release       #
desk: .?os .apos .droid .+lin .win .web        # web is for desk too
desk: .?screen .+desk .!mobile .tv             # chromecasted tv
desk: .?store .fibase .icloud .dsql .+locbe    # icloud excluded
desk: .?native .+amd .arm .losong .mips        # all cpus

### Release ### still require sign-offs to override forced -release
shipit: !dev !loud !lbe =i18n !🦄 !release
shipit: .?os .apos .+droid .lin .win .web
shipit: .?screen .desk .+mobile .tv
shipit: .?store .+fibase .icloud .dsql .!locbe
shipit: .?native .amd .+arm .losong .mips

### --- END ---

# line comments start with a sharp in the first column,
# to EOL comment begins at the # past flags or knob variants bar.
#
# ------ TL;DR docs -----------------------------------------------------
# bname: tells the branch name (one then summoned with `retarget @bname`)
#        next line should provide flags and their default predicates:
#        eg. bname: +flagA -flagB *flagC =flagD !flagE %flagF (up to 7)
#
# + - *  tells the stub engine what to put on a new #ifconf pragmas.
#        Also informs the apply engine of default state for the branch.
# = ! %  forbids to simply override respective +, -, or * on the cli.
#        Overrides on the cli must be then forced too.
#
#        Next are knob definitions (up to 7 knobs up to 6 variants each):
# .?name    makes a knob, .variant names follow (min:2 max:6, 7th is .*)
# .+variant makes it a default for this knob (in a branch)
# .=variant forces it to be the only default, others may not be chosen
# .!variant forbids user to choose this variant (in a branch)
#
# All flag and variant names must be unique. Then all defined branches
# must have the same set of flags, knobs, and variants as "main:" has.
# Only predicates ( + - * % ! = ) on flags and variants may differ.
# Thorough the code pragmas must keep order estabilished in "main:".
# Main code configuration itself is one for the bare "retarget @".
''';

const samplePragmas =
    '''// retarget test file (complements `retarget --init` generated example config)
//
/* // @ :Target:: # @desk +dev -loud +lbe -i18n -🦄 -release ᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫|
 .os.web .screen.desk .store.locbe .native.amd  ᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫*/

//--- Target info (above) ------------------------ stub: --stubtag @ ---
//    always updated with the last applied configuration

/* A few commands to see how code spans below are activated/deactivated:

   retarget --init > retarget.flags       # sample branch configurations
   retarget --sample > lib/rtsample.dart  # produces this file
   retarget @                             # set state defined as 'main:'
   retarget @ -i18n                       # unset i18n @main
   retarget @desk +i18n                   # set i18n @desk
   retarget @desk +i18n -dev              # set i18n, unset dev @desk
   retarget @desk os.web +dev +i18n       # set web, set dev, i18n @desk
   retarget @desk os.win -dev \\=🦄       # override forced -🦄
   retarget @desk screen.=mobile          # override forbidden !mobile
*/

//--- Line switch --------------------------- stub: --stubli @ +name ---
//    single line switch on a single condition
//
// /* @ +🦄***: # */ import 'unicorns.dart';
/* // @ -🦄***: # */ import 'ponies.dart';

// Line switch recognizes also knob variants:
// /* @ +apos***: # */ import 'rt_cupertino.dart';
// /* @ +apos***: # */ import 'rt_macos_ui.dart';
// /* @ +win****: # */ import 'rt_fluent_ui.dart';
/* // @ +web****: # */ import 'dart:html'
// /* @ -web****: # */ import 'dart:io'


//--- Simple If ----------------------------- stub: --stubif @branch ---
//
// // { zkhuk___: #ifconf +dev *loud +lbe *i18n -🦄 -release
      /* Here goes your "condition is true" code. */

// // } zkhuk^^^: #efi @@ +dev *loud +lbe *i18n -🦄 -release


//--- If with Else -------------------------- stub: --stubel @branch ---
//
// // { tmmjj___: #ifconf +dev *loud +lbe *i18n -🦄 -release
      /* Here goes your "condition is true" code. */

/* //}{ tmmjj```: #else ! +dev *loud +lbe *i18n -🦄 -release
      /* Here goes your "condition is false" code. */

*/ // } tmmjj^^^: #efi @! +dev *loud +lbe *i18n -🦄 -release


//--- Knob switch -------------- stub: --stubsw @branch knob.variant ---
//
// // { ultmx...: #switch .os.* from .os.APOS.DROID.LIN.win.WEB
       /* Here goes the "default" case code... */

/* //}{ ultmx---: #caseof .os.win from .os.apos.droid.lin.WIN.web
       /* Here goes your ".os.win" variant code... */

*/ // } ultmx^^^: #esw OF .os.apos.droid.lin.win.web


//--- Exhaustive knob switch ------- stub: --stubsw @branch "knob.*" ---
//
// // { fystw...: #switch .screen.desk from .screen.DESK.mobile.tv
       /* Here goes your ".screen.desk" variant code... */

/* //}{ fystw---: #caseof .screen.mobile from .screen.desk.MOBILE.tv
       /* Here goes your ".screen.mobile" variant code... */

// //}{ fystw---: #caseof .screen.tv from .screen.desk.mobile.TV
       /* Here goes your ".screen.tv" variant code... */

*/ // } fystw^^^: #esw OF .screen.desk.mobile.tv

''';
