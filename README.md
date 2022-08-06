## Synopsis:

The `retarget` tool takes a set of _flag_ identifiers then comments-out or
uncomments spans of code marked with in-comment pragmas.  Tool does apply
changes according to user defined rules, each be set with flag predicates
on a pragma. Eg. `retarget @ -ios +dev` will comment-out code spans marked
with `+ios` and activate code spans marked with `+dev` (_dev_ not shown in
the example code below).

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
_"Guard" of a five random characters binds pragma lines into a single set._

New pragma set can be generated with the `--stub` family options to the command,
usually hooked to the IDE action. Eg. vim's `:r! retarget --stubel @ +ios *dev`
command was used to generate the three `#ifconf/else/efi` pragma lines above.


### Flag expressions for selecting code configuration

As seen at example, `retarget` _if_ pragmas consist of a distinctive header
followed by a logical condition made of identifiers (flags), each prepended
with either if-set(+), if-unset(-), or is-irrelevant(*) predicates.

  - +flag : activate span if "flag" is given to the `retarget` for apply
  - -flag : activate span if "flag" is NOT given, or given with `-` prefix
  - *flag : "flag" state is irrelevant for this span

Code span is uncomented only if all +/- predicates are met (logical AND) -
otherwise the enclosed code is commented-out using C style comments `/* */`.
If there is an `#else` pragma present, one or either span is activated,
according to the `#ifconf` expression value.

Only expressions on the `#ifconf` pragma matters to the tool. Ones on `#else`
and `#efi` are meant for the reading human. If they diverge, eg. after the
`#ifconf` line edit, tool will fix predicates on `#else`/`#efi` itself.


## Knobs (switches)

`One of` type switches can be used to exclusively select an active code
span from among up to six. Switches can be exhaustive (ie. where all cases
defined in the `retarget.flags` must be present and linter checks for the
cases' completeness). Or they can have a default code span that activates
if no specific case is selected. Default span is always the first one and
its condition is given on the `#switch` pragma as `kname.*`.  Exhaustive
switch has one of its case conditions given right to the `#switch` pragma.

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

This pragma turns on/off a single line content (following the pragma) with
condition being a single flag or a knob variant (+being set or -not).

BEWARE! For now `dart format` MAY break your line pragma guarded code if
it deems it too long.  It honors 1st column `//`, but it thinks that it
is permitted to move /* comments */ at will. There is [an issue]() filled
for changing this behavior. You may hand-up there, if you're affected.

Especially DO NOT use line pragmas deep in Flutter code.  Nor set your IDE
to use higher `dart format --line-length` (it will break for others).
IOW for now use Line pragma just for a single include. If you have more than
one include under same condition it is better to keep them all within
`#ifconf` or `#switch` scopes.


## Target configuration info

Target info helps reading human to figure out the set code configuration.

``` dart
/* // @ :Target:: # @main +dev -ios +lbe -i18n -release ᛫᛫᛫᛫|
 .os.droid .screen.mobile ᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫᛫*/
```

Target pragma will be updated on each `retarget` apply to contain all
pieces (branch, flags with state, knobs' selected variants) that were
last used to configure the code tree.

_Do NOT touch (remove, add, adjust) the filler dots. As other retarget
pragmas this one is also a fixed-shape construct. Unlike other pragmas,
`Target` uses unicode characters (\\u16eb middots)_

> While _Target_ pragma can be put on every file, it really should be kept
> only on a single one, typically one that contains program main entry
> (to not pollute source versioning repository with superfluous copies of
> the same changes).


## Default code configurations

To allow for consistency checks `retarget` tool needs to know all flags
to be used and their state.  While all flags and knob variants might be
given at every `retarget` invocation, it would be cumbersome and error-prone.
Hence `retarget` allows user to define flags, knobs and their most-likely state
in a text file named `retarget.flags`, meant to be kept alongside `pubspec.yaml`
in the project's root directory (name and location are fixed).

The `retarget.flags` file may keep default configurations for more than
one named branch of code.  Then per-branch can be applied simply by calling
`retarget @bname` (the bare `@` summons "main:" branch configuration).
The `main` branch can be the only one, but it must be configured for cli use.
When `retarget` runs, any flag not explicitly given after `@bname ` on the
cli is sourced from the `retarget.flags` template for the given branch.
_(Term: `@bname` (@branch) construct is called a "branch selector".)_

> _You can create a rich example of `retarget.flags` file using
> `retarget --init > retarget.flags` command. Also a complementary sample
> source file can be made using `retarget --sample > lib/rtsample.dart` command.
> Together these allow you to learn tool fast just by plaing with examples._


### fend off invalid configurations

Flags in a branch template can be set as _forced_, so they may not be
unwittingly abused (set or unset after @bname) to select a nonsensical
code configuration or to `--stub` produce a nonsensical pragma condition.
Final flag shape and state can be forced in .flags using `!` for `-`,
`=` for `+`, and `%` for `*`. Details are documented in the sample file.

Eg. `apmob: !dro !mips =ios *dev %test` will template a pragma expression
of  `-dro -mips +ios *dev *test`, allowing user to override only the "dev".
Would user try to change expression eg. giving `--stub @apmob +mips`, tool
linter will tell her that `+mips` is not meant for this branch at all.
Nor she could override it just for apply with `retarget @apmob +mips`.

Forced defaults make harder to produce a pragma expression that does not
fit with the given branch code configuration, and it makes harder to
come with a source state that may not compile, or worse.

> _Without restrictions and current flags/knob/variants limits being 7,7,6,
respectively, you might need to test your source for over 15M distinct
code configurations. Are you ready to test them all?_


### Everyday usage tips

 - Save all files opened in your IDE before applying configuration!
   Otherwise your code migh not compile, or – in the worst case –
   you may end with a couple of heisenbugs lurking.
 - Keep retarget branch names and your git/svn/fossil branch names in sync
 - Have your work commited in the working branch before you apply changes.
 - git diff after changes. Cleanly applied configuration should have only
   a few pragma lines showing in the diff.
 - To avoid pollution of upstream repository with pragma select diffs, a single
   configuration of the main branch should always be applied via a precommit
   hook to all files coming form branches of other code configurations.
 - Every and each SVCs branch should touch only its own `retarget` branch
   configuration lines in `retarget.flags` file. To ease on diff and merges
   later on, `branch:` lines for a given branch should be surrounded by enough
   non changing comment lines.
 - retarget is still a **beta** and possibly will be for long. Caveat emptor!


### Pragma edit tips:

1. use `--stubli --stubif --stubel --stubsw --stubca --stubtag` to add
   pragmas. Let tool make a well formed pragma. You can't do this by hand.
1. The only places human is expected to _overwrite_ in a generated pragma
   are condition flag predicates __+ - *__, and, with care, knob selectors.
1. Span pragmas should be put alone in a separate line.
   Otherwise `dart format` may surprise you in least expected ways.
1. Pragmas' span should close over a natural code scope. Ie. all parenthesis,
   brackets, and braces within a pair of pragmas must be balanced (not linted).
1. Pragma enclosed spans can be nested, but for now there is no lint whether
   inner span will ever activate. If sponors came, such lint could be made.
1. The retarget.flags should provide (almost) everything. Its easier to work
   with `retarget @appl` and `retarget @droid` commands than *think* about how to
   set state on four flags plus three knob variants with each call to `retarget`.
1. Thinking two to five flags is somehow manageable. Dealing with more __IS_NOT__.
   The same rule applies to branches, knobs and knob variants. Make your branch
   template to have as few moving parts (non-forced flags/variants) as posssible.
1. DO NOT abuse the power. Do not sprinkle your source file with dozens of
   pragmas. The `retarget` parser will understand the flow, humans will not.
   Single knob, plus single if/else nested spans (or vice-versa) are ok.
   Five nested knobs in a file will eat all your legs soon. Stay modest!


### You can not remove a flag!

Adding a flag, or knob, or knob variant is easy. Removing a flag or knob
variant is next to impossible. Once even a smallest sliver of app logic
that depends on a given code configuration was written, a way back closes
fast and thight.

> once there were tool options to add/rename configuration pieces, but
> these were retracted. Just plan carefully ahead.


### Windows™ caveats

Windows™ shell warning: before **printing** `:Target:` pragma on the
Windows™ built-in shell window (older powershell.exe including) configure
it to use utf-8 encoding (via `chcp 65001` command). Or better switch to
"Windows Terminal" that is more utf-8 aware than other Windows shell
managers and set its profile to use utf-8. Redirecting Target pragma
to file, or getting it from `--stubtag` via VSCode/vim pipe command
should be fine, but manual shell operations with cmd.exe and powershell.exe
still need you to configure cp65001 environment on per-session basis.


### Project state

 [x] Retarget basic functionality (done)
 [x] Lint for most common mistakes in `retarget.flags` config file (done)
 [x] Lint for most common failures after copy/paste source edits (done)
 [x] Copy user edits of condition to the other pragma lines in a set (done)
 [ ] In-project Dart powered test suite (TBD)
 [ ] rich regression tests suite (TBD)


### Files

`pubspec.yaml`   Its presence tells the code tree root.
`retarget.flags` keeps at least one defined configuration. If not present
                 beside `pubspec.yaml` and `--defcf` is not given tool
                 will exit. (No config, no fun).

### Env
```
RT_DEFCF      can be used instead of --defcf to define code configuration.
RT_PKGDIR     can be used instead of --dir providing path to a package tree
RT_ERRCODES   if merely set to anything, exit with error returns non-zero
              as if retarget ran with --silent. Helps debuging CI scripts.
              Interactive session normally should not bother user with
              error exit code - error messages are printed.
              Also some IDEs (notably VSCode vim extension) may even hang
              editor on non zero exit that prints to stdout a few kB.
```
[See vim-plugin issue #7835](https://github.com/VSCodeVim/Vim/issues/7835)


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
                 that (ACL) lack of permissions won't break --apply later.

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

Retarget is a tool, not a lib. It is dual licensed under CC BY-ND license
for all, and under BSD-3 clause license for "company license tier" Github
Sponsors. Both licenses text is to be found in the LICENSE file.
