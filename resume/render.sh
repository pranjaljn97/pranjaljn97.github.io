#!/usr/bin/env bash
# Render resume.html -> ../Pranjal_Jain_Resume.pdf
#
# The phone number is not stored in resume.html (this repo is public). Supply it
# at render time; it ends up only in the generated PDF:
#
#   RESUME_PHONE='(+91) XXXXXXXXXX' ./render.sh
#
set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${RESUME_PHONE:-}" ]]; then
  echo "error: RESUME_PHONE is not set — refusing to render a PDF with a literal {{PHONE}} placeholder." >&2
  echo "usage: RESUME_PHONE='(+91) XXXXXXXXXX' $0" >&2
  exit 1
fi

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[[ -x "$CHROME" ]] || { echo "error: Chrome not found at $CHROME" >&2; exit 1; }

OUT="$(cd .. && pwd)/Pranjal_Jain_Resume.pdf"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Substitute the phone into a throwaway copy so the tracked file stays clean.
python3 - "$TMP/resume.html" <<'PY'
import os, sys
src = open('resume.html', encoding='utf-8').read()
phone = os.environ['RESUME_PHONE']
if '{{PHONE}}' not in src:
    sys.exit('error: {{PHONE}} placeholder missing from resume.html')
open(sys.argv[1], 'w', encoding='utf-8').write(src.replace('{{PHONE}}', phone))
PY

# Chrome defers to the document's `@page { size: A4; margin: 0 }` — no margin flags.
# It reliably writes the PDF but often hangs on exit in headless, so cap it.
"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --user-data-dir="$TMP/profile" \
  --print-to-pdf="$OUT" "file://$TMP/resume.html" >/dev/null 2>&1 &
pid=$!
( sleep 30; kill -9 "$pid" 2>/dev/null ) & watchdog=$!
wait "$pid" 2>/dev/null || true
kill "$watchdog" 2>/dev/null || true

[[ -s "$OUT" ]] || { echo "error: no PDF produced at $OUT" >&2; exit 1; }

pages=$(mdls -name kMDItemNumberOfPages -raw "$OUT" 2>/dev/null || echo "?")
echo "wrote $OUT (${pages} page(s))"
[[ "$pages" == "1" ]] || echo "warning: expected a 1-page resume, got ${pages}" >&2
