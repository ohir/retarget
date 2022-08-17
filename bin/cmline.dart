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

import 'package:args/args.dart';

import 'rtconf.dart';
import 'stubgen.dart' show StubKind;
import 'retarget.dart';

// We may want to use other parser. Ie. NO opt['smth'] should leak
// Seal this
class Cmline {
  late final Config _cfg;
  late Directory wd;
  final Uint8List? clibuf;
  late final CfgLines cfgLines;
  late final String guard;
  late final String cfitem;
  late final String bname; // --branch || RT_BRANCH || 'main'
  late final List<String> stubco;
  late final List<String> files;
  late final List<String> arg;
  late final ArgResults _opt;
  late final DPf dp;
  late final bool chkrun; // dry-run asked for
  late final bool isCi; // --cibranch --defcf or RT_* env set;
  late final StubKind? stubkind;
  late final bool pkgOk; // --do we have real tree to work on
  late final bool forced;
  late final bool zebra; // -z flag given, multiply stub code
  String? stubcode; // code sample for stubs
  bool diag = false; // --verbose diagnostics

  Cmline(List<String> argi) : clibuf = pipedSync() {
    if (argi.isNotEmpty && argi.last.contains('printENV')) prnenv(argi);
    final parser = ArgParser(allowTrailingOptions: false)
      ..addFlag('help', abbr: 'h', negatable: false, help: 'this page')
      ..addFlag('verbose',
          abbr: 'v', negatable: false, help: "Inform about progress")
      ..addOption('defcf',
          hide: true,
          help: 'Provides configuration for CI. Not implemented yet.')
      ..addOption('cibranch', // for CI use only
          abbr: 'b',
          hide: true,
          help: 'Select a branch other than "main" OVERSEDES @bname!!!')
      ..addOption('dir',
          abbr: 'd',
          // defaultsTo: '.',
          help: 'Start at the given directory instead of default (current)')
      ..addFlag('dry-run',
          abbr: 'n',
          negatable: false,
          help:
              "Do not change anything, just check. Dry-run can be also\nturned on by giving a single ' c' as last to command.")
      ..addFlag('diag',
          hide: true,
          abbr: 'D',
          negatable: false,
          help: "Make human readable description of processed pragmas")
      ..addFlag('silent',
          abbr: 'S',
          negatable: false,
          help: "Suppress printing errors. Sets \$? to error # (for CI use)")
      ..addFlag('apply',
          negatable: false,
          help:
              "Walk the tree and apply target configuration (for CI use)\nCLI does apply by default (unless given 'c' or --dry-run)")
      ..addFlag('force',
          negatable: false,
          help:
              'Perform some actions normally suppresed by lint errors.\nIf given to -n, a single byte test write will make sure\nthat ACL lack of file permissions won\'t break --apply later.')
      ..addSeparator('pragmas:')
      ..addFlag('stubif', negatable: false, help: 'generate #if/#efi pragma')
      ..addFlag('stubel',
          negatable: false, help: 'generate #if/#else/#efi pragma')
      ..addFlag('stubli',
          negatable: false, help: 'generate line pragma |expects @ +-condition')
      ..addFlag('stubsw',
          negatable: false,
          help: 'generate #switch pragma |expects @ knob.var or "knob.*"')
      ..addFlag('stubca',
          negatable: false,
          help: 'generate #else or #case from piped in #efi or #esw line')
      ..addFlag('stubtag',
          negatable: false,
          help: 'generate "current configuration" pragma (updated later)')
      ..addFlag('stubco',
          hide: true,
          negatable: false,
          help: 'generate build constraints pragma |expects list of branches')
      ..addOption('ext',
          hide: true,
          help: 'Provide off-extension used by build constraints pragma')
      ..addOption('codetostub',
          abbr: 'k', hide: true, help: 'sample code to fill in stubs')
      ..addOption('guard',
          abbr: 'g',
          help: 'Five ascii letters to use as guard (normally generated)')
      ..addFlag('zebra',
          abbr: 'z',
          negatable: false,
          help:
              'copy input code to every span of a newly generated stub\n(without zebra piped code makes just to a single span)')
      ..addFlag('ucguard',
          hide: true,
          negatable: false,
          help: 'use also uppercase letters in generated guards')
      ..addSeparator('examples:')
      ..addFlag('init',
          negatable: false,
          help:
              "prints example of a configuration template. You may redirect\n   output to a real file using ` >retarget.flags`")
      ..addFlag('sample',
          negatable: false,
          help:
              "prints source that uses all pragmas.  Make real test file\n   redirecting output with eg. `>lib/rtsample.dart`")
      // ..addSeparator('refactor:        [NIY] not implemented')
      ..addFlag('fixguard',
          negatable: false,
          hide: true,
          help: '[NIY] fix wrong pragma on "follower". Works only via pipe.')
      ..addOption('addflag',
          hide: true,
          help: '[NIY] Adds an *irrelevant flag to all pragmas in code tree')
      ..addOption('chflag',
          hide: true,
          help: '[NIY] Rename flag "old" to "new" in all pragmas in code tree');

    try {
      _opt = parser.parse(argi);
    } catch (e) {
      print('Bad call${e.toString().replaceFirst('FormatException', '')}');
      print('''

  Unrecognized option, or -flag expression got misinterpreted as an option.
  Prepend expression part with two dashes, or just use @name before flags

  % retarget @name +flag -flag    # uses retarget.flag defaults for @name branch
  % retarget @ +flag -flag        # shortcut for @main branch

  ''');
      exit(9);
    }
    // set exit printer
    var exitcodes = Platform.environment['RT_ERRCODES'] == null ? false : true;
    if (_opt['silent']) {
      dp = (ec, _) => ec;
    } else {
      dp = ((ec, v) {
        print(v);
        if (exitcodes) {
          return ec;
        }
        return 0;
      });
    }
    if (_opt['help']) {
      print(synopsis);
      exit(dp(0, parser.usage));
    }
    if (_opt['init']) {
      print(sampleFlagsBig.trim());
      exit(0);
    }
    if (_opt['sample']) {
      print(samplePragmas.trim());
      exit(0);
    }
    String userguard = _opt['guard'] ?? _guard(uc: _opt['ucguard']);
    if (userguard.length < 5) userguard = _guard();
    if (userguard.length > 5) userguard = userguard.substring(0, 5);
    guard = userguard;
    forced = _opt['force'];
    stubcode = _opt['codetostub'];
    zebra = _opt['zebra'];
    stubkind = (_opt['stubif'])
        ? StubKind.iffi
        : (_opt['stubel'])
            ? StubKind.elfi
            : (_opt['stubco'])
                ? StubKind.bcon
                : (_opt['stubsw'])
                    ? StubKind.swth
                    : (_opt['stubca'])
                        ? StubKind.swca
                        : (_opt['stubtag'])
                            ? StubKind.tagt
                            : (_opt['stubli'])
                                ? StubKind.line
                                : zebra // if not given to former, do make a Line
                                    ? StubKind.line
                                    : null;

    var wdp = _opt['dir'] ??
        Platform.environment['RT_PKGDIR'] ??
        Directory.current.path;
    wd = Directory(wdp);
    var bna = 'unknown'; // branch name local
    var nrm = <String>[]; // normalized arguments
    var cmo = _opt.rest;
    if (cmo.isEmpty) {
      print(synopsis);
      exit(dp(0, parser.usage)); // at least @ is expected
    } else if (cmo.length > maxFlags * 2) {
      exit(dp(8, '\n  Err: too much arguments!\n\n'));
    } else {
      // massage input, User might mix and shuffle eg.: +flag "-flag *flag"
      for (var o in cmo) {
        for (var x in o.split(' ')) {
          nrm.add(x.trim());
        }
      }
      if (nrm[0].codeUnitAt(0) == 0x40) {
        bna = (nrm[0].length > 1) ? nrm[0].substring(1) : 'main';
        nrm = nrm.sublist(1);
      }
      {
        var iffi = nrm.indexOf('--');
        if (iffi >= 0 && iffi < nrm.length - 1) {
          files = nrm.sublist(iffi + 1);
          nrm = nrm.sublist(0, iffi);
        } else {
          files = <String>[''];
        }
      }
      if (stubkind != null && stubkind == StubKind.bcon) {
        stubco = nrm.sublist(0);
        nrm = [];
      }
      if (nrm.isNotEmpty && nrm.last == 'c') {
        chkrun = true;
        nrm.removeLast();
      } else {
        chkrun = _opt['dry-run'];
      }
      arg = nrm;
    }
    String? defcf;
    defcf = _opt['defcf'] ?? Platform.environment['RT_DEFCF'];
    if (defcf == null) {
      var cfgFile = findConfSync(wd); // get config from file
      if (cfgFile is! File) {
        cmferr(cfgFile, wd, bna, dp); // take error pages out of here
      } else {
        var li = <String>[]; // lines
        String? cferr;
        try {
          li = cfgFile
              .readAsStringSync()
              .split('\n')
              .map((e) => e.split(' #')[0].trim()) // remove # to EOL early
              .toList();
          cfgLines = CfgLines(bna, li, arg, stubkind != null);
          cferr = cfgLines.err.toString();
        } on FileSystemException catch (e) {
          exit(dp(11, '\nUnreadable file ${cfgFile.path}\n$e'));
        } catch (_) {
          rethrow;
        } // no element
        if (cferr.isNotEmpty) {
          if (stdout.hasTerminal) {
            exit(dp(22,
                '\nForbidden or wrong source tree configuration:$osNL$osNL$cferr$osNL'));
          } else {
            stdout.write(
                '// retarget.flags or cli arguments are wrong, re-run on terminal to know more:\n// retarget ');
            stdout.writeln(argi.join(' ').quoteItems());
            if (clibuf != null && clibuf!.isNotEmpty) {
              stdout.write(u8co.decoder.convert(clibuf!));
            }
            exit(22);
          }
        }
        wd = cfgFile.parent;
        bname = bna;
      }
      isCi = false; // configuration from file,
    } else {
      // XXX CI: take --defcf and make config off it - postponed till sponsored
      isCi = true;
      if (clibuf == null && !wd.existsSync()) {
        exit(dp(
            15, 'Package tree root directory MUST exist!\n[bad: ${wd.path}]'));
      }
      exit(dp(1, 'CI is not implemented yet'));
    } // config data ready
    _cfg = Config(
      dir: wd,
      cfl: cfgLines,
      clibuf: clibuf,
      dry: chkrun,
      force: forced,
      loud: _opt['verbose'],
      fixG: _opt['fixguard'],
      diags: _opt['diag'],
      silent: _opt['silent'],
    );
    pkgOk = true;
  } // Cmline constructor

  Config get cfg => _cfg; // if we ever would need a factory
  CfgLines get cfl => cfgLines;

  // no configurations - no fun, make it sync
  static FileSystemEntity? findConfSync(Directory start) {
    while (true) {
      if (!start.existsSync()) {
        return null; // no broken links, please
      }
      var x = start
          .listSync(followLinks: false) // no linked config mess
          .where((f) => f is File && f.path.endsWith('/pubspec.yaml'))
          .take(1)
          .toList(growable: false);
      if (x.isEmpty) {
        if (start.path == start.parent.path) {
          return null;
        }
        start = start.parent;
        continue;
      } else {
        var cffi = File('${start.path}/retarget.flags');
        if (cffi.existsSync()) {
          return cffi;
        }
        return start;
      }
    }
  }

  static Uint8List? pipedSync() {
    if (stdin.hasTerminal) {
      return null;
    }
    final bl = BytesBuilder(copy: true);
    int item;
    do {
      item = stdin.readByteSync();
      if (item < 0 || bl.length > 1 << 27) {
        break; // EOT || > 1GB, too much data
        // XXX test if Dart runtime properly closes pipe at bl.length exit
      }
      bl.addByte(item);
    } while (item != 4); // handle EOT on dumb terminals, too (/bin/expect)
    if (bl.isEmpty) {
      return null;
    }
    return bl.takeBytes();
  }

  static List<String> prnenv(List<String> argi) {
    print('Call: dir=${Directory.current}');
    argi.map((e) => 'arg: >$e<').forEach((e) => print(e));

    Platform.environment.entries
        .where((e) => e.key.startsWith('VSC') || e.key.startsWith('RT'))
        .forEach((v) {
      print('env: ${v.key}=${v.value}');
    });
    return <String>['rta', '--', '@testx'];
  }

  static String _guard({bool uc = false}) {
    var rg = DateTime.now().microsecondsSinceEpoch; // seed from time.now
    var ol = <int>[0, 0, 0, 0, 0];
    var mo = uc ? 52 : 26;
    for (var k = 4; k >= 0; k--) {
      var cn = rg % mo;
      if (cn < 26) {
        ol[k] = cn + 0x61;
      } else {
        ol[k] = cn - 26 + 0x41;
      }
      rg = rg ~/ mo;
    }
    return AsciiCodec().decode(ol);
  }

  static void cmferr(
      FileSystemEntity? cfgFile, Directory wd, String bname, DPf dp) {
    if (cfgFile == null) {
      exit(dp(9, '''
  Retarget must work inside a valid Dart package tree!
    Err: no pubspec.yaml was found in ${wd.path} and up!

    '''));
    } else if (cfgFile is File) {
      // no config for branch in file (valid package dir)
      // on read error we exited there
      exit(dp(11, '''

  Defaults for "$bname" branch not configured!
  You can edit ${cfgFile.path},
  Or add "$bname: default flags" confing right from the console:

  % echo "main: +your -new *def +flags" >> ${cfgFile.path}

    or use stub:
  % retarget --subconf @newname >> ${cfgFile.path}

     '''));
    } else if (cfgFile is Directory) {
      //
      exit(dp(13, '''
  Err: no retarget.flags config found in ${cfgFile.path}

  Retarget tool needs to know all flags to be used and their "main" defaults
  before it starts configuring sources. It keeps flags in a "retarget.flags"
  file placed along the "pubspec.yaml" in the package root directory.
  To start working with retarget enabled sources either:

  create retarget.flags config with defaults:

    echo 'main: +flag1 -flag2 *flag3  # example' > retarget.flags

  -------------------------------------------------------------------
  For use in CI or from make you may set environment with config line
      export RT_DEFCF="branchname: +flag1 -flag2 *flag3"
  Or provide whole CI config via --defcf option.
  If both are set the cmdline option overrides environment one.
  Note that for on tree operations (like --apply) the --dir=path must
  point to a valid package tree.
  -------------------------------------------------------------------

    '''));
    } else if (cfgFile is Link) {
      exit(dp(10, '''
  The retarget.flags configuration file MAY NOT be a symbolic link!
    Err: ${cfgFile.path} is not a plain text file!

    '''));
    }
  }
}

const synopsis = '''
Usage:
       retarget [options] @[bname] [+|-flag [...]] [[.]knob.variant] [...]]
                   (naked @ implicitly selects @main branch)
''';
