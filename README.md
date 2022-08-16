## conditional includes and code for Flutter and Dart

The `retarget` tool takes a set of _flag_ identifiers then comments-out or uncomments spans of code marked with in-comment pragmas.  Tool does apply changes according to user defined rules, each be set with flag predicates on a pragma. Eg. `retarget @ -ios +dev` will comment-out code spans marked with `+ios` and activate code spans marked with `+dev` (_dev_ not shown in the example code below).

```dart
// /* @ +ios****: # */ import package:flutter/cupertino.dart
/* // @ -ios****: # */ import package:flutter/material.dart

  @override
  Widget build(BuildContext context) {
  /* // { guard___: #ifconf +ios *dev
    return const CupertinoApp(
      title: _title,
      home: MyStatefulWidget(),
    );
  */ //}{ guard```: #else ! +ios *dev
    return MaterialApp(
      title: _title,
      home: Scaffold(
        appBar: AppBar(title: const Text(_title)),
        body: const MyStatefulWidget(),
      ),
    );
  // // } guard^^^: #efi @! +ios *dev
  }
```
_guard is made of a five random characters that bind pragma lines into a single set._

New pragma set can be generated with the `--stub` family options to the command, usually hooked to the IDE action. Eg. vim's `:r! retarget --stubel @ +ios *dev` command was used to generate the three `#ifconf/else/efi` pragma lines above.


### Flag expressions for selecting code configuration

As seen at example, `retarget` _if_ pragmas consist of a distinctive header followed by a logical condition made of identifiers (flags), each prepended with either if‑set(+), if‑unset(-), or is‑irrelevant(*) predicates.

  - `+flag` : activate span if "flag" is given to the `retarget` for apply
  - `-flag` : activate span if "flag" is NOT given, or given with `-` prefix
  - `*flag` : "flag" state is irrelevant for this span

Code span is uncomented only if all +/- predicates are met (logical AND) - otherwise the enclosed code is commented-out using C style comments `/* */`.  If there is an `#else` pragma present, one or either span is activated, according to the `#ifconf` expression value.

Only expressions on the `#ifconf` pragma matters to the tool. Ones on `#else` and `#efi` are meant for the reading human. If they diverge, eg. after the `#ifconf` line edit, tool will fix predicates on `#else`/`#efi` itself.

## Knobs (switches)

`One of` type switches can select a single active code span from among up to six.  Switches can be exhaustive (ie. where all cases defined in the `retarget.flags` must be present and linter checks for the cases' completeness). Or they can have a default code span that activates if no specific case is selected. Default span is always the first one and its condition is given on the `#switch` pragma as `kname.*`.  Exhaustive switch has one of its case conditions given right to the `#switch` pragma.

```dart
// exhaustive switch of three variants:
//
/* // { ekwec...: #switch .screen.desk from .screen.DESK.mobile.tv
       /* Here goes your ".screen.desk" variant code... */
    log('desktop screen layout is active');

*/ //}{ ekwec---: #caseof .screen.mobile from .screen.desk.MOBILE.tv
       /* Here goes your ".screen.mobile" variant code... */
    log('mobile screen layout is active');

/* //}{ ekwec---: #caseof .screen.tv from .screen.desk.mobile.TV
       /* Here goes your ".screen.tv" variant code... */
    log('tv screen layout is active');

*/ // } ekwec^^^: #esw OF .screen.desk.mobile.tv
```
> _Terms: `.screen` is "a knob", or "knob name", `.tv`,
> `.desk`, `.mobile` are "variants", or "knob variant names"._

```dart
// simple switch (with #caseofs for two of five variants):
//
/* // { fxziz...: #switch .os.* from .os.ios.droid.LIN.WIN.WEB
       /* Here goes your "default" case code... */
    log('other OSes code span is active');

*/ //}{ fxziz---: #caseof .os.droid from .os.ios.DROID.lin.win.web
       /* Here goes your ".os.droid" variant code... */
    log('android code span is active');

/* //}{ fxziz---: #caseof .os.ios from .os.IOS.droid.lin.win.web
       /* Here goes your ".os.ios" variant code... */
    log('iOS code span is active');

*/ // } fxziz^^^: #esw OF .os.ios.droid.lin.win.web
```


## Line pragma

``` dart
/* // @ +win****: # */  include 'package:of_not_too_long_path.dart';
```

This pragma turns on/off a single line content (following the pragma) with condition being a single flag or a knob variant (+being set or -not).

**Beware!** For now `dart format` **may break** your line pragma guarded code if line end reaches past the 80th column.  It honors 1st column `//`, but it thinks that it is permitted to move /* comments */ at will (probably rigthful so).

Especially DO NOT use line pragmas deep in Flutter code.  Nor set your IDE to use higher `dart format --line-length` (it will break for others).  IOW for now use Line pragma just for a single include. If you have more than one include under same condition it is better to keep them all within `#ifconf` or `#switch` scopes.


## Target configuration info

Target info helps reading human to figure out the set code configuration.

``` dart
/* // @ :Target:: # @main +dev -ios +lbe -i18n -release ᛫᛫᛫᛫|
 .os.droid .screen.mobile ᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫*/
```

Target pragma will be updated on each `retarget` apply to contain all pieces (branch, flags with state, knobs' selected variants) that were last used to configure the code tree.

_Do NOT touch (remove, add, adjust) the filler dots. As other retarget pragmas this one is also a fixed-shape construct. Unlike other pragmas, `Target` uses unicode characters (\\u16eb middot)_

> While _Target_ pragma can be put on every file, it really should be kept only on a single one – typically one that contains program main entry. _Otherwise source versioning repository will be polluted with superfluous copies of the same changes_.


## Default code configurations

To allow for consistency checks `retarget` tool needs to know all flags to be used and their state.  While all flags and knob variants might be given at every `retarget` invocation, it would be cumbersome and error-prone.  Hence `retarget` allows user to define flags, knobs and their most-likely state in a text file named `retarget.flags`, meant to be kept alongside `pubspec.yaml` in the project's root directory (name and location are fixed).

The `retarget.flags` file may keep default configurations for more than one named branch of code.  Then per-branch defaults can be applied simply by calling `retarget @bname` _(`@bname` construct is called a "branch selector".)_. You can use bare `@` - this summons a "main" branch configuration, the only one mandated.  When `retarget` runs, any flag not explicitly given after branch selector on the cli is sourced from the `retarget.flags` template for the selected branch.

> _You can create a rich example of `retarget.flags` file using `retarget --init > retarget.flags` command. Also a complementary sample source file can be made using `retarget --sample >lib/rtsample.dart` command.  Together these allow you to learn tool fast just by plaing with generated examples._


### Fend off invalid configurations

Flags in a branch template can be set as _forced_, so they may not be unwittingly abused (set or unset after @bname) to select a nonsensical code configuration or to `--stub` produce a nonsensical pragma condition.  Final flag shape and state can be forced in .flags using `!` for `-`, `=` for `+`, and `%` for `*`. Details are documented in the sample file.

Eg. `apmob: !dro !mips =ios *dev %test` will template a pragma expression of `-dro -mips +ios *dev *test`, allowing user to override only the "dev".  Would user try to change expression eg. giving `--stub @apmob +mips`, tool linter will tell her that `+mips` is not meant for this branch at all.  Nor she could override it just for apply with `retarget @apmob +mips`.

Forced defaults make harder to produce a pragma expression that does not fit with the given branch code configuration, and it makes harder to come with a source state that may not compile, or worse.


### Everyday usage tips

 - Save all files opened in your IDE before applying configuration!  Otherwise your code migh not compile, or – in a worst case – you may end with a couple of heisenbugs lurking.
 - Have your work commited in the local working branch before you apply changes.
 - `git diff` after applying configuration. Cleanly applied configuration should have only a few pragma changes showing in the diff: `retarget` tool is still an early **beta** and possibly will be beta for quite a some time. _Caveat emptor!_
 - To avoid pollution of an upstream repository (with pragma select diffs) a single configuration of the main branch should always be applied via a precommit hook to all files coming form branches of other code configurations.
 - Do not push upstream _side_ code configurations (ones that override bare `@branch` settings).
 - Keep retarget branch names and your git/svn/fossil branch names in sync
 - Every and each SVCs branch should touch only its own `retarget` branch configuration lines in `retarget.flags` file.
 - To ease on diff and merges of `retarget.flags` later on, `branch:` lines for a given branch defaults should be surrounded by enough non changing comment lines.


### Pragma edit tips

1. use `--stubli --stubif --stubel --stubsw --stubca --stubtag` to add pragmas. Let tool make a well formed pragma. You can't do this by hand.
1. The only places human is expected to _overwrite_ are condition flag predicates __+ - *__, in a generated pragma and, with care, knob variant selectors.
1. Span marking pragmas should be put alone in a separate line.  Otherwise `dart format` may surprise you in a least expected way.
1. Pragmas' span should close over a natural code scope. Ie. all parentheses, brackets, and braces within a pair of pragmas must be balanced (there is no lint for that, it would be too slow and it would duplicate work of the analyzer).
1. Pragma enclosed spans can be nested, but for now there is no lint whether inner span will ever activate. If sponors came, such lint could be made.


### Stay modest

With retarget's flags/knobs/knob-variants limit being 7:7:6, respectively, you can still produce over 15 millions of distinct code configurations.

1. Thinking two to three flags is somehow manageable. Thinking three-to-five knob \#cases is somehow manageable. Anything more **is not**.
1. Do not sprinkle your source file with dozens of pragmas. The `retarget` parser will understand the flow, humans will not.  Single knob, plus single if/else nested spans (or vice-versa) per file are ok.  Five nested knobs filled with ifs will shot off all your legs soon.
1. Make each branch template to have as few moving parts (non-forced flags/variants) as possible. Let yourself to use at most `+/-dev`, `+/-loud` after the `@branch` that sets everything else for the target platform and screen.

Final warning: **with app in production you can not remove a flag!**

Adding a flag, or knob, or knob variant is easy. Removing a flag or knob variant is next to impossible once even a smallest sliver of app logic that depends on a new flag state was written.  Way to back off closes fast and tight with each additional line under a new condition. It is better to plan carefully ahead then stick with it for the project's life.

> once there were tool options to add/rename configuration pieces, but these were retracted. Do not ask for them to be brought back, please.



### Windows™ encoding caveats

1. Retarget works through sources on a raw (utf8) bytes level. It means it will not touch UTF-16LE encoded files at all. Generating pragmas through the shell pipe also needs an UTF-8 aware environment. Per session basis it can be done manually using `chcp 65001` command. Recent Windows cli solutions like "Windows Terminal", or "Cmder" are utf-8 aware and let you configure UTF-8 once for all via session profiles.
1. Line endings do not matter to `retarget`, except for the `:Target:` informative pragma that has two lines. Normally `:Target:` will adapt to the line endings convention _of the file_ at apply time, but it will be broken if your editor (or your git) will change line endings back and forth.


### Project state

 - [x] Retarget basic functionality (done)
 - [x] Lint for most common mistakes in `retarget.flags` config file (done)
 - [x] Lint for most common failures after copy/paste source edits (done)
 - [x] Copy user edits of condition to the other pragma lines in a set (done)
 - [x] Hint \#switch _default_ case scope with variants uppercased (done)
 - [x] Integration test of apply enginge (done)
 - [ ] Publish as a package on the `pub.dev` site
 - [ ] Tests for flags/cli linter (TBD, thats > 60 cases now)
 - [ ] CI pipelines support (`-S` and `--defcf` TBD)

_Main areas of concern now are Dart-native tests, then CI pipelines support._


### Files
```
pubspec.yaml    Its presence tells the code tree root.
retarget.flags  keeps at least one defined configuration. If it is not present alongside
                the pubspec.yaml, and CI's `--defcf` is not given either, tool will exit.
                Ie. No config – no fun.
*.dart          Tool target files
*.dartx         For testing tool itself, and for safe playing with "misbehaving" files
                for all users.

lib/**/*.dart   Only conventional Dart source locations are searched (recursively).
bin/**/*.dart
test/**/*.dart
```


### Env
```
- RT_DEFCF      can be used instead of --defcf to define code configuration.
- RT_PKGDIR     can be used instead of --dir providing path to a package tree
- RT_ERRCODES   if merely set to anything, exit with error returns non-zero as if
                retarget ran with --silent. Helps debuging CI scripts.
                For interactive sessions retarget does not bother user with error
                exit code - error messages for human user are printed out.
```
_Note: CI support, except RT\_ERRCODES, is just planned as of now_.


### Install from pub.dev

If you intend to use `retarget` tool with more than one project, you probably should install it globally. Please constrain global installation to a specific version (as a precaution against supply-chain exploits).
```
$ pub global activate retarget 0.1.0
```
_Better yet, install `retarget` straight from sources:_


### Install from github
```
cd yourworkspacedir
git clone https://github.com/ohir/retarget.git
cd retarget
dart pub get # ! get/update dependencies
dart analyze # should be ok
dart compile exe -o bin/retarget bin/retarget.dart # posix/wsl, add .exe for Win
cp bin/retarget ~/bin  # or /usr/local/opt/bin/ or where you keep local binaries
```


### retarget --help
```
Usage:
       retarget [options] @[bname] [+|-flag [...]] [[.]knob.variant] [...]]
                   (naked @ implicitly selects @main branch)

-h, --help       this page
-v, --verbose    Inform about progress
-d, --dir        Start at the given directory instead of default (current)
-n, --dry-run    Do not change anything, just check. Dry-run can be also
                 turned on by giving a single ' c' as last to command.
-S, --silent     Suppress printing errors. Sets $? to error # (for CI use)
    --apply      Walk the tree and apply target configuration (for CI use)
                 CLI does apply by default (unless given 'c' or --dry-run)
    --force      Perform some actions normally suppresed by lint errors.
                 If given to -n, a single byte test write will make sure
                 that lack of file permissions won't break --apply later.

pragmas:
    --stubif     generate #if/#efi pragma
    --stubel     generate #if/#else/#efi pragma
    --stubli     generate line pragma |expects @ +-condition
    --stubsw     generate #switch pragma |expects @ knob.var or "knob.*"
    --stubca     generate #else or #case from piped in #efi or #esw line
    --stubtag    generate "current configuration" pragma (updated later)
-g, --guard      Five ascii letters to use as guard (normally generated)
-z, --zebra      copy input code to every span of a newly generated stub
                 (without zebra piped code makes just to a single span)

examples:
    --init       prints example of a configuration template. You may redirect
                    output to a real file using ` >>retarget.flags`
    --sample     prints source that uses all pragmas.  Make real test file
                    redirecting output with eg. `>lib/rtsample.dart`
```


### License

Retarget is a tool, not a library. Not much of it can be reused. Hence it is dual licensed: under CC BY‑ND license for all, then under BSD 3‑Clause license for companies sponsoring project via Github Sponsors. Both licenses text is to be found in the LICENSE file.


### Support

If your company is shipping smaller and more robust Flutter apps with `retarget`'s help, please share a one programmer-hour per month to support tool maturing.  If you are an employee of such a company, please mention up the ladder that whatever a succesful business uses daily is support‑worthy. Thank you.
