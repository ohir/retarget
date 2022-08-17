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

import 'dart:typed_data';

import 'retarget.dart';
import 'rtconf.dart';
import 'walker.dart';

// chgSs='//';  coUp='*/';  coDn='/*';
const coLi = ((((2 << 7) | 47) << 16) | ((1 << 7) | 47)) << 30; // // Li
const coUp = ((((2 << 7) | 47) << 16) | ((1 << 7) | 42)) << 30; // */ Up
const coDn = ((((2 << 7) | 42) << 16) | ((1 << 7) | 47)) << 30; // /* Dn

extension _PragmaManip on Pragma {
  void _applyChg(Uint8List bu) {
    int was = chg;
    switch (chg) {
      case coLi: // //
        if (!(bu[at] == 47 && bu[at + 1] == 47)) chg |= at - 1;
        break;
      case coUp: // */
        if (!(bu[at] == 42 && bu[at + 1] == 47)) chg |= at - 1;
        break;
      case coDn: // /*
        if (!(bu[at] == 47 && bu[at + 1] == 42)) chg |= at - 1;
        break;
    }
    if (chg == was) chg = 0;
  }
}

PgErr psoSw(PragSet ps, Uint8List bu, Config cfg) {
  PgErr? err;
  final pa = ps.parts;
  final eswIdx = ps.parts.length - 1;
  void putCo(int tobe, int paIdx) => pa[paIdx].chg = tobe;
  late Uint64List vknobs;
  int i = 0;
  int ksta = pa[0].ss; // ksta can be reused
  int kend = pa[0].to; // kend can be reused after
  int dots = pa[0].chg; // knob dot is on both sides, see _chkCondition lint
  int defD = 0; // default dots
  for (; i <= eswIdx; i++) {
    if (!bu.rangesEqual(from: pa[i].ss, to: pa[i].to, from2: ksta, to2: kend)) {
      pa[i].err ??= err = PgErr.eBadFromVariantsInfo;
    }
    pa[i].chg = coLi; // clear all
  }
  final vnaO = dots & 127; // take offset
  dots >>= 7;
  while (dots != 0) {
    defD <<= 7;
    defD |= dots & 127;
    dots >>= 7;
  }
  dots = defD;
  var a = pa[0];
  final bool hasdef = a.type == PgType.isSwdf;
  final int var1st = hasdef ? 1 : 0;
  final int pgcases = hasdef ? eswIdx - 1 : eswIdx;
  final kname = bu.slice(a.fl + 1, a.fl + vnaO - 1);
  final bKnob = binItem(kname, 0);
  ksta = cfg.ccIndexOf(kname); // now knob name index
  kend = 0;
  int kcnt = 0;
  CfgItem cfi = 0;
  var cc = cfg.cconf;
  int ccend = cc.length;

  derp:
  do {
    if (err != null) break derp; // earlier lints erred
    if (ksta < 0) {
      a.err ??= err = PgErr.eUnknownVarName;
      break derp;
    }
    kcnt = 0;
    ksta++; // to the first variant in cconf
    kend = ksta;
    while (kend < ccend && cc[kend].isKnobVar()) {
      kcnt++;
      kend++;
    }
    if (hasdef) {
      if (pgcases > kcnt) {
        a.err ??= err = PgErr.eTooManyCaseofs;
        break derp;
      } else if (pgcases == kcnt) {
        a.err ??= err = PgErr.eDefaultOnExhaustiveSw;
        break derp;
      }
    } else {
      if (pgcases < kcnt) {
        a.err ??= err = PgErr.eNotAllCasesGiven;
        break derp;
      } else if (pgcases > kcnt) {
        a.err ??= err = PgErr.eTooManyCaseofs;
        break derp;
      }
    }
    if (hasdef && kcnt == pgcases) {}
    vknobs = cfg.cconf.sublist(ksta, kend);
    ccend = vknobs.length; // we have our sublist
    kend = ps.parts.length - 2; // now is last variant pragma (next is #esw)
    ksta = 0; // now is active knobs count
    for (i = var1st; i <= kend; i++) {
      a = pa[i];
      if (binItem(bu.slice(a.fl + 1, a.fl + vnaO - 1), 0) != bKnob) {
        a.err ??= err = PgErr.eMisspelledKnobName;
        break derp;
      }
      if (((a.ss - 6) - (a.fl + vnaO)) > 7) {
        a.err ??= err = PgErr.eUnknownVarName;
        break derp;
      }
      CfgItem ite = binItem(bu.slice(a.fl + vnaO, a.ss - 6), 0).indexIn(vknobs);
      if (ite < 0) {
        a.err ??= err = PgErr.eUnknownVarName;
        break derp;
      }
      cfi = vknobs[ite];
      if (i <= kend) {
        a.guard = ((dots >> (7 * ite)) & 127); // keep dot-pos
        defD &= ~(127 << (7 * ite)); // erase self
      }
      if (cfi.isKnobVarSet()) {
        ksta++;
        if (i == 0) {
          putCo(coLi, 0); //        // Co
          putCo(coDn, 1); //        /* Dn
          putCo(coUp, kend + 1); // */ Up
        } else if (i == kend) {
          putCo(coDn, 0); //        /*
          putCo(coUp, i); //        */
          putCo(coLi, kend + 1); // //
        } else {
          putCo(coDn, 0); //        /*
          putCo(coUp, i); //        */
          putCo(coDn, i + 1); //    */
          putCo(coUp, kend + 1); // */
        }
      }
    }
    if (i > kend && ksta == 0) {
      if (!hasdef) {
        a.err ??= err = PgErr.eNoCodeToActivate;
        break derp;
      } // activate default
      putCo(coLi, 0); //        //
      putCo(coDn, 1); //        /*
      putCo(coUp, kend + 1); // */
    }
  } while (false);
  int grd = pa[pa.length - 1].guard;
  if (err != null) {
    for (i = 0; i <= eswIdx; i++) {
      pa[i].guard = grd;
      pa[i].chg = 0;
    }
    return err;
  }
  int chi = 0;
  void fixit(int pos, int c) {
    // absolute pos, pos: 0 closes fixlist.
    // ss is already at -1 (dot) to offset
    a.fix ??= <int>[];
    if (pos == 0) {
      if (chi != 0) a.fix!.add(chi << 30 | a.ss);
      if (a.fix!.isEmpty) a.fix = null;
      chi = 0;
      return;
    }
    if (chi == 0) {
      chi = ((pos - a.ss) << 7) | (c & 127);
      return;
    }
    chi |= (((pos - a.ss) << 7) | (c & 127)) << 16;
    a.fix!.add(chi << 30 | a.ss);
    chi = 0;
  }

  for (i = var1st; i < eswIdx; i++) {
    a = pa[i];
    bool uc = false;
    for (int n = a.ss + 1; n < a.to; n++) {
      int c = bu[n];
      if (n == a.ss + a.guard) uc = true;
      if (c == 46) uc = false;
      if (uc && c > 96 && c < 123) c &= ~(0x20);
      if (!uc && c < 91 && c > 64) c |= 0x20;
      if (bu[n] != c) fixit(n, c);
    }
    fixit(0, 0); // close list
  }
  if (hasdef) {
    a = pa[0];
    int df = dots;
    int ao = 0;
    while (df > 0) {
      ao <<= 7;
      ao |= df & 127;
      df >>= 7;
    }
    dcase:
    while (ao != 0) {
      df = defD;
      bool uc = false;
      int cu = ao & 127;
      ao >>= 7;
      while (df > 0) {
        if (cu == df & 127) {
          uc = true;
          break;
        }
        df >>= 7;
      }
      for (int n = a.ss + cu; n < a.to; n++) {
        int c = bu[n];
        if (c == 46) continue dcase;
        if (uc && c > 96 && c < 123) c &= ~(0x20);
        if (!uc && c < 91 && c > 64) c |= 0x20;
        if (bu[n] != c) fixit(n, c);
      }
    }
    fixit(0, 0); // close list
  }
  {
    a = pa[pa.length - 1]; // fix #esw, to be prudent
    for (int n = a.ss + 1; n < a.to; n++) {
      int c = bu[n];
      if (c < 91 && c > 64) c |= 0x20;
      if (bu[n] != c) fixit(n, c);
    }
    fixit(0, 0); // close list
  }
  for (i = 0; i <= eswIdx; i++) {
    pa[i]._applyChg(bu); // apply changes
    pa[i].guard = grd; // restore guards
  }
  //return PgErr.eUnknown;
  return PgErr.eNone;
}

PgErr psoTag(PragSet ps, Uint8List bu, Config cfg) {
  var a = ps.parts[0];
  int dst = a.at;
  int i = 0;
  for (; i < 256; i++) {
    if (cfg.bTargt[i] != bu[dst + i]) {
      a.chg = blockWrite1 << 30 | a.at - 1;
      break; // even single change is enough
    }
  }
  if (a.chg == 0) return PgErr.eNone;
  dst = bu.lengthInBytes; // CR corrections, if cr found past pragma
  dst = a.to + 16 < bu.lengthInBytes ? a.to + 16 : bu.lengthInBytes;
  for (i = a.to; i < dst; i++) {
    if (bu[i] == osCR) {
      a.chg |= cfg.bTgtCR;
      break;
    }
  }
  return PgErr.eNone;
}

PgErr psoLi(PragSet ps, Uint8List bu, Config cfg) {
  // // @ +Flag***: # */
  //    +8^     ^14
  var a = ps.parts[0];
  int cs = a.at + 9; // cond start
  int cc = bu[cs - 1]; // cond char
  int ce = cs;
  while (bu[ce] != 42) {
    ce++;
  }
  bool? vset = cfg.isNameSet(bu.sublist(cs, ce));
  if (vset == null) {
    a.err = PgErr.eUnknownVarName; // not known
    return PgErr.eUnknownVarName; // not known
  } else if (vset) {
    if (cc == 43 && bu[a.at + 1] == 47) {
      a.chg = ((((((5 << 7) | 47) << 16) | (2 << 7) | 42) << 30) | a.at - 1);
    } // + + / => make active   => * /
    if (cc == 45 && bu[a.at + 1] == 42) {
      a.chg = ((((((5 << 7) | 42) << 16) | (2 << 7) | 47) << 30) | a.at - 1);
    } // + - * => make inactive => / *
  } else {
    if (cc == 45 && bu[a.at + 1] == 47) {
      a.chg = ((((((5 << 7) | 47) << 16) | (2 << 7) | 42) << 30) | a.at - 1);
    } // - - / => make active   => * /
    if (cc == 43 && bu[a.at + 1] == 42) {
      a.chg = ((((((5 << 7) | 42) << 16) | (2 << 7) | 47) << 30) | a.at - 1);
    } // - + * => make inactive => / *
  }
  return PgErr.eNone;
}

PgErr psoIf(PragSet ps, Uint8List bu, Config cfg) {
  bool hasE = ps.parts[1].type == PgType.isElse;
  var a = ps.parts[0];
  if (hasE &&
      ps.parts.length != 3 &&
      ps.parts[1].type != PgType.isElse &&
      ps.parts[2].type != PgType.isEfi) {
    a.err = PgErr.eBadFinal;
    return PgErr.eBadFinal;
  }
  if (!hasE && ps.parts.length != 2 && ps.parts[1].type != PgType.isFi) {
    a.err = PgErr.eBadFinal;
    return PgErr.eBadFinal;
  }
  var dochg = false; // do changes
  int hb = hasE ? 2 : 0; // true heads
  var f = cfg.bFlags;
  if (a.to - a.fl != f.lengthInBytes) {
    a.err = PgErr.eBadFlags;
    return PgErr.eBadFlags;
  }
  int i = a.fl;
  int n = 0;
  while (i < a.to) {
    switch (bu[i]) {
      case 0x2a: // *
        break;
      case 0x2b: // +
        if (f[n] == 0x2b) break;
        if (f[n] != 0x2d) continue bad;
        hb = 4;
        break;
      case 0x2d: // -
        if (f[n] == 0x2d) break;
        if (f[n] != 0x2b) continue bad;
        hb = 4;
        break;
      bad:
      default:
        if (bu[i] != f[n]) {
          a.err = PgErr.eBadFlags;
          return PgErr.eBadFlags;
        }
    }
    i++;
    n++;
  } // cond estabilished
  var le = cfg.pglead;
  do {
    n = 0;
    for (var v in ps.parts) {
      if (bu[v.at] != le[hb + n] || bu[v.at + 1] != le[hb + n + 1]) {
        dochg = true;
        break;
      }
      n += 2;
    }
    if (!dochg) {
      break;
    } else {
      int end = ps.parts.length;
      n = 0;
      for (int i = 0; i < end; i++) {
        int o = // chr:b0..b6 ofs:b7..15
            (((2 << 7 | le[hb + n + 1]) << 16) | ((1 << 7 | le[hb + n]))) << 30;
        o |= (ps.parts[i].at - 1);
        ps.parts[i].chg = o;
        n += 2;
      }
    } // pragma.chg
  } while (false);
  var src = ps.parts[0];
  var end = src.to - src.fl;
  if (end > 510) {
    a.err = PgErr.eTooMuchToFix;
    return PgErr.eTooMuchToFix;
  }
  for (int k = 1; k < ps.parts.length; k++) {
    var dst = ps.parts[k];
    int c1 = 0;
    int p1 = 0;
    for (i = 0; i < end; i++) {
      if (bu[src.fl + i] == bu[dst.fl + i]) continue;
      var c = bu[src.fl + i];
      if (c > 126) {
        a.err = PgErr.eBadCh;
        return PgErr.eBadCh;
      } // chitem fuse, 7bits in service. Utf fixes go via blockWrite
      if (c1 == 0) {
        c1 = c;
        p1 = i + 1;
        continue;
      }
      dst.fix ??= <ChgItem>[];
      dst.fix!.add(((((((i + 1) << 7) | c) << 16) | (p1 << 7 | c1)) << 30) |
          (dst.fl - 1));
      c1 = p1 = 0;
    }
    if (p1 != 0) {
      dst.fix ??= <ChgItem>[];
      dst.fix!.add((((p1 << 7) | c1) << 30) | (dst.fl - 1));
    }
  } // fix-list
  return PgErr.eNone;
}

PgErr psoBc(PragSet ps, Uint8List bu, Config cfg) {
  print('  NIY! psoBc called! G:${ps.guard}');
  return PgErr.eNone;
}

PgErr pso(PragSet ps, Uint8List bu, Config cfg) {
  print('  NIY! pso unknown called! G:${ps.guard}');
  return PgErr.eNone;
}
