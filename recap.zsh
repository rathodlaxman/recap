# ============================================================
#  Recap - offline article summariser  (Ollama + Gemma 4)
#  Add this block to ~/.zshrc, then run:  source ~/.zshrc
#  Commands:  recap | recap short | recap changes | recaplong
#             recapall | recapc | recapmail | recapurl | recapurls | recapsetup | recapdoctor | recap help
# ============================================================

RECAP_DIR="${RECAP_DIR:-$HOME/Summaries}"
RECAP_HOME="${RECAP_HOME:-$HOME/.recap}"
RECAP_VERSION="1.0.0"
RECAP_MODEL_DEFAULT="gemma4-sum"

# --- which Python runs the address commands ---------------------------
_recap_py() {   # RECAP_PYTHON if set, else the private environment made by recapsetup, else python3 from the PATH
  if [[ -n "$RECAP_PYTHON" ]]; then print -r -- "$RECAP_PYTHON"
  elif [[ -x "$RECAP_HOME/venv/bin/python" ]]; then print -r -- "$RECAP_HOME/venv/bin/python"
  else print -r -- python3
  fi
}

# --- shared prompt -------------------------------------------------
_recap_prompt() {
  print -r -- "Summarise the text below. Start with the gist: one sentence that states the main finding or message in plain words and does not list items. Never start with 'Here is a summary'. Then give the main points as short bullets, only as many as needed, never padded, with the central figures inside them. Write the bullets in Markdown, each beginning with '- '. Do not use any headings other than 'Worth noting'. Under 'Worth noting' write only extra facts that are not already in the bullets, each as a full sentence that states a fact; never list bare names, dates or numbers. If there is nothing extra, leave out the heading. Write numbers, percentages and years in digits, never spelled out as words. Match the type of text: for news, who did what, when and why; for market or business reports, the main moves with figures and reasons; for editorials and opinion pieces, what the author argues and why; for circulars, regulations and rulings, lead with what is new, say from when it applies and who must act; for tutorials and explainers, the main tips or ideas; for research, what was studied and found; for a collection of separate stories or ideas, say so in the gist and give one bullet per item, naming who said or did it. Rules: Use only the main article; ignore sidebars, related links, promotions, addresses, signatures, bios and disclaimers. Add no outside facts, adjectives or conclusions. In an editorial, present claims as the author's, and write 'The author wants the Court to set aside the orders' rather than 'The Court set aside the orders'; use 'The editorial argues' only for a newspaper's own editorial. Say exactly who said each thing: never give a speaker's remark to the author, and never give the author's lesson to a speaker. Planned things are planned, not done. Do not link events as cause and effect unless the text does. Keep hedges and the strength of wording. Keep names, figures, dates, roles, teams and comparisons exactly as written, attach each figure only to what the text attaches it to, and do not guess. End after the last point, with no questions or offers."
}

# --- helpers -------------------------------------------------------
_recap_title() {   # first non-blank line, trimmed to 90 chars
  grep -m1 -v '^[[:space:]]*$' "$1" | tr -d '\r' | cut -c1-90
}

_recap_slug() {
  print -r -- "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-50
}

_recap_clean() {   # tidy the model output into clean Markdown
  awk '
    NR==1 && /^Here[^ ]* / { skipblank=1; next }
    skipblank && /^[[:space:]]*$/ { skipblank=0; next }
    { skipblank=0 }
    /^(Related|See also|Further reading):?[[:space:]]*$/ { exit }
    {
      sub(/^[[:space:]]*\*[[:space:]]+/, "- ")
      sub(/^[[:space:]]*•[[:space:]]+/, "- ")
      if ($0 ~ /^[[:space:]]*\*?\*?(Worth noting|Worth Noting)\*?\*?:?[[:space:]]*$/) {
        print ""; print "**Worth noting**"; print ""; inwn=1; next
      }
      if (inwn && $0 !~ /^[[:space:]]*$/ && $0 !~ /^- /) $0 = "- " $0
      print
    }'
}

# --- drop "Worth noting" bullets that repeat the main points -------
_recap_dedupe() {   # RECAP_OVERLAP = share of repeated words that counts as a repeat (default 0.6)
  awk -v thr="${RECAP_OVERLAP:-0.6}" '
    function norm(s,   t) { t = tolower(s); gsub(/[^a-z0-9 ]/, " ", t); return t }
    function keep(w) { return (length(w) >= 4 || w ~ /[0-9]/) }
    function addwords(s,   n, i, a) {
      n = split(norm(s), a, " ")
      for (i = 1; i <= n; i++) if (keep(a[i])) seen[a[i]] = 1
    }
    function overlap(s,   n, i, a, tot, hit) {
      n = split(norm(s), a, " "); tot = 0; hit = 0
      for (i = 1; i <= n; i++) if (keep(a[i])) { tot++; if (a[i] in seen) hit++ }
      return (tot == 0) ? 0 : hit / tot
    }
    /^[[:space:]]*\*\*Worth noting\*\*[[:space:]]*$/ { inwn = 1; shown = 0; pend = 0; next }
    inwn {
      if ($0 ~ /^[[:space:]]*$/) next
      if (overlap($0) >= thr) next
      if (!shown) { print ""; print "**Worth noting**"; print ""; shown = 1 }
      addwords($0); print; next
    }
    /^[[:space:]]*$/ { pend = 1; next }
    { if (pend) print ""; pend = 0; addwords($0); print }
    END { print "" }'
}

# --- input and source helpers (used by recapurl) -------------------
_recap_input() {   # RECAP_INPUT = read this file instead of the clipboard
  if [[ -n "$RECAP_INPUT" ]]; then cat "$RECAP_INPUT"; else pbpaste; fi
}

_recap_src_line() {   # RECAP_SOURCE = address to show under the heading
  if [[ -n "$RECAP_SOURCE" ]]; then
    print -r -- "Source: $RECAP_SOURCE"
    print ""
  fi
}

_recap_msg() {   # screen messages: each argument on its own line, then a blank line (stderr only)
  if [[ "$1" == "-b" ]]; then [[ -z "$RECAP_NO_LEAD" ]] && print -u2 ""; shift; fi   # -b: also a blank line before
  [[ -z "$_RECAP_FIRST_MSG" ]] && _RECAP_FIRST_MSG="$1"   # first message of an address run = its failure reason
  print -u2 -rl -- "$@"
  print -u2 ""
}

_recap_preview() {   # $1 = file: its first 3 non-blank lines, each cut at a word boundary
  grep -v '^[[:space:]]*$' "$1" | head -3 | awk '{
    line = $0
    if (length(line) > 100) { line = substr(line, 1, 100); sub(/[[:space:]]+[^[:space:]]*$/, "", line); line = line " ..." }
    print "  " line }'
}

_recap_flags() {   # --think=false only for models that accept it
  case "$1" in
    gemma4*|qwen*) print -r -- "--think=false" ;;
    *) ;;
  esac
}

# --- one article ---------------------------------------------------
recap() {
  local mode="$1" extra="" tmp title words model base
  model="${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}"
  local -a tf
  tf=(${=$(_recap_flags "$model")})
  base="$(_recap_prompt)"

  case "$mode" in
    short) base="Summarise the text below in one sentence, then give up to 3 short bullet takeaways in Markdown, each beginning with '- '. Start with the summary itself, never an introduction. Use 'The editorial argues' only for a newspaper's own editorial, and then present the claims as the author's. Say exactly who said each thing. Keep hedges and the strength of wording. Write numbers in digits. Attach each figure only to what the text attaches it to. Use only the main article; ignore related links, sidebars, addresses, signatures and disclaimers. Do not ask me any questions." ;;
    changes) extra="Special focus for this summary: the text changes an earlier rule or circular. State clearly which clauses or points are new or changed, using their clause numbers, and which are existing or unchanged. Then say who must act and from when. Mention the number and date of the earlier circular only as the one being modified." ;;
    version|-V|--version) print -r -- "Recap $RECAP_VERSION"; return ;;
    help|-h|--help)
      cat <<'EOT'
  recap               adaptive summary of whatever is on the clipboard
  recap short         one sentence plus up to 3 takeaways
  recap changes       for circulars and rules: new vs unchanged clauses
  recap "focus text"  your own focus, e.g. recap "focus on costs"
  recaplong           long articles and transcripts: reads it in parts (slow but accurate)
  recapall            several articles separated by lines containing only @@@@
  recapc              same as recap, and also copies the summary to the clipboard
  recapmail           short email summary: sender, tasks, deadlines, reply needed
  recapurl "ADDRESS"  fetch a web article or YouTube captions, or read a PDF (address or file), and summarise (quote it)
  recapurl "A" "B"    several addresses, one after another (--single: one file, --separate: one each)
  recapurls           summarise every web address on the clipboard (one per line; same flags)
  recapsetup          create or update the private Python environment the address commands use
  recapdoctor         check the whole setup and say what to fix
  recap version       show which version of Recap this is
  RECAP_MODEL=gemma-sum recap    use a different model for one run
  Summaries are saved as Markdown in ~/Summaries
EOT
      return ;;
    "") ;;
    *) extra="Special focus for this summary: $*" ;;
  esac

  tmp=$(mktemp)
  _recap_input | tr -d '\r' > "$tmp"
  words=$(wc -w < "$tmp" | tr -d ' ')
  title=$(_recap_title "$tmp")

  if (( words < 20 )); then
    _recap_msg -b "Only $words words on the clipboard. Copy the article first."
    rm -f "$tmp"; return 1
  fi

  _recap_msg -b "Reading $words words with $model." "Options: short | changes | help | or your own focus in quotes"
  if (( words > 4000 )); then
    _recap_msg "Note: $words words is long for one pass." "Accuracy drops above about 2,500 words. Consider recaplong."
  elif (( words > 2500 )); then
    _recap_msg "Note: over 2,500 words." "recaplong will be more accurate if this matters."
  fi

  local out
  out=$(mktemp)
  {
    print -r -- "## $title"
    print ""
    _recap_src_line
    ollama run --nowordwrap "${tf[@]}" "$model" "$base $extra" < "$tmp" | _recap_clean
  } | tee "$out"

  _recap_save "$out" "$title"
  rm -f "$tmp" "$out"
}

_recap_save() {
  local out="$1" title="$2" slug file
  if [[ -n "$RECAP_COLLECT" ]]; then   # recapurl --single: add to the combined file instead
    [[ -s "$RECAP_COLLECT" ]] && { print -r -- "---"; print ""; } >> "$RECAP_COLLECT"
    cat "$out" >> "$RECAP_COLLECT"
    _recap_msg "Added to the combined file."
    return
  fi
  mkdir -p "$RECAP_DIR"
  slug=$(_recap_slug "$title")
  [[ -z "$slug" ]] && slug="summary"
  file="$RECAP_DIR/$(date +%Y-%m-%d)-$slug.md"
  local n=2
  while [[ -e "$file" ]]; do
    file="$RECAP_DIR/$(date +%Y-%m-%d)-$slug-$n.md"; n=$((n+1))
  done
  cp "$out" "$file"
  _recap_msg "Saved:" "  $file"
}

alias recapc='recap | tee >(pbcopy)'

# --- read one long text in parts, then combine (used by recaplong and recapall) ---
_recap_long_core() {   # $1 = text file, $2 = title, rest = optional focus; summary goes to stdout
  local src="$1" title="$2"; shift 2
  local model="${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}"
  local tmp notes f i=0 n words
  local -a tf parts
  tf=(${=$(_recap_flags "$model")})
  tmp=$(mktemp -d); notes=$(mktemp)
  words=$(wc -w < "$src" | tr -d ' ')

  awk -v d="$tmp" -v max="${RECAP_CHUNK:-1200}" '
    BEGIN{n=1; c=0}
    { if (c + NF > max && c > 0) { n++; c=0 }
      print > sprintf("%s/chunk_%03d.txt", d, n); c += NF }' "$src"

  parts=("$tmp"/chunk_*.txt(N))
  n=${#parts}
  _recap_msg "Reading $words words in $n parts with $model." "This takes roughly $((n*45)) seconds."

  for f in $parts; do
    i=$((i+1))
    echo "  part $i of $n..." >&2
    print -r -- "--- Part $i ---" >> "$notes"
    ollama run --nowordwrap "${tf[@]}" "$model" \
"This is one part of a longer document. List everything it contains as short bullets: the facts, figures, names, dates, claims, arguments and quotes. Say exactly who said or did each thing. Keep names and numbers exactly as written and keep hedges such as 'possibly' or 'the best explanation is'. Do not summarise, shorten or add anything, and write no introduction." \
      < "$f" >> "$notes"
    print "" >> "$notes"
  done

  _recap_msg "  combining..."
  ollama run --nowordwrap "${tf[@]}" "$model" \
    "$(_recap_prompt) The text below is a set of notes taken in order from a longer document, not the document itself. Summarise what the document says. $*" \
    < "$notes" | _recap_clean | _recap_dedupe

  mkdir -p "$RECAP_DIR"
  cp "$notes" "$RECAP_DIR/$(date +%Y-%m-%d)-$(_recap_slug "$title")-notes.txt"
  rm -rf "$tmp"; rm -f "$notes"
}

# --- several articles ----------------------------------------------
# Articles over RECAP_LONG_WORDS (default 4000) are read in parts, like recaplong.
recapall() {
  local tmp out f i=0 n words title
  local -a parts
  tmp=$(mktemp -d); out=$(mktemp)

  pbpaste | tr -d '\r' | awk -v d="$tmp" '
    BEGIN{n=1}
    /^@@@@[[:space:]]*$/ {n++; next}
    {print > sprintf("%s/part_%03d.txt", d, n)}'

  parts=("$tmp"/part_*.txt(N))
  n=${#parts}
  if (( n == 0 )); then
    _recap_msg -b "Nothing found on the clipboard."; rm -rf "$tmp" "$out"; return 1
  fi
  (( n == 1 )) && _recap_msg -b "Only one article found." "Put @@@@ alone on a line between articles."

  for f in $parts; do
    words=$(wc -w < "$f" | tr -d ' ')
    (( words < 30 )) && continue
    i=$((i+1))
    title=$(_recap_title "$f")
    if (( i == 1 && n > 1 )); then _recap_msg -b "Article $i of $n - $words words"; else _recap_msg "Article $i of $n - $words words"; fi
    if (( words > ${RECAP_LONG_WORDS:-4000} )); then
      _recap_msg "Long article: reading it in parts, as recaplong does."
      _recap_long_core "$f" "$title" "$@" > "$tmp/long-summary.txt"
    fi
    {
      print -r -- "## $title"
      print ""
      if (( words > ${RECAP_LONG_WORDS:-4000} )); then
        cat "$tmp/long-summary.txt"
      else
        ollama run --nowordwrap ${=$(_recap_flags "${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}")} \
          "${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}" "$(_recap_prompt) $*" < "$f" | _recap_clean
      fi
      print ""
    } | tee -a "$out"
  done

  if (( i == 0 )); then
    if (( n > 1 )); then _recap_msg -b "No article with at least 30 words found." "Nothing saved; clipboard left unchanged."
    else _recap_msg "No article with at least 30 words found." "Nothing saved; clipboard left unchanged."; fi
    rm -rf "$tmp"; rm -f "$out"; return 1
  fi

  pbcopy < "$out"
  _recap_save "$out" "batch-of-$i-articles"
  rm -rf "$tmp"; rm -f "$out"
  _recap_msg "Done. All summaries are also on your clipboard."
}

# --- long article or transcript (reads it in parts) -----------------
recaplong() {
  local tmp out title words
  tmp=$(mktemp); out=$(mktemp)

  _recap_input | tr -d '\r' > "$tmp"
  words=$(wc -w < "$tmp" | tr -d ' ')
  title=$(_recap_title "$tmp")

  if (( words < 20 )); then
    _recap_msg -b "Only $words words on the clipboard. Copy the text first."
    rm -f "$tmp" "$out"; return 1
  fi

  [[ -z "$RECAP_NO_LEAD" ]] && print -u2 ""
  local sumf; sumf=$(mktemp)
  _recap_long_core "$tmp" "$title" "$@" > "$sumf"
  {
    print -r -- "## $title"
    print ""
    _recap_src_line
    cat "$sumf"
  } | tee "$out"

  _recap_save "$out" "$title"
  rm -f "$tmp" "$out" "$sumf"
}

# --- YouTube captions ---------------------------------------------------
# Exit codes of _recap_fetch_yt: 2 no video address in the link, 3 no captions, 4 video unavailable,
# 5 sign-in / age check, 6 blocked by YouTube, 7 other error (error=Name). Other stdout: lang=Name generated=0|1
_recap_fetch_yt() {   # $1 = address, $2 = output file
  "$(_recap_py)" - "$1" "$2" <<'PY'
import html as htmllib
import json
import re
import sys
import urllib.parse
import urllib.request

url, out = sys.argv[1], sys.argv[2]

def video_id(u):
    p = urllib.parse.urlparse(u)
    host = (p.hostname or "").lower()
    cand = None
    if host.endswith("youtu.be"):
        cand = p.path.strip("/").split("/")[0]
    elif "youtube.com" in host:
        if p.path == "/watch":
            cand = urllib.parse.parse_qs(p.query).get("v", [""])[0]
        else:
            m = re.match(r"^/(?:shorts|live|embed|v)/([^/?]+)", p.path)
            cand = m.group(1) if m else None
    return cand if cand and re.fullmatch(r"[A-Za-z0-9_-]{11}", cand) else None

vid = video_id(url)
if not vid:
    sys.exit(2)

try:
    from youtube_transcript_api import YouTubeTranscriptApi
    from youtube_transcript_api import (AgeRestricted, CouldNotRetrieveTranscript, InvalidVideoId, IpBlocked,
        NoTranscriptFound, PoTokenRequired, RequestBlocked, TranscriptsDisabled, VideoUnavailable, VideoUnplayable)
    transcripts = list(YouTubeTranscriptApi().list(vid))
    if not transcripts:
        sys.exit(3)
    def english(t):
        return t.language_code.split("-")[0].lower() == "en"
    order = [
        [t for t in transcripts if english(t) and not t.is_generated],
        [t for t in transcripts if english(t) and t.is_generated],
        [t for t in transcripts if not t.is_generated],
        [t for t in transcripts if t.is_generated],
    ]
    chosen = next(group[0] for group in order if group)
    fetched = chosen.fetch()
except SystemExit:
    raise
except InvalidVideoId:
    sys.exit(2)
except (TranscriptsDisabled, NoTranscriptFound):
    sys.exit(3)
except (VideoUnavailable, VideoUnplayable):
    sys.exit(4)
except (AgeRestricted, PoTokenRequired):
    sys.exit(5)
except RequestBlocked:      # includes IpBlocked
    sys.exit(6)
except Exception as err:
    print("error=" + type(err).__name__)
    sys.exit(7)

title, channel = "", ""
try:
    q = urllib.parse.quote("https://www.youtube.com/watch?v=" + vid, safe="")
    req = urllib.request.Request("https://www.youtube.com/oembed?format=json&url=" + q,
                                 headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=8) as r:
        meta = json.loads(r.read().decode("utf-8"))
    title, channel = (meta.get("title") or "").strip(), (meta.get("author_name") or "").strip()
except Exception:
    pass
if not title:
    title = "YouTube video " + vid

text = " ".join(htmllib.unescape(sn.text).replace("\n", " ") for sn in fetched.snippets)
text = re.sub(r"\[(?:music|applause|laughter|laughs|inaudible|silence|cheering|crosstalk|singing)\]", " ", text, flags=re.I)
text = re.sub(r"\s*>>\s*", "\n\n", text)            # '>>' marks a change of speaker in captions
paras = []
for para in text.split("\n\n"):
    ws = para.split()
    paras += [" ".join(ws[i:i + 100]) for i in range(0, len(ws), 100)] + [""] if ws else []
body = "\n".join(paras).strip()
if not body:
    sys.exit(3)
head = title + "\n\n" + ("Channel: " + channel + "\n\n" if channel else "")
with open(out, "w", encoding="utf-8") as f:
    f.write(head + body + "\n")
print("lang=" + re.sub(r"\s*\(auto-generated\)", "", fetched.language or fetched.language_code, flags=re.I))
print("generated=" + ("1" if fetched.is_generated else "0"))
print("english=" + ("1" if english(chosen) else "0"))
PY
}

# --- PDF: an address or a file on this Mac ----------------------------------
# Exit codes of _recap_fetch_pdf: 2 no response or unreadable file, 3 no readable text (scanned), 4 HTTP error (http=NNN),
# 5 password-protected, 6 too large, 7 other error (error=Name), 9 not a PDF. Other stdout: pages=N reader=pdfium|pypdf
_recap_fetch_pdf() {   # $1 = address or file path, $2 = output file
  "$(_recap_py)" - "$1" "$2" <<'PY'
import io
import logging
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter

src, out = sys.argv[1], sys.argv[2]
logging.getLogger("pypdf").setLevel(logging.CRITICAL)
MAX = int(float(os.environ.get("RECAP_PDF_MAX_MB", "30")) * 1024 * 1024)

def fail(code, *info):
    for line in info:
        print(line)
    sys.exit(code)

# ---- get the bytes (address or file on this Mac)
try:
    if src.lower().startswith(("http://", "https://")):
        req = urllib.request.Request(src, headers={"User-Agent": "Mozilla/5.0 (compatible; recap)", "Accept": "application/pdf,*/*"})
        with urllib.request.urlopen(req, timeout=40) as r:
            data = r.read(MAX + 1)
    else:
        if os.path.getsize(src) > MAX:
            fail(6)
        with open(src, "rb") as fh:
            data = fh.read()
except urllib.error.HTTPError as e:
    fail(4, f"http={e.code}")
except SystemExit:
    raise
except Exception:
    fail(2)
if len(data) > MAX:
    fail(6)
if b"%PDF" not in data[:1024]:
    fail(9)

# ---- read the pages: pypdfium2 if installed (cleaner spacing), else pypdf
want = os.environ.get("RECAP_PDF_READER", "")
engine = ""
if want != "pypdf":
    try:
        import pypdfium2 as pdfium
        engine = "pdfium"
    except Exception:
        engine = ""
if not engine:
    try:
        import pypdf
        engine = "pypdf"
    except Exception:
        fail(7, "error=NoPdfReader")
pages = []
try:
    if engine == "pdfium":
        try:
            doc = pdfium.PdfDocument(data)
        except Exception as err:
            if "password" in str(err).lower():
                fail(5)
            raise
        for i in range(len(doc)):
            try:
                pages.append(doc[i].get_textpage().get_text_range() or "")
            except Exception:
                pages.append("")
        doc.close()
    else:
        reader = pypdf.PdfReader(io.BytesIO(data))
        if reader.is_encrypted:
            try:
                unlocked = reader.decrypt("")
            except Exception as err:
                if type(err).__name__ == "DependencyError":
                    fail(7, "error=DependencyError")
                unlocked = 0
            if not unlocked:
                fail(5)
        for pg in reader.pages:
            try:
                pages.append(pg.extract_text() or "")
            except Exception:
                pages.append("")
except SystemExit:
    raise
except Exception as err:
    fail(7, "error=" + type(err).__name__)
n = len(pages)

# ---- clean: ligatures, soft hyphens, odd spaces
def norm(s):
    s = s.replace("\u00ad", "")
    for a, b in (("\ufb01", "fi"), ("\ufb02", "fl"), ("\ufb00", "ff"), ("\ufb03", "ffi"), ("\ufb04", "ffl"), ("\u00a0", " ")):
        s = s.replace(a, b)
    s = s.replace("\ufffe", "").replace("\uffff", "")     # pdfium marks a line-end hyphen inside the rejoined word
    s = re.sub(r"[\x00-\x08\x0b-\x1f]", "", s)
    return re.sub(r"[ \t]+", " ", s).strip()

page_lines = [[norm(l) for l in p.replace("\r", "\n").split("\n") if norm(l)] for p in pages]

# ---- patterns
NUM = re.compile(r"^(?:page\s*)?[-\u2013\u2014\[(]?\s*\d{1,4}\s*[-\u2013\u2014\])]?(?:\s*(?:of|/)\s*\d{1,4})?$", re.I)
ROMAN = re.compile(r"^(?:[ivxlc]{1,5}|[IVXLC]{1,5})$")
URL_ONLY = re.compile(r"^(?:https?://)?(?:www\.)?[a-z0-9-]+(?:\.[a-z0-9-]+)*\.[a-z]{2,}(?:/\S*)?$", re.I)
LEGAL = re.compile(r"^(?:copyright\b|\u00a9)|all rights reserved", re.I)
def key(l):
    return re.sub(r"\d+", "#", l.lower())

# ---- headers and footers repeated on many pages
repeated = set()
if n >= 4:
    cnt = Counter()
    for lines in page_lines:
        cnt.update({key(l) for l in lines[:3] + lines[-3:] if len(l) < 90})
    repeated = {k for k, c in cnt.items() if c >= max(3, 0.5 * n)}
    edge_keys = {key(l) for lines in page_lines for l in lines[:3] + lines[-3:] if len(l) < 90}
    for k in list(repeated):                      # 'AB' glued on later pages, 'A' and 'B' separate on earlier ones
        for a in edge_keys:
            if a and a != k and k.startswith(a) and k[len(a):] in edge_keys:
                repeated.update({a, k[len(a):]})

# ---- title: PDF metadata is unreliable, so use the first sensible line of page 1, else the file name
alllens = sorted(len(l) for lines in page_lines for l in lines)
typical = alllens[int(0.9 * (len(alllens) - 1))] if alllens else 0
def title_candidates():
    for l in (page_lines[0][:14] if page_lines else []):
        if len(l) >= 0.6 * typical:
            continue                                  # a full-width line is body text, not a title
        if URL_ONLY.match(l) or NUM.match(l) or LEGAL.search(l) or l.lower().startswith("by "):
            continue
        letters = re.sub(r"[^A-Za-z]", "", l)
        if letters and letters.isupper() and key(l) in repeated:
            continue                                  # a running label such as HBR CASE STUDY
        if 3 <= len(l) <= 120 and not l.endswith((".", ",", ";")):
            yield l
title = next(title_candidates(), "")

# ---- drop page numbers, running headers, web addresses at the page edge, legal lines
kept = []
for lines in page_lines:
    m = len(lines)
    for i, l in enumerate(lines):
        edge = i < 3 or i >= m - 3
        edge2 = i < 2 or i >= m - 2
        if edge and (key(l) in repeated or URL_ONLY.match(l)):
            continue
        if edge2 and (NUM.match(l) or ROMAN.match(l)):
            continue
        if len(l) < 200 and LEGAL.search(l):
            continue
        kept.append(l)

# ---- join the hard-wrapped lines into paragraphs
END = tuple('.!?:;"\u201d\u2019)\']')
lens = sorted(len(l) for l in kept)
p90 = lens[int(0.9 * (len(lens) - 1))] if lens else 0
def short(l):
    return len(l) < 0.6 * p90
paras, cur = [], ""
for i, l in enumerate(kept):
    nxt = kept[i + 1] if i + 1 < len(kept) else ""
    if cur and cur.endswith("-") and len(cur) > 1 and cur[-2].isalpha() and l[:1].islower():
        cur = cur[:-1] + l                       # word split by a hyphen at the line end: mend it
    elif cur and cur.endswith("-") and len(cur) > 1 and cur[-2].isalpha() and l[:1].isupper():
        cur = cur + l                            # a real hyphen before a capital (Anglo-Saxon)
    elif cur:
        cur += " " + l
    else:
        cur = l
    if short(l) and (l.endswith(END) or nxt[:1].isupper() or nxt[:1].isdigit() or not nxt):
        paras.append(cur)
        cur = ""
if cur:
    paras.append(cur)
paras = [p for p in paras if p.strip()]
words = len(" ".join(paras).split())
if words < 30:
    fail(3, f"pages={n}")

# ---- assemble: title line first (not repeated in the body), then the text
if not title:
    base = os.path.basename(urllib.parse.urlparse(src).path) if src.lower().startswith(("http://", "https://")) else os.path.basename(src)
    base = urllib.parse.unquote(base)
    title = re.sub(r"\.pdf$", "", base, flags=re.I).replace("_", " ").replace("+", " ").strip() or "PDF document"
body = paras[1:] if paras and paras[0] == title else paras
with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join([title, ""] + body).strip() + "\n")
print(f"pages={n}")
print(f"reader={engine}")
PY
}

# --- web page: fetch, clean, summarise ------------------------------
# Exit codes of _recap_fetch: 2 no response, 3 no article text, 4 HTTP error (http=NNN), 8 it is a PDF,
# 5 redirected to a login page. Other lines on stdout: paywall=1  cutoff=1
_recap_fetch() {   # $1 = address, $2 = output file
  "$(_recap_py)" - "$1" "$2" <<'PY'
import re
import sys
import trafilatura
from trafilatura import downloads

url, out = sys.argv[1], sys.argv[2]
html, final = None, url
try:
    resp = downloads.fetch_response(url, decode=True)
except Exception:
    resp = None
    html = trafilatura.fetch_url(url)
if resp is not None:
    if resp.status != 200:
        print(f"http={resp.status}")
        sys.exit(4)
    if "application/pdf" in ((getattr(resp, "headers", None) or {}).get("content-type", "") or "").lower():
        sys.exit(8)                      # the address serves a PDF: recapurl then reads it as one
    html, final = resp.html, (resp.url or url)
if not html:
    sys.exit(2)
if re.search(r"/(login|log-in|signin|sign-in|subscribe|register|paywall)\b", final.lower()) and final != url:
    print(f"final={final}")
    sys.exit(5)

text = trafilatura.extract(html, url=url, include_comments=False)
if not text:
    sys.exit(3)
meta = trafilatura.extract_metadata(html)
title = ((meta.title if meta else "") or "").strip()
author = ((meta.author if meta else "") or "").strip()
body = text.strip()
if title and not body.lower().startswith(title.lower()):
    body = title + "\n\n" + body
if author and author.lower() not in body[:400].lower():
    first, _, rest = body.partition("\n")
    body = first + "\n\nBy " + author + "\n" + rest
with open(out, "w", encoding="utf-8") as f:
    f.write(body.strip() + "\n")

if re.search(r'"isAccessibleForFree"\s*:\s*"?false"?', html, re.I):
    print("paywall=1")
# A cut-off teaser: the text ends mid-sentence AND the page has subscription wording.
# (A missing final full stop alone is common on free pages, so it is not enough.)
last = text.strip().splitlines()[-1].strip()
gate = re.search(
    r"already (have an account|a subscriber|a member)|sign up to get access|to continue reading"
    r"|subscribe to (continue|read|unlock)|unlock (this|the full)|members[- ]only",
    html, re.I)
if gate and len(last) >= 60 and last[-1].isalnum():
    print("cutoff=1")
PY
}

# recapurl "ADDRESS" [short | changes | "focus text"]
# Pages over RECAP_LONG_WORDS (default 4000) are read in parts, like recaplong.
# The extracted text is saved as ~/Summaries/DATE-title-source.txt so you can check the summary against it.
_recap_has_pdf_reader() {   # pypdfium2 (cleaner text) or pypdf
  local py; py="$(_recap_py)"
  "$py" -c 'import pypdfium2' 2>/dev/null || "$py" -c 'import pypdf' 2>/dev/null
}

_recap_is_addr() {   # is this argument an address or a PDF file, rather than a mode or focus text?
  local a="$1"
  [[ "$a" == "~/"* ]] && a="$HOME/${a:2}"
  [[ "$a" == http://* || "$a" == https://* || "$a" == www.* ]] && return 0
  [[ "${a:l}" == *.pdf && ( -f "$a" || "$a" == /* || "$a" == ./* || "$a" == ../* ) ]] && return 0
  return 1
}

_recap_url_one() {   # one address (web page or YouTube video) + optional mode or focus text; returns 1 if nothing was summarised
  local url="$1" tmp info code words title slug srcfile http_status final cutoff=0 paywall=0 src_note is_yt=0 yt_lang yt_gen=0 yt_en=1 min_words=150 is_pdf=0 local_pdf=0 pdf_pages pg=""
  shift
  _RECAP_FIRST_MSG=""
  [[ "$url" == "~/"* ]] && url="$HOME/${url:2}"
  if [[ "${url:l}" == *.pdf && "$url" != http://* && "$url" != https://* ]]; then   # a PDF file on this Mac
    if [[ -f "$url" ]]; then
      is_pdf=1; local_pdf=1
    elif [[ "$url" == /* || "$url" == ./* || "$url" == ../* ]]; then
      _recap_msg -b "File not found: $url"
      return 1
    fi
  fi
  (( local_pdf )) || { [[ "$url" == http://* || "$url" == https://* ]] || url="https://$url"; }

  case "${url:l}" in
    *youtube.com/watch*|*youtube.com/shorts/*|*youtube.com/live/*|*youtube.com/embed/*|*youtube.com/v/*|*youtu.be/*)
      is_yt=1 ;;
    *youtube.com/*)
      _recap_msg -b "That looks like a YouTube channel, playlist or search page." "Give the link to a single video."
      return 1 ;;
    *vimeo.com/*|*spotify.com/*|*podcasts.apple.com/*|*soundcloud.com/*|*.mp3|*.mp4|*.m4a|*.wav|*.mov|*.webm)
      _recap_msg -b "That looks like a video or audio link." "recapurl reads web articles and YouTube captions only."
      return 1 ;;
    *.pdf|*.pdf\?*|*.pdf\#*)
      is_pdf=1 ;;
  esac

  if (( is_yt )); then
    "$(_recap_py)" -c 'import youtube_transcript_api' 2>/dev/null || {
      _recap_msg -b "youtube-transcript-api is not installed." "Run this, then try again:" "  recapsetup"
      return 1
    }
    min_words=60
  elif (( is_pdf )); then
    _recap_has_pdf_reader || {
      _recap_msg -b "No PDF reader is installed." "Run this, then try again:" "  recapsetup"
      return 1
    }
    min_words=60
  else
    "$(_recap_py)" -c 'import trafilatura' 2>/dev/null || {
      _recap_msg -b "trafilatura is not installed." "Run this, then try again:" "  recapsetup"
      return 1
    }
  fi

  tmp=$(mktemp)
  if (( local_pdf )); then _recap_msg -b "Reading PDF file:" "  $url"; else _recap_msg -b "Fetching:" "  $url"; fi
  _RECAP_FIRST_MSG=""
  if (( is_yt )); then
    info=$(_recap_fetch_yt "$url" "$tmp"); code=$?
    yt_lang=$(print -r -- "$info" | sed -n 's/^lang=//p' | head -1)
    [[ "$info" == *generated=1* ]] && yt_gen=1
    [[ "$info" == *english=0* ]] && yt_en=0
  elif (( is_pdf )); then
    info=$(_recap_fetch_pdf "$url" "$tmp"); code=$?
  else
    info=$(_recap_fetch "$url" "$tmp"); code=$?
    if (( code == 8 )); then   # the address serves a PDF without saying so in its name
      is_pdf=1; min_words=60
      _recap_has_pdf_reader || {
        _recap_msg "That address is a PDF, and no PDF reader is installed." "Run this, then try again:" "  recapsetup"
        rm -f "$tmp"; return 1
      }
      info=$(_recap_fetch_pdf "$url" "$tmp"); code=$?
    fi
  fi
  pdf_pages=$(print -r -- "$info" | sed -n 's/^pages=//p' | head -1)
  if [[ -n "$pdf_pages" ]]; then pg=" ($pdf_pages pages)"; [[ "$pdf_pages" == 1 ]] && pg=" (1 page)"; fi
  http_status=$(print -r -- "$info" | sed -n 's/^http=//p' | head -1)
  final=$(print -r -- "$info" | sed -n 's/^final=//p' | head -1)
  [[ "$info" == *cutoff=1* ]] && cutoff=1
  [[ "$info" == *paywall=1* ]] && paywall=1

  if (( is_yt )); then
    case $code in
      0) ;;
      2) _recap_msg "Could not find a video in that link." "Nothing summarised." ;;
      3) _recap_msg "This video has no captions available." "The owner may have turned them off. recapurl cannot summarise a video without captions." "Nothing summarised." ;;
      4) _recap_msg "YouTube says the video is unavailable." "It may be private, removed, or not viewable in your region." "Nothing summarised." ;;
      5) _recap_msg "YouTube wants a sign-in or age check for this video." "Nothing summarised." ;;
      6) _recap_msg "YouTube blocked the request." "This sometimes clears after a while or on another network." "You can also open the video, choose Show transcript, copy the text and use recap." "Nothing summarised." ;;
      *) _recap_msg "Could not read the captions ($(print -r -- "$info" | sed -n 's/^error=//p' | head -1))." "Nothing summarised." ;;
    esac
    [[ $code != 0 ]] && { rm -f "$tmp"; return 1; }
  elif (( is_pdf )); then
    case $code in
      0) ;;
      2) if (( local_pdf )); then _recap_msg "Could not read that file." "Nothing summarised."
         else _recap_msg "No response from the site." "Possible causes: a network, security-certificate or timeout problem." "Nothing summarised."; fi ;;
      3) _recap_msg "No readable text in this PDF$pg." "It is probably scanned pages, which are images. recapurl cannot read those." "Nothing summarised." ;;
      4) case "$http_status" in
           401|403|429) _recap_msg "The site answered with HTTP $http_status instead of the PDF." "That usually means it blocks automated downloads or needs a login." "Download the file in your browser and run recapurl on the saved file." ;;
           404|410) _recap_msg "The site answered with HTTP $http_status instead of the PDF." "That usually means the address is wrong or the file was removed." ;;
           *) _recap_msg "The site answered with HTTP $http_status instead of the PDF." "Try again later, or download it in your browser and run recapurl on the saved file." ;;
         esac ;;
      5) _recap_msg "This PDF is password-protected." "Nothing summarised." ;;
      6) _recap_msg "That PDF is larger than ${RECAP_PDF_MAX_MB:-30} MB." "Nothing summarised. To raise the limit:" "  RECAP_PDF_MAX_MB=60 recapurl \"$url\"" ;;
      9) _recap_msg "That link did not return a PDF." "It may be a web page or a login page." "Nothing summarised." ;;
      *) if [[ "$info" == *error=DependencyError* ]]; then
           _recap_msg "This PDF is encrypted in a way the basic PDF reader cannot open." "Run this, then try again:" "  recapsetup"
         else
           _recap_msg "Could not read the PDF ($(print -r -- "$info" | sed -n 's/^error=//p' | head -1))." "The file may be damaged. Nothing summarised."
         fi ;;
    esac
    [[ $code != 0 ]] && { rm -f "$tmp"; return 1; }
  else
  case $code in
    0) ;;
    2) _recap_msg "No response from the site." "Possible causes: a network, security-certificate or timeout problem." "Nothing summarised."
       rm -f "$tmp"; return 1 ;;
    4) case "$http_status" in
         401|403|429) _recap_msg "The site answered with HTTP $http_status instead of the page." "That usually means it blocks automated downloads or needs a login." "Copy the text and use recap." ;;
         404|410) _recap_msg "The site answered with HTTP $http_status instead of the page." "That usually means the address is wrong or the page was removed." ;;
         *) _recap_msg "The site answered with HTTP $http_status instead of the page." "Try again later, or copy the text and use recap." ;;
       esac
       rm -f "$tmp"; return 1 ;;
    5) _recap_msg "The site redirected to a login or subscribe page." "  $final" "Nothing summarised."
       rm -f "$tmp"; return 1 ;;
    3) _recap_msg "No article text found on that page." "It may need a login or be built with scripts." "Nothing summarised."
       rm -f "$tmp"; return 1 ;;
    *) _recap_msg "Could not read the page (error $code)." "Nothing summarised."
       rm -f "$tmp"; return 1 ;;
  esac
  fi

  words=$(wc -w < "$tmp" | tr -d ' ')
  title=$(_recap_title "$tmp")
  slug=$(_recap_slug "$title"); [[ -z "$slug" ]] && slug="page"
  mkdir -p "$RECAP_DIR"
  srcfile="$RECAP_DIR/$(date +%Y-%m-%d)-$slug-source.txt"
  { print -r -- "Source: $url"; print ""; cat "$tmp"; } > "$srcfile"

  if [[ "$RECAP_URL_FORCE" != 1 ]]; then
    if (( words < ${RECAP_URL_MIN:-$min_words} )); then
      if (( is_yt )); then
        _recap_msg "Only $words words of captions came back." "The video may be very short or mostly music." "Nothing summarised."
      elif (( is_pdf )); then
        _recap_msg "Only $words words of text came back." "The PDF may be mostly images or very short." "Nothing summarised."
      else
        _recap_msg "Only $words words came back." "The page may be paywalled, need a login or be mostly scripts." "Nothing summarised."
      fi
      _recap_msg "Extracted text saved so you can look:" "  $srcfile"
      rm -f "$tmp"; return 1
    fi
    if (( words > ${RECAP_URL_MAX:-10000} )); then
      _recap_msg "That is $words words: too long to summarise reliably in one go." "The part-by-part method is only tested up to about 6,600 words, and past roughly 10,000 words its notes probably no longer fit in the model's memory."
      _recap_msg "Text saved so you can copy one chapter or section and use recaplong:" "  $srcfile"
      _recap_msg "To try the whole text anyway, run:" "  RECAP_URL_MAX=$((words + 1000)) recapurl \"$url\""
      rm -f "$tmp"; return 1
    fi
    if (( paywall )); then
      _recap_msg "Stopped: the page marks its article as paywalled (members only)." "What came back is probably a teaser or a subscription notice." "Nothing summarised."
      _recap_msg "Extracted text saved so you can look:" "  $srcfile"
      _recap_msg "To summarise it anyway, run:" "  RECAP_URL_FORCE=1 recapurl \"$url\""
      rm -f "$tmp"; return 1
    fi
  fi
  if (( is_yt )); then
    _recap_msg "Fetched $words words of captions ($yt_lang, $( ((yt_gen)) && print automatic || print uploaded by the channel ))." "Captions saved to:" "  $srcfile"
  elif (( is_pdf )); then
    _recap_msg "Read $words words$pg from the PDF." "Text saved to:" "  $srcfile"
    if [[ "$info" == *reader=pypdf* ]]; then
      _recap_msg "Note: this used the basic PDF reader (pypdf)." "Headers and small capitals can come out garbled. For cleaner text run:" "  recapsetup"
    fi
  else
    _recap_msg "Fetched $words words." "Extracted text saved to:" "  $srcfile"
  fi
  _recap_msg "Text starts:" "$(_recap_preview "$tmp")"

  src_note="$url"
  (( is_pdf )) && src_note="$url (PDF)"
  if (( is_yt )); then
    src_note="$url (YouTube captions$( ((yt_gen)) && print ', automatic' ))"
    if (( yt_gen )); then
      _recap_msg "Note: these are YouTube's automatic captions." "They have no speaker names, little punctuation, and some misheard words." "Check names, figures and who said what against the video."
    fi
    if (( ! yt_en )); then
      _recap_msg "Note: the captions are in $yt_lang." "How well the summary works in that language is untested."
    fi
  fi
  if (( cutoff )); then
    _recap_msg "Warning: the text ends mid-sentence." "The page may be a paywalled teaser, so the summary may cover only part of the article."
    src_note="$url (text appears cut off: possibly a paywalled teaser)"
  fi

  if (( words > ${RECAP_LONG_WORDS:-4000} )); then
    case "$1" in
      short|changes)
        _recap_msg "'$1' only applies under ${RECAP_LONG_WORDS:-4000} words." "Summarising in parts without it."
        shift ;;
    esac
    RECAP_NO_LEAD=1 RECAP_INPUT="$tmp" RECAP_SOURCE="$src_note" recaplong "$@"
  else
    RECAP_NO_LEAD=1 RECAP_INPUT="$tmp" RECAP_SOURCE="$src_note" recap "$@"
  fi
  rm -f "$tmp"
  return 0
}

# Which way to save a batch: flag, then RECAP_BATCH, then ask (only in a terminal), else separate files.
_recap_batch_mode() {   # $1 = mode from the flag (single|separate|empty); prints single or separate
  local m="$1" ans
  [[ -z "$m" ]] && m="$RECAP_BATCH"
  case "$m" in single|separate) print -r -- "$m"; return ;; esac
  if [[ -t 0 && -t 2 ]]; then
    read -k 1 "ans?Save all summaries in one file, or one file per address? [o = one file, s = separate, Enter = separate] "
    print -u2 ""
    [[ "$ans" == [oO] ]] && { print -r -- single; return; }
  fi
  print -r -- separate
}

# recapurl [--single | --separate] "ADDRESS or PDF FILE" [...] [short | changes | "focus text"]
# The first argument is always an address. Further arguments that start with http:// or https://
# (or www.) are more addresses; anything after them is a mode or focus applied to every address.
recapurl() {
  local -a urls failed reasons lines
  local i=0 ok=0 j u mode="" coll="" final=""
  while [[ "$1" == --single || "$1" == --separate ]]; do mode="${1#--}"; shift; done
  if [[ -z "$1" || "$1" == help || "$1" == -h || "$1" == --help ]]; then
    _recap_msg -b "Usage: recapurl [--single | --separate] \"ADDRESS\" [\"ADDRESS\" ...] [short | changes | \"focus text\"]" "Put each address in quotes (addresses with ? or & break otherwise)."
    _recap_msg "Fetches a web article, strips menus and ads, and summarises it." "For a YouTube video it reads the captions. A PDF (an address or a file on this Mac) is read too. Not for other audio or video." "Several are summarised one after another; extra ones must start with https:// or www., or be a .pdf file." "For several addresses, --single saves all summaries in one file and --separate gives each its own." "Without a flag it asks (or set RECAP_BATCH=single or separate). With one address the flags do nothing." "To skip the paywall and short-text checks:" "  RECAP_URL_FORCE=1 recapurl \"ADDRESS\""
    [[ -z "$1" ]] && return 1
    return 0
  fi
  if [[ "$1" == --* ]]; then
    _recap_msg -b "Unknown option: $1" "Options: --single, --separate (only used with several addresses)."
    return 1
  fi
  urls=("$1"); shift
  while [[ -n "$1" ]] && _recap_is_addr "$1"; do urls+=("$1"); shift; done

  if (( ${#urls} == 1 )); then
    _recap_url_one "${urls[1]}" "$@"
    return $?
  fi

  mode=$(_recap_batch_mode "$mode")
  if [[ "$mode" == single ]]; then
    coll=$(mktemp)
    _recap_msg -b "Saving all summaries in one combined file."
  else
    _recap_msg -b "Saving one file per address."
  fi

  for u in "${urls[@]}"; do
    i=$((i+1))
    _recap_msg -b "Link $i of ${#urls}"
    if RECAP_COLLECT="$coll" RECAP_NO_LEAD=1 _recap_url_one "$u" "$@"; then
      ok=$((ok+1))
    else
      failed+=("$u"); reasons+=("$_RECAP_FIRST_MSG")
    fi
  done

  if [[ -n "$coll" ]]; then
    if (( ok > 0 )); then
      final=$(mktemp)
      {
        print -r -- "# $ok link summaries, $(date +%Y-%m-%d)"; print ""
        cat "$coll"
        if (( ${#failed} )); then
          print ""; print -r -- "## Not summarised"; print ""
          for ((j=1; j<=${#failed}; j++)); do print -r -- "- ${failed[j]}"; print -r -- "  ${reasons[j]}"; done
        fi
      } > "$final"
      _recap_save "$final" "batch-of-$ok-links"
      rm -f "$final"
    fi
    rm -f "$coll"
  fi

  if (( ${#failed} )); then
    for ((j=1; j<=${#failed}; j++)); do lines+=("  ${failed[j]}" "    ${reasons[j]}"); done
    _recap_msg -b "Finished: $ok of ${#urls} summarised." "Not summarised:" "${lines[@]}"
  else
    _recap_msg -b "Finished: all ${#urls} summarised."
  fi
  (( ${#failed} == 0 ))
}

# recapurls [--single | --separate] ["focus text"]: summarise every web address found on the clipboard
# (one per line, anything else is ignored)
recapurls() {
  local -a urls flags
  while [[ "$1" == --single || "$1" == --separate ]]; do flags+=("$1"); shift; done
  urls=(${(f)"$(pbpaste | tr -d '\r' | grep -Eo 'https?://[^[:space:]]+' | sed -E 's/[.,;:)>]+$//' | awk '!seen[$0]++')"})
  if (( ${#urls} == 0 )); then
    _recap_msg -b "No web addresses found on the clipboard." "Copy the addresses first, one per line, each starting with http:// or https://."
    return 1
  fi
  _recap_msg -b "Found ${#urls} address(es) on the clipboard:" "${(@)urls/#/  }"
  recapurl "${flags[@]}" "${urls[@]}" "$@"
}

# --- Python environment: setup and health check ----------------------
# recapsetup: create (or update) Recap's private Python environment in $RECAP_HOME/venv and install the
# packages the address commands need. Your own Python is not touched. Run it again to upgrade the packages.
recapsetup() {
  local base="${RECAP_BASE_PYTHON:-python3}" venv="$RECAP_HOME/venv" out ver
  if ! command -v "$base" >/dev/null 2>&1; then
    _recap_msg -b "Python 3 was not found ($base)." "Install it from python.org or with Homebrew (brew install python), then run recapsetup again."
    return 1
  fi
  if ! "$base" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
    ver=$("$base" -c 'import sys; print(sys.version.split()[0])' 2>/dev/null)
    _recap_msg -b "Python ${ver:-?} is too old: Recap needs Python 3.9 or newer." "Install a newer Python, then run:" "  RECAP_BASE_PYTHON=/path/to/python3 recapsetup"
    return 1
  fi
  if [[ ! -x "$venv/bin/python" ]]; then
    _recap_msg -b "Creating Recap's private Python environment in:" "  ${venv/#$HOME/~}"
    mkdir -p "$RECAP_HOME" && "$base" -m venv "$venv" 2>&1 | tail -3
    if [[ ! -x "$venv/bin/python" ]]; then
      _recap_msg "Could not create the environment." "Check that this Python includes the venv module, or try another one:" "  RECAP_BASE_PYTHON=/path/to/python3 recapsetup"
      return 1
    fi
  else
    _recap_msg -b "Updating Recap's private Python environment in:" "  ${venv/#$HOME/~}"
  fi
  _recap_msg "Installing trafilatura, youtube-transcript-api and pypdfium2." "This needs a network connection and takes about a minute."
  "$venv/bin/python" -m pip install --quiet --upgrade pip >/dev/null 2>&1
  if ! out=$("$venv/bin/python" -m pip install --quiet --upgrade trafilatura youtube-transcript-api pypdfium2 2>&1); then
    _recap_msg "The package install failed. The last lines of pip's output:" "$(print -r -- "$out" | tail -8)"
    return 1
  fi
  if ! out=$("$venv/bin/python" -c 'import trafilatura, youtube_transcript_api, pypdfium2' 2>&1); then
    _recap_msg "The packages installed but could not be loaded:" "$(print -r -- "$out" | tail -4)"
    return 1
  fi
  _recap_msg "Done. recapurl and recapurls now use this environment automatically." "To check everything, run:" "  recapdoctor"
}

# recapdoctor: check the whole setup and say what to fix. Safe to paste into a bug report.
recapdoctor() {
  local problems=0 pyproblems=0 py list m pyout line
  local default_model="${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}"
  _recap_has_model() {   # is this model in `ollama list`? A name without a tag also matches :latest
    local want="$1"
    [[ "$want" == *:* ]] || want="${want}:latest"
    print -r -- "$list" | awk 'NR>1 {print $1}' | grep -qx -- "$want"
  }
  print ""
  print "Recap check (version $RECAP_VERSION)"
  print ""
  print "System"
  if [[ "$(uname -s)" == Darwin ]]; then
    print "  ok       macOS $(sw_vers -productVersion 2>/dev/null) on $(uname -m), zsh $ZSH_VERSION"
  else
    print "  PROBLEM  this is not macOS ($(uname -s)). Recap uses pbcopy and pbpaste and supports macOS only."; problems=$((problems+1))
  fi
  if command -v pbcopy >/dev/null 2>&1 && command -v pbpaste >/dev/null 2>&1; then
    print "  ok       pbcopy and pbpaste found"
  else
    print "  PROBLEM  pbcopy or pbpaste not found"; problems=$((problems+1))
  fi
  print ""
  print "Ollama"
  if ! command -v ollama >/dev/null 2>&1; then
    print "  PROBLEM  ollama not found. Install it from https://ollama.com, then rerun recapdoctor."; problems=$((problems+1))
  else
    print "  ok       ollama found: ${$(command -v ollama)/#$HOME/~}"
    if list=$(ollama list 2>/dev/null); then
      print "  ok       Ollama is running"
      if _recap_has_model "$default_model"; then
        print "  ok       model $default_model is installed (the default)"
      else
        print "  PROBLEM  model $default_model is not installed. Build it with the ollama create commands in the README."; problems=$((problems+1))
      fi
      for m in gemma-sum llama3.2:3b; do
        if _recap_has_model "$m"; then print "  ok       optional model $m is installed"
        else print "  optional model $m is not installed ($( [[ $m == gemma-sum ]] && print 'second opinion' || print 'needed by recapmail' ))"; fi
      done
    else
      print "  PROBLEM  Ollama is installed but not running. Open the Ollama app, or run: ollama serve"; problems=$((problems+1))
    fi
  fi
  unfunction _recap_has_model 2>/dev/null
  print ""
  print "Python (only for recapurl and recapurls)"
  py="$(_recap_py)"
  if [[ -n "$RECAP_PYTHON" ]]; then print "  using    RECAP_PYTHON: ${RECAP_PYTHON/#$HOME/~}"
  elif [[ -x "$RECAP_HOME/venv/bin/python" ]]; then print "  using    the private environment: ${RECAP_HOME/#$HOME/~}/venv"
  else print "  using    python3 from your PATH (no private environment yet; recapsetup creates one)"; fi
  if ! pyout=$("$py" - 2>&1 <<'PY'
import sys
from importlib.metadata import PackageNotFoundError, version
print("python", sys.version.split()[0])
for dist in ("trafilatura", "youtube-transcript-api", "pypdfium2", "pypdf"):
    try:
        print("ok", dist, version(dist))
    except PackageNotFoundError:
        print("missing", dist)
PY
  ); then
    print "  PROBLEM  could not run Python (${py/#$HOME/~}). Run recapsetup."; problems=$((problems+1)); pyproblems=$((pyproblems+1))
  else
    print "  ok       Python $(print -r -- "$pyout" | sed -n 's/^python //p' | head -1)"
    for line in ${(f)"$(print -r -- "$pyout" | grep -E '^(ok|missing) ')"}; do
      m="${${line#* }%% *}"
      case "$line" in
        "ok "*) print "  ok       $m ${line##* }" ;;
        *) if [[ "$m" == pypdf ]]; then print "  optional pypdf is not installed (only a fallback PDF reader)"
           elif [[ "$m" == pypdfium2 && "$pyout" == *"ok pypdf "* ]]; then print "  optional pypdfium2 is not installed (pypdf will be used, with poorer PDF text)"
           else print "  PROBLEM  $m is not installed. Run recapsetup."; problems=$((problems+1)); pyproblems=$((pyproblems+1)); fi ;;
      esac
    done
  fi
  print ""
  print "Files"
  if mkdir -p "$RECAP_DIR" 2>/dev/null && touch "$RECAP_DIR/.recap-write-test" 2>/dev/null; then
    rm -f "$RECAP_DIR/.recap-write-test"
    print "  ok       summaries folder ${RECAP_DIR/#$HOME/~} is writable"
  else
    print "  PROBLEM  cannot write to ${RECAP_DIR/#$HOME/~}"; problems=$((problems+1))
  fi
  print ""
  if (( problems == 0 )); then print "Result: all checks passed."
  else
    print "Result: $problems problem(s) found."
    (( pyproblems )) && print "Python problems affect only recapurl and recapurls; the clipboard commands do not need Python."
  fi
  print ""
  (( problems == 0 ))
}

# --- email ----------------------------------------------------------
recapmail() {
  pbpaste | tr -d '\r' | ollama run --nowordwrap llama3.2:3b \
"Summarise the email below in 3 lines. Then list: who sent it and what they want from me, any tasks or deadlines, and whether a reply is needed. If there are no tasks or deadlines, write None. Use only facts in the email. Do not ask me questions."
}
