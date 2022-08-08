
## cheat sheet for IDE plugin authors

### retarget pragma anatomy

Retarget pragma shape was carefully designed to be easily recognizable by
humans and to be lean for machine, with a clear vision of adding retarget
functionality to existing Dart tools. If added as a step in source parsing,
retarget pragmas shape keeps at O(1) code complexity to recognize,
and any edits are just a few bytes to be written in-place (RAM or file).

Pragma headers contain braces to help user navigate within an IDE.  Pairing
guards helps the tool to check pragmas consistency (eg. to alert user about
overlapping spans or orphaned pragmas as may happen after a cut/paste edits).

Condition negation ! on #else is a visual hint for human, not an operator.
End of block uses #efi @ marker, then ___, ```, and ^^^ obligatory padding
is an additional visual (and grep) clue.

```
        ________ pragma lead comment can be '// //', or '*/ //', or '/* //'
       / _______ IDE navigation helper
      / /                 ___________ "on this condition being false" hint
  ___/ /                 /
 // //}{ draug```: #else ! +flag -flag *flag   flags, following text is ok
         ^^^^^     ^^^^^
            \         \_________________ pragma kind (also: #ifconf, #efi)
             \__________________________ pairing guard, randomly generated
```

Pairing guards on each set of pragmas must be unique within a file scope
(and `retarget` tool linter checks it). If all guarded scopes are generated
using `--stub**` family, guards should be unique (modulo 11'881'375/2).

Retarget pragma lead is a fixed size field, to be fast recognized
just by checking positions 3, 16, 18 to have slash, colon, and sharp -
given slash or asterix on position 0. Whole pragma then ends at the
first blank that is not followed by . + - or *, or at the NL.
At least a single flag must be recognized to make a pragma.

```
0  3           16 18      _first marker is at 26
/* // { guard___: #ifconf +aplos    first 18 + 8
*/ //}{ guard```: #else ! +aplos    first 18 + 8
// // } guard^^^: #efi @! +aplos    first 18 + 8

/* // { guard___: #ifconf +aplos    first 18 + 8
*/ // } guard^^^: #efi @@ +aplos    first 18 + 8
```
