### simple configuration
```
# retarget.flags
main: *dev *loud                               # flags
main: .?os .+ios .android .mac .lin .win .web  # platform (knob)
```

 - `+loud` flag enables _firehose logging_ code normally not wanted in production app that millions might use
 - `+dev` flag to switch between in-house/development backends (URIs/Credentials) and that of production environment in the cloud.
 - `os` target platform _knob_ allows us to be sure that large swaths of UI code dealing with target platform specific layouts do not ship for other platforms.


### built-in example files

For the learning (and test) purposes tool can produce example `retarget.flags` and example file that contains all pragmas. With these two you can create your own playground:

```
$ dart create -t package learnrt
$ cd learnrt
$ retarget --init > retarget.flags
$ retarget --sample > lib/rtsample.dart
```

Content of both files for `pub.dev` readers:

```dart
// retarget --sample > lib/rtsample.dart
//
/* // @ :Target:: # @main +dev -loud +lbe -i18n -🦄 -release ᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫|
 .os.droid .screen.mobile .store.locbe .native.arm ᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫*/

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
   retarget @desk os.win -dev \=🦄       # override forced -🦄
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
// /* @ +web****: # */ import 'dart:html'
/* // @ -web****: # */ import 'dart:io'


//--- Simple If ----------------------------- stub: --stubif @branch ---
//
/* // { zkhuk___: #ifconf +dev *loud +lbe +i18n -🦄 -release
      /* Here goes your "condition is true" code. */

*/ // } zkhuk^^^: #efi @@ +dev *loud +lbe +i18n -🦄 -release


//--- If with Else -------------------------- stub: --stubel @branch ---
//
// // { tmmjj___: #ifconf +dev *loud +lbe -i18n -🦄 -release
      /* Here goes your "condition is true" code. */

/* //}{ tmmjj```: #else ! +dev *loud +lbe -i18n -🦄 -release
      /* Here goes your "condition is false" code. */

*/ // } tmmjj^^^: #efi @! +dev *loud +lbe -i18n -🦄 -release


//--- Knob switch -------------- stub: --stubsw @branch knob.variant ---
//
// // { ultmx...: #switch .os.* from .os.APOS.DROID.LIN.win.WEB
       /* Here goes the "default" case code... */

/* //}{ ultmx---: #caseof .os.win from .os.apos.droid.lin.WIN.web
       /* Here goes your ".os.win" variant code... */

*/ // } ultmx^^^: #esw OF .os.apos.droid.lin.win.web


//--- Exhaustive knob switch ------- stub: --stubsw @branch "knob.*" ---
//
/* // { fystw...: #switch .screen.desk from .screen.DESK.mobile.tv
       /* Here goes your ".screen.desk" variant code... */

*/ //}{ fystw---: #caseof .screen.mobile from .screen.desk.MOBILE.tv
       /* Here goes your ".screen.mobile" variant code... */

/* //}{ fystw---: #caseof .screen.tv from .screen.desk.mobile.TV
       /* Here goes your ".screen.tv" variant code... */

*/ // } fystw^^^: #esw OF .screen.desk.mobile.tv
```

```
# retarget --init > retarget.flags
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
main: +dev *loud =lbe *i18n !🦄 !release       # +lbe -🦄 -release forced
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
```
