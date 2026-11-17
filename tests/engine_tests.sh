#!/usr/bin/env bash
# ============================================================
# engine_tests.sh -- regression tests for 97_entries.sty.
# Run from anywhere:  bash tests/engine_tests.sh   (or: make test)
# Needs pdflatex, pdftotext (poppler) and timeout (coreutils).
# Each case compiles a tiny document in a temp dir and checks one of:
#   err:<text>   the build stops with a cv-entries error containing <text>
#   out:<text>   the build succeeds and the PDF text contains <text>
#   ok           the build succeeds with no error
# A case that runs longer than 20 s counts as a failure.
# ============================================================
set -u
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export TEXINPUTS="$ROOT_DIR//:"
pass=0; fail=0

check() {  # check <name> <expect> <body>
  local name="$1" expect="$2" body="$3" log msg rc
  printf '%s\n' '\documentclass{article}\usepackage{99_preamble}\usepackage{97_entries}' \
    '\begin{document}' "$body" '\end{document}' > "$TMP/t.tex"
  ( cd "$TMP" && timeout 20 pdflatex -interaction=nonstopmode t.tex >/dev/null 2>&1 ); rc=$?
  log="$(tr '\n' ' ' < "$TMP/t.log" 2>/dev/null | sed 's/(cv-entries) *//g; s/  */ /g')"
  msg="$(grep -o 'Package cv-entries Error:.*' <<<"$log" | cut -c1-160)"
  local ok=0
  if [ "$rc" = 124 ]; then msg="HANG"
  else case "$expect" in
    err:*) grep -qF -- "${expect#err:}" <<<"$msg" && ok=1 ;;
    out:*) [ -z "$msg" ] && pdftotext "$TMP/t.pdf" - 2>/dev/null | tr '\n' ' ' | tr -s ' ' | grep -qF -- "${expect#out:}" && ok=1 ;;
    ok)    [ -z "$msg" ] && ! grep -q '^!' "$TMP/t.log" && ok=1 ;;
  esac; fi
  if [ $ok = 1 ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL %-20s expected %s\n     got: %s\n' "$name" "$expect" "${msg:-no error}"; fi
  rm -f "$TMP"/t.*
}
P='\DefinePosition'

# --- keys ---------------------------------------------------------------
check typo-key       'err:unknown key '"'"'bulets'"'"   "$P{A}{title=T, date=2023, bulets=none}"
check unbraced-comma 'err:has no value'                 "$P{A}{title=T, org=Dept, Uni, date=2023, bullets=none}"
check dup-key        'err:given twice'                  "$P{A}{title=T, title=U, date=2023, bullets=none}"
check fixed-override 'err:unknown key '"'"'tut date'    "$P{A}{title=T, tut date=2023, date=2023, bullets=none}"
check full-prefix    'err:unknown key '"'"'full title'  "$P{A}{title=T, full title=U, date=2023, bullets=none}"
check pub-tut-key    'err:unknown key '"'"'tut title'   '\DefinePublication{Pb}{title=T, tut title=U, authors=A, venue=V, date=2026}'
check missing-title  'err:required key '"'"'title'      "$P{A}{date=2023, bullets=none}"
check pres-no-type   'err:required key '"'"'type'       '\DefinePresentation{Tk}{title=T, venue=V, date=2023}'
# --- names ----------------------------------------------------------------
check name-taken     'err:already exists'               '\DefineParagraph{section}{x}'
check redefine       'err:already exists'               '\DefineParagraph{Q}{x}\DefineParagraph{Q}{y}'
check name-digit     'err:letters only'                 '\DefineParagraph{Pub2}{x}'
check name-space     'err:letters only'                 "$P{My Name}{title=T, date=2023, bullets=none}"
# --- dates ----------------------------------------------------------------
check no-date        'err:a date is required'           "$P{A}{title=T, bullets=none}"
check start-only     'err:needs an '"'"'end'            "$P{A}{title=T, start=2023-01, bullets=none}"
check end-only       'err:needs a '"'"'start'           "$P{A}{title=T, end=2023, bullets=none}"
check date-and-range 'err:not both'                     "$P{A}{title=T, date=2023, start=2023, end=2024, bullets=none}"
check bad-month      'err:'"'"'start = 2023-13'         "$P{A}{title=T, start=2023-13, end=2024-01, bullets=none}"
check bad-date-shape 'err:'"'"'date = 2023-1-5'         "$P{A}{title=T, date=2023-1-5, bullets=none}"
check date-slash     'err:'"'"'date = 2023/12'          "$P{A}{title=T, date=2023/12, bullets=none}"
check date-empty     'err:is empty'                     "$P{A}{title=T, date={}, bullets=none}"
check date-present   'err:is not a date'                "$P{A}{title=T, date=present, bullets=none}"
check reversed-month 'err:is before start date'         "$P{A}{title=T, start=2024-03, end=2024-01, bullets=none}"
check reversed-year  'err:is before start date'         "$P{A}{title=T, start=2025, end=2024, bullets=none}"
check mixed-prec     'err:must both be YYYY'            "$P{A}{title=T, start=2023, end=2023-12, bullets=none}"
check render-bad     'err:'"'"'date = 2023-13'          "$P{A}{title=T, date=2023-13, bullets=none}\\A"
check render-nodate  'err:a date is required'           '\DefinePublication{Pb}{title=T, authors=A, venue=V}\Pb'
check fmt-same-year  'out:Jan – Dec 2023'               "$P{A}{title=T, start=2023-01, end=2023-12, bullets=none}\\A"
check fmt-same-month 'out:Jun 2023'                     "$P{A}{title=T, start=2023-06, end=2023-06, bullets=none}\\A"
check fmt-present    'out:Sep 2025 – Present'           "$P{A}{title=T, start=2025-09, end=PRESENT, bullets=none}\\A"
check fmt-years      'out:2021 – 2026'                  "$P{A}{title=T, start=2021, end=2026, bullets=none}\\A"
check fmt-cross-year 'out:Apr 2021 – May 2026'          "$P{A}{title=T, start=2021-04, end=2026-05, bullets=none}\\A"
check fmt-point      'out:Dec 2023'                     "$P{A}{title=T, date=2023-12, bullets=none}\\A"
check fmt-literal    'out:Spring 2020'                  "$P{A}{title=T, date={Spring 2020}, bullets=none}\\A"
# --- forms and bullets ----------------------------------------------------
check miss-bullets   'err:no bullets for the '"'"'short' "$P{A}{title=T, date=2023, bullets=none}\\A[short]"
check bullets-empty  'err:is empty; write'              "$P{A}{title=T, date=2023, bullets={}}\\A"
check bullets-noitem 'err:must be a list'               "$P{A}{title=T, date=2023, bullets={Did a thing}}\\A"
check none-any-case  'ok'                               "$P{A}{title=T, date=2023, bullets=NONE}\\A"
check form-fallback  'out:Tut title | Base org'         "$P{A}{title=T, org={Base org}, tut title={Tut title}, date=2023, tut bullets=none}\\A[tut]"
check bad-form       'err:has no '"'"'long'"'"' form'   "$P{A}{title=T, date=2023, bullets=none}\\A[long]"
check pub-no-tut     'err:has no '"'"'tut'"'"' form'    '\DefinePublication{Pb}{title=T, authors=A, venue=V, date=2026}\Pb[tut]'
check formless-arg   'err:has no forms'                 '\DefineParagraph{Q}{x}\Q[short]'
check setform-bad    'err:unknown form'                 '\SetEntryForm{long}'
check setform-space  'ok'                               '\SetEntryForm{ short }'
check acad-form      'out:Acad bullet'                  "$P{A}{title=T, date=2023, bullets={\\item Full bullet}, acad bullets={\\item Acad bullet}}\\A[acad]"
check acad-missing   'err:no bullets for the '"'"'acad' "$P{A}{title=T, date=2023, bullets=none}\\A[acad]"
check pub-no-acad    'err:has no '"'"'acad'"'"' form'   '\DefinePublication{Pb}{title=T, authors=A, venue=V, date=2026}\Pb[acad]'
C='\DefineCourse'
check course-nested   'out:Courses taught PHYS 2A, General Physics (laboratory)' "$C{Ca}{title={PHYS 2A, General Physics}, type=laboratory, date={Fall 2023}, bullets={\\item Lab bullet}}$P{A}{title=T, date=2023, bullets={\\item B}, courses={Ca}}\\A"
check course-unknown  'err:which is not a'               "$P{A}{title=T, date=2023, bullets=none, courses={Nope}}\\A"
check course-notkind  'err:which is not a'               "$P{Bx}{title=U, date=2023, bullets=none}$P{A}{title=T, date=2023, bullets=none, courses={Bx}}\\A"
check course-noinherit 'ok'                              "$C{Ca}{title=X, date=2023, bullets={\\item Lab bullet}}$P{A}{title=T, date=2023, bullets=none, short bullets=none, courses={Ca}}\\A[short]"
check course-nobullets 'err:no bullets for the '"'"'short' "$C{Ca}{title=X, date=2023, bullets=none}$P{A}{title=T, date=2023, bullets=none, short bullets=none, short courses={Ca}}\\A[short]"
check course-alone    'out:PHYS 2A (laboratory)'         "$C{Ca}{title={PHYS 2A}, type=laboratory, date=2023, bullets=none}\\Ca"
check doc-default    'out:Tut title'                    "$P{A}{title=T, tut title={Tut title}, date=2023, tut bullets=none}\\SetEntryForm{tut}\\A"
# --- references, skills, works --------------------------------------------
check unconfirmed    'err:confirmed = false'            '\DefineReference{RefQ}{name=N, affiliation=A, relationship=R, confirmed=false}\RefQ'
check bad-confirmed  'err:must be true or false'        '\DefineReference{RefQ}{name=N, affiliation=A, relationship=R, confirmed=yes}'
check ref-ok         'out:N, A — R'                     '\DefineReference{RefQ}{name=N, affiliation=A, relationship=R, confirmed = true }\RefQ'
check skill-dup      'err:is given twice'               '\DefineSkills{Sk}{A = x, A = y}'
check skill-lines    'out:Programming: Python Tutoring & Instruction: one' '\DefineSkills{Sk}{Programming = Python, Tutoring \& Instruction = one}\Sk'
check work-layout    'out:T (poster) A. B V. Note.' '\DefinePresentation{Tk}{title=T, type=poster, authors={A.~B}, venue=V, note=Note., date=2026}\Tk'
check no-double-dot  'out:X et al. Lead.'               '\DefinePublication{Pb}{title=T, authors=A, venue={X et al.}, note=Lead., date=2026}\Pb'

echo "engine_tests: $pass passed, $fail failed"
[ "$fail" = 0 ]
