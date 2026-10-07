# ============================================================
#  Recap - offline article summarizer  (Ollama + Gemma 4)
#  Add this block to ~/.zshrc, then run:  source ~/.zshrc
#  Commands:  recap | recap short | recap changes | recaplong
#             recapall | recapc | recapmail | recapurl | recapurls | recapfind | recapsetup | recapdoctor | recap help
# ============================================================

RECAP_DIR="${RECAP_DIR:-$HOME/Summaries}"
RECAP_HOME="${RECAP_HOME:-$HOME/.recap}"
RECAP_VERSION="1.1.0"
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
  print -r -- "Summarize the text below. Start with the gist: one sentence that states the main finding or message in plain words and does not list items. Never start with 'Here is a summary'. Then give the main points as short bullets, only as many as needed, never padded, with the central figures inside them. Write the bullets in Markdown, each beginning with '- '. Do not use any headings other than 'Worth noting'. Under 'Worth noting' write only extra facts that are not already in the bullets, each as a full sentence that states a fact; never list bare names, dates or numbers. If there is nothing extra, leave out the heading. Write numbers, percentages and years in digits, never spelled out as words. Match the type of text: for news, who did what, when and why; for market or business reports, the main moves with figures and reasons; for editorials and opinion pieces, what the author argues and why; for circulars, regulations and rulings, lead with what is new, say from when it applies and who must act; for tutorials and explainers, the main tips or ideas; for research, what was studied and found; for a collection of separate stories or ideas, say so in the gist and give one bullet per item, naming who said or did it. Rules: Use only the main article; ignore sidebars, related links, promotions, addresses, signatures, bios and disclaimers. Add no outside facts, adjectives or conclusions. In an editorial, present claims as the author's, and write 'The author wants the Court to set aside the orders' rather than 'The Court set aside the orders'; use 'The editorial argues' only for a newspaper's own editorial. Say exactly who said each thing: never give a speaker's remark to the author, and never give the author's lesson to a speaker. Planned things are planned, not done. Do not link events as cause and effect unless the text does. Keep hedges and the strength of wording. Keep names, figures, dates, roles, teams and comparisons exactly as written, attach each figure only to what the text attaches it to, and do not guess. End after the last point, with no questions or offers."
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
_recap_input() {   # the text to work on: RECAP_INPUT (a file), else a file or pipe given to the command, else the clipboard
  local t
  if [[ -n "$RECAP_INPUT" ]]; then cat "$RECAP_INPUT"
  elif [[ ! -t 0 ]]; then   # recap < file.txt, or: cat file.txt | recap
    t=$(mktemp); cat > "$t"
    if [[ -s "$t" ]]; then cat "$t"; else pbpaste; fi
    rm -f "$t"
  else pbpaste
  fi
}

_recap_src_line() {   # RECAP_SOURCE = address to show under the heading; RECAP_BYLINE = author and site (or channel and site)
  if [[ -n "$RECAP_SOURCE" ]]; then
    if [[ -n "$RECAP_BYLINE" ]]; then
      print -r -- "Source: $RECAP_SOURCE  "   # two trailing spaces make a line break in Markdown
      print -r -- "$RECAP_BYLINE"
    else
      print -r -- "Source: $RECAP_SOURCE"
    fi
    print ""
  fi
}

_recap_notify() {   # $1 = SECONDS when the command started, $2 = message, $3 = subtitle, $4 = "issues" for the warning sound
  # Off unless RECAP_NOTIFY=1 (or --notify). Only for runs longer than RECAP_NOTIFY_AFTER seconds (default 20).
  [[ "${RECAP_NOTIFY:-0}" == 1 && -z "$RECAP_QUIET_DONE" ]] || return 0
  (( SECONDS - $1 >= ${RECAP_NOTIFY_AFTER:-20} )) || return 0
  local msg sub snd
  msg=$(print -rn -- "$2" | tr -d '"\\' | tr '\n' ' ')
  sub=$(print -rn -- "$3" | tr -d '"\\' | tr '\n' ' ' | cut -c1-100)
  snd=$(print -rn -- "${RECAP_NOTIFY_SOUND:-Glass}" | tr -d '"\\')
  [[ "$4" == issues ]] && snd="Basso"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$msg\" with title \"Recap\" subtitle \"$sub\" sound name \"$snd\"" >/dev/null 2>&1 && return 0
  fi
  print -n -u2 $'\a'
}

_recap_urltool() {   # keys ADDRESS...  ->  KEY<TAB>CLEAN per address.   seen DIR KEY...  ->  KEY<TAB>FILE<TAB>DATE for keys already summarized
  "$(_recap_py)" - "$@" <<'PY'
import datetime
import glob
import os
import re
import sys
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

TRACK = re.compile(
    r"^(utm_.*|fbclid|gclid|dclid|gbraid|wbraid|msclkid|mc_cid|mc_eid|igshid|yclid|_hsenc|_hsmi|"
    r"vero_id|ref_src|ref_url|s_cid|cmpid|ocid|mkt_tok|trk|trkid)$", re.I)
YT_HOSTS = ("youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be")


def norm(a):
    """Return (key, clean). Two addresses with the same key are the same page."""
    raw = a.strip()
    a = raw
    low = a.lower()
    if low.startswith(("http://", "https://")) or low.startswith("www."):
        if low.startswith("www."):
            a = "https://" + a
        try:
            u = urlsplit(a)
            host = (u.hostname or "").lower()
            port = u.port
        except ValueError:
            return "raw:" + raw, raw
        if not host or "@" in u.netloc:
            return "raw:" + raw, raw
        h = host[4:] if host.startswith("www.") else host
        if h in YT_HOSTS:
            vid = None
            if h == "youtu.be":
                vid = u.path.strip("/").split("/")[0] or None
            elif u.path == "/watch":
                vid = dict(parse_qsl(u.query)).get("v")
            else:
                m = re.match(r"^/(shorts|live|embed|v)/([^/?#]+)", u.path)
                vid = m.group(2) if m else None
            if vid and re.fullmatch(r"[A-Za-z0-9_-]{6,20}", vid):
                return "yt:" + vid, "https://www.youtube.com/watch?v=" + vid
        pairs = parse_qsl(u.query, keep_blank_values=True)
        kept = [(k, v) for k, v in pairs if not TRACK.match(k)]
        query = u.query if len(kept) == len(pairs) else urlencode(kept)
        netloc = host + (":" + str(port) if port and port not in (80, 443) else "")
        path = u.path or "/"
        clean = urlunsplit((u.scheme.lower() or "https", netloc, path, query, ""))
        key = "u:" + h + (":" + str(port) if port and port not in (80, 443) else "") + (path.rstrip("/") or "/")
        if kept:
            key += "?" + urlencode(sorted(kept))
        return key, clean
    p = os.path.expanduser(raw)
    return "f:" + os.path.realpath(p), raw


mode = sys.argv[1]
if mode == "keys":
    for a in sys.argv[2:]:
        k, c = norm(a)
        print(k + "\t" + c)
elif mode == "seen":
    folder, wanted, best = sys.argv[2], set(sys.argv[3:]), {}
    suffix = re.compile(r" \((PDF|YouTube captions[^)]*|text appears cut off[^)]*)\)$")
    for path in glob.glob(os.path.join(folder, "*.md")):
        try:
            if os.path.getsize(path) > 3000000:
                continue
            with open(path, encoding="utf-8", errors="replace") as f:
                text = f.read()
            mtime = os.path.getmtime(path)
        except OSError:
            continue
        for line in text.splitlines():
            if line.startswith("Source: "):
                key = norm(suffix.sub("", line[8:].strip()))[0]
                if key in wanted and (key not in best or mtime > best[key][0]):
                    best[key] = (mtime, path)
    for key, (mtime, path) in best.items():
        d = datetime.datetime.fromtimestamp(mtime)
        print(key + "\t" + path + "\t" + d.strftime("%b") + " " + str(d.day) + ", " + str(d.year))
PY
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

_recap_looks_like_command() {   # $1 = file: is its first line a Recap or clipboard command (copied by mistake)?
  local first
  first=$(grep -m1 -v '^[[:space:]]*$' "$1" | tr -d '\r')
  [[ "$first" =~ '^(recap[a-z]*|pbcopy|pbpaste)([[:space:]]|$)' ]] || return 1
  print -r -- "$first"
}

_recap_flags() {   # --think=false only for models that accept it
  case "$1" in
    gemma4*|qwen*) print -r -- "--think=false" ;;
    *) ;;
  esac
}

# --- one article ---------------------------------------------------
recap() {
  [[ "$1" == --notify ]] && { local RECAP_NOTIFY=1; shift; }
  local t0=$SECONDS
  local mode="$1" extra="" tmp title words model base first
  model="${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}"
  local -a tf
  tf=(${=$(_recap_flags "$model")})
  base="$(_recap_prompt)"

  case "$mode" in
    short) base="Summarize the text below in one sentence, then give up to 3 short bullet takeaways in Markdown, each beginning with '- '. Start with the summary itself, never an introduction. Use 'The editorial argues' only for a newspaper's own editorial, and then present the claims as the author's. Say exactly who said each thing. Keep hedges and the strength of wording. Write numbers in digits. Attach each figure only to what the text attaches it to. Use only the main article; ignore related links, sidebars, addresses, signatures and disclaimers. Do not ask me any questions." ;;
    changes) extra="Special focus for this summary: the text changes an earlier rule or circular. State clearly which clauses or points are new or changed, using their clause numbers, and which are existing or unchanged. Then say who must act and from when. Mention the number and date of the earlier circular only as the one being modified." ;;
    version|-V|--version) print -r -- "Recap $RECAP_VERSION"; return ;;
    help|-h|--help)
      cat <<'EOT'
  recap               adaptive summary of the text on the clipboard (or: recap < file.txt)
  recap short         one sentence plus up to 3 takeaways
  recap changes       for circulars and rules: new vs unchanged clauses
  recap "focus text"  your own focus, e.g. recap "focus on costs"
  recaplong           long articles and transcripts: reads it in parts (slow but accurate)
  recapall            several articles separated by lines containing only @@@@
  recapc              same as recap, and also copies the summary to the clipboard
  recapmail           short email summary: sender, tasks, deadlines, reply needed
  recapurl "ADDRESS"  fetch a web article or YouTube captions, or read a PDF (address or file), and summarize (quote it)
  recapurl "A" "B"    several addresses, one after another (--single: one file, --separate: one each)
  recapurl FOLDER     summarize every PDF in a folder; --again redoes one already summarized; --notify ends with a notification
  recapurls           summarize the addresses typed after it, or every address on the clipboard (one per line)
  recapfind "words"    search your saved summaries (every word must appear)
  recapsetup          one-time setup: private Python environment and the summarizing model
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
    if first=$(_recap_looks_like_command "$tmp"); then
      _recap_msg -b "The clipboard holds a command, not an article: $first" "Copying a command (for example from a web page or a chat) replaces the article you copied before it." "Copy the article again, then TYPE the command instead of copying it. Or give Recap the file: recap < file.txt"
    else
      _recap_msg -b "Only $words words found." "Copy the article first (Command + C), or give a file: recap < file.txt"
    fi
    rm -f "$tmp"; return 1
  fi

  _recap_msg -b "Reading $words words with $model." "Options: short | changes | help | or your own focus in quotes"
  if (( words > 4000 )); then
    _recap_msg "Note: $words words is long for one pass." "Accuracy drops above about 2,500 words. Consider recaplong."
  elif (( words > 2500 )); then
    _recap_msg "Note: over 2,500 words." "recaplong will be more accurate if this matters."
  fi

  _recap_ensure_ollama || { rm -f "$tmp"; return 1; }
  local out
  out=$(mktemp)
  {
    print -r -- "## $title"
    print ""
    _recap_src_line
    ollama run --nowordwrap "${tf[@]}" "$model" "$base $extra" < "$tmp" | _recap_clean
  } | tee "$out"

  if ! _recap_has_summary "$out"; then
    _recap_msg "No summary was produced." "The model returned nothing, so nothing was saved. Run recapdoctor to check the setup, then try again."
    _RECAP_FIRST_MSG="No summary was produced."
    rm -f "$tmp" "$out"; return 1
  fi
  _recap_save "$out" "$title"
  _recap_notify "$t0" "Summary ready" "$title"
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

unalias recapc 2>/dev/null   # older versions defined recapc as an alias, which blocks the function below
recapc() { recap "$@" | tee >(pbcopy); }   # same as recap, and the summary is also copied to the clipboard

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
"This is one part of a longer document. List everything it contains as short bullets: the facts, figures, names, dates, claims, arguments and quotes. Say exactly who said or did each thing. Keep names and numbers exactly as written and keep hedges such as 'possibly' or 'the best explanation is'. Do not summarize, shorten or add anything, and write no introduction." \
      < "$f" >> "$notes"
    print "" >> "$notes"
  done

  _recap_msg "  combining..."
  ollama run --nowordwrap "${tf[@]}" "$model" \
    "$(_recap_prompt) The text below is a set of notes taken in order from a longer document, not the document itself. Summarize what the document says. $*" \
    < "$notes" | _recap_clean | _recap_dedupe

  mkdir -p "$RECAP_DIR"
  cp "$notes" "$RECAP_DIR/$(date +%Y-%m-%d)-$(_recap_slug "$title")-notes.txt"
  rm -rf "$tmp"; rm -f "$notes"
}

# --- several articles ----------------------------------------------
# Articles over RECAP_LONG_WORDS (default 4000) are read in parts, like recaplong.
recapall() {
  [[ "$1" == --notify ]] && { local RECAP_NOTIFY=1; shift; }
  local t0=$SECONDS
  local tmp out f i=0 n words title
  local -a parts
  tmp=$(mktemp -d); out=$(mktemp)

  _recap_input | tr -d '\r' | awk -v d="$tmp" '
    BEGIN{n=1}
    /^@@@@[[:space:]]*$/ {n++; next}
    {print > sprintf("%s/part_%03d.txt", d, n)}'

  parts=("$tmp"/part_*.txt(N))
  n=${#parts}
  if (( n == 0 )); then
    _recap_msg -b "Nothing found to read." "Copy the articles first, or give a file: recapall < file.txt"; rm -rf "$tmp" "$out"; return 1
  fi
  (( n == 1 )) && _recap_msg -b "Only one article found." "Put @@@@ alone on a line between articles."
  _recap_ensure_ollama || { rm -rf "$tmp"; rm -f "$out"; return 1; }

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
  _recap_notify "$t0" "$i summaries ready" "recapall"
}

# --- long article or transcript (reads it in parts) -----------------
recaplong() {
  [[ "$1" == --notify ]] && { local RECAP_NOTIFY=1; shift; }
  local t0=$SECONDS
  local tmp out title words first
  tmp=$(mktemp); out=$(mktemp)

  _recap_input | tr -d '\r' > "$tmp"
  words=$(wc -w < "$tmp" | tr -d ' ')
  title=$(_recap_title "$tmp")

  if (( words < 20 )); then
    if first=$(_recap_looks_like_command "$tmp"); then
      _recap_msg -b "The clipboard holds a command, not a text: $first" "Copying a command replaces the text you copied before it." "Copy the text again, then TYPE the command instead of copying it. Or give Recap the file: recaplong < file.txt"
    else
      _recap_msg -b "Only $words words found." "Copy the text first (Command + C), or give a file: recaplong < file.txt"
    fi
    rm -f "$tmp" "$out"; return 1
  fi

  _recap_ensure_ollama || { rm -f "$tmp" "$out"; return 1; }
  [[ -z "$RECAP_NO_LEAD" ]] && print -u2 ""
  local sumf; sumf=$(mktemp)
  _recap_long_core "$tmp" "$title" "$@" > "$sumf"
  {
    print -r -- "## $title"
    print ""
    _recap_src_line
    cat "$sumf"
  } | tee "$out"

  if ! _recap_has_summary "$out"; then
    _recap_msg "No summary was produced." "The model returned nothing, so nothing was saved. Run recapdoctor to check the setup, then try again."
    _RECAP_FIRST_MSG="No summary was produced."
    rm -f "$tmp" "$out" "$sumf"; return 1
  fi
  _recap_save "$out" "$title"
  _recap_notify "$t0" "Summary ready" "$title"
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
print("channel=" + re.sub(r"\s+", " ", channel).strip())
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
cands = []
for c in title_candidates():
    cands.append(c)
    if len(cands) == 3:
        break
title = cands[0] if cands else ""
# a running header that is only part of the next candidate (How Systems Fail / How Complex Systems Fail): take the longer one
if len(cands) > 1 and key(cands[0]) in repeated and set(cands[0].lower().split()) < set(cands[1].lower().split()):
    title = cands[1]
# a document code such as "IIMA/ BP0370" or "Q3 2026" is not a heading: the file name is better
if title and re.search(r"\d", title) and len(title.split()) <= 3 and not re.search(r"[a-z]{4,}", title):
    title = ""

# ---- author: only from an explicit line on page 1 ("by ...", "Prepared by ...", "Author: ..."); PDF metadata is not used
AUTH = re.compile(r"^(?:prepared by|written by|authored by|authors?\s*:|by)\s+(.+)$", re.I)
SPLIT = re.compile(r"[,;(]|\s+(?:at|of|from)\s+|(?<![A-Z])\.\s+(?=[A-Z])")
NAMEWORD = {"and", "&", "van", "de", "der", "von", "la", "bin", "al", "del", "da", "di"}
NOT_NAMES = {"the editors", "the editorial board", "the editorial team", "staff", "staff writer", "editors", "admin", "unknown", "anonymous"}
author = ""
for l in (page_lines[0][:25] if page_lines else []):
    m = AUTH.match(l.strip())
    if not m or len(l) > 160:
        continue
    cand = SPLIT.split(m.group(1))[0].strip(" .")
    ws = cand.split()
    if (1 <= len(ws) <= 8 and len(cand) <= 80 and not re.search(r"https?://|www\.|@|\d", cand)
            and all(w[:1].isupper() or w.lower() in NAMEWORD for w in ws) and cand.lower() not in NOT_NAMES):
        author = cand
        break

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
print("author=" + author)
PY
}

# --- web page: fetch, clean, summarize ------------------------------
# Exit codes of _recap_fetch: 2 no response, 3 no article text, 4 HTTP error (http=NNN), 8 it is a PDF,
# 5 redirected to a login page. Other lines on stdout: paywall=1  cutoff=1
_recap_fetch() {   # $1 = address, $2 = output file
  "$(_recap_py)" - "$1" "$2" <<'PY'
import re
import sys
import trafilatura
from trafilatura import downloads
from urllib.parse import urlsplit

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
site = ((getattr(meta, "sitename", "") if meta else "") or "").strip()
body = text.strip()
if title and not body.lower().startswith(title.lower()):
    body = title + "\n\n" + body
if author and author.lower() not in body[:400].lower():
    first, _, rest = body.partition("\n")
    body = first + "\n\nBy " + author + "\n" + rest
with open(out, "w", encoding="utf-8") as f:
    f.write(body.strip() + "\n")


def tidy_author(a):
    a = re.sub(r"\s+", " ", (a or "").replace(";", ",").replace("|", "/")).strip(" ,;|-")
    generic = {"admin", "administrator", "staff", "editor", "editors", "editorial", "team", "unknown",
               "anonymous", "guest", "author", "user", "webmaster", "news desk", "newsroom", "staff writer"}
    if not a or len(a) > 80 or a.lower() in generic or re.search(r"https?://|www\.|@|\d{3,}", a, re.I):
        return ""
    return a


host = re.sub(r"^www\.", "", urlsplit(final).hostname or "")
site = re.sub(r"\s+", " ", site.replace("|", "/"))
if not site or len(site) > 60:
    site = host
print("author=" + tidy_author(author))
print("site=" + site)

if re.search(r'"isAccessibleForFree"\s*:\s*"?false"?', html, re.I):
    print("paywall=1")
# A cut-off teaser: the text ends mid-sentence AND the page has subscription wording.
# (A missing final period alone is common on free pages, so it is not enough.)
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

_recap_is_addr() {   # is this argument an address, a PDF file or a folder, rather than a mode or focus text?
  local a="$1"
  [[ "$a" == "~/"* ]] && a="$HOME/${a:2}"
  [[ "$a" == http://* || "$a" == https://* || "$a" == www.* ]] && return 0
  [[ "${a:l}" == *.pdf && ( -f "$a" || "$a" == /* || "$a" == ./* || "$a" == ../* ) ]] && return 0
  [[ ( "$a" == /* || "$a" == ./* || "$a" == ../* || "$a" == . || "$a" == .. ) && -d "$a" ]] && return 0
  return 1
}

_recap_url_one() {   # one address (web page or YouTube video) + optional mode or focus text; returns 1 if nothing was summarized
  local rc=0 url="$1" tmp info code words title slug srcfile http_status final cutoff=0 paywall=0 src_note is_yt=0 yt_lang yt_gen=0 yt_en=1 min_words=150 is_pdf=0 local_pdf=0 pdf_pages pg=""
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
  if (( ! local_pdf )) && [[ "$url" == /* || "$url" == ./* || "$url" == ../* ]]; then
    if [[ -d "$url" ]]; then
      _recap_msg -b "That is a folder: $url" "Give recapurl the folder on its own and it summarizes the PDF files in it."
    elif [[ -e "$url" ]]; then
      _recap_msg -b "recapurl reads web addresses, YouTube links and PDF files." "For a text file use: recap < $url"
    else
      _recap_msg -b "File not found: $url"
    fi
    return 1
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
  local author site channel byline="" host
  author=$(print -r -- "$info" | sed -n 's/^author=//p' | head -1)
  site=$(print -r -- "$info" | sed -n 's/^site=//p' | head -1)
  channel=$(print -r -- "$info" | sed -n 's/^channel=//p' | head -1)

  if (( is_yt )); then
    case $code in
      0) ;;
      2) _recap_msg "Could not find a video in that link." "Nothing summarized." ;;
      3) _recap_msg "This video has no captions available." "The owner may have turned them off. recapurl cannot summarize a video without captions." "Nothing summarized." ;;
      4) _recap_msg "YouTube says the video is unavailable." "It may be private, removed, or not viewable in your region." "Nothing summarized." ;;
      5) _recap_msg "YouTube wants a sign-in or age check for this video." "Nothing summarized." ;;
      6) _recap_msg "YouTube blocked the request." "This sometimes clears after a while or on another network." "You can also open the video, choose Show transcript, copy the text and use recap." "Nothing summarized." ;;
      *) _recap_msg "Could not read the captions ($(print -r -- "$info" | sed -n 's/^error=//p' | head -1))." "Nothing summarized." ;;
    esac
    [[ $code != 0 ]] && { rm -f "$tmp"; return 1; }
  elif (( is_pdf )); then
    case $code in
      0) ;;
      2) if (( local_pdf )); then _recap_msg "Could not read that file." "Nothing summarized."
         else _recap_msg "No response from the site." "Possible causes: a network, security-certificate or timeout problem." "Nothing summarized."; fi ;;
      3) _recap_msg "No readable text in this PDF$pg." "It is probably scanned pages, which are images. recapurl cannot read those." "Nothing summarized." ;;
      4) case "$http_status" in
           401|403|429) _recap_msg "The site answered with HTTP $http_status instead of the PDF." "That usually means it blocks automated downloads or needs a login." "Download the file in your browser and run recapurl on the saved file." ;;
           404|410) _recap_msg "The site answered with HTTP $http_status instead of the PDF." "That usually means the address is wrong or the file was removed." ;;
           *) _recap_msg "The site answered with HTTP $http_status instead of the PDF." "Try again later, or download it in your browser and run recapurl on the saved file." ;;
         esac ;;
      5) _recap_msg "This PDF is password-protected." "Nothing summarized." ;;
      6) _recap_msg "That PDF is larger than ${RECAP_PDF_MAX_MB:-30} MB." "Nothing summarized. To raise the limit:" "  RECAP_PDF_MAX_MB=60 recapurl \"$url\"" ;;
      9) _recap_msg "That link did not return a PDF." "It may be a web page or a login page." "Nothing summarized." ;;
      *) if [[ "$info" == *error=DependencyError* ]]; then
           _recap_msg "This PDF is encrypted in a way the basic PDF reader cannot open." "Run this, then try again:" "  recapsetup"
         else
           _recap_msg "Could not read the PDF ($(print -r -- "$info" | sed -n 's/^error=//p' | head -1))." "The file may be damaged. Nothing summarized."
         fi ;;
    esac
    [[ $code != 0 ]] && { rm -f "$tmp"; return 1; }
  else
  case $code in
    0) ;;
    2) _recap_msg "No response from the site." "Possible causes: a network, security-certificate or timeout problem." "Nothing summarized."
       rm -f "$tmp"; return 1 ;;
    4) case "$http_status" in
         401|403|429) _recap_msg "The site answered with HTTP $http_status instead of the page." "That usually means it blocks automated downloads or needs a login." "Copy the text and use recap." ;;
         404|410) _recap_msg "The site answered with HTTP $http_status instead of the page." "That usually means the address is wrong or the page was removed." ;;
         *) _recap_msg "The site answered with HTTP $http_status instead of the page." "Try again later, or copy the text and use recap." ;;
       esac
       rm -f "$tmp"; return 1 ;;
    5) _recap_msg "The site redirected to a login or subscribe page." "  $final" "Nothing summarized."
       rm -f "$tmp"; return 1 ;;
    3) _recap_msg "No article text found on that page." "It may need a login or be built with scripts." "Nothing summarized."
       rm -f "$tmp"; return 1 ;;
    *) _recap_msg "Could not read the page (error $code)." "Nothing summarized."
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
        _recap_msg "Only $words words of captions came back." "The video may be very short or mostly music." "Nothing summarized."
      elif (( is_pdf )); then
        _recap_msg "Only $words words of text came back." "The PDF may be mostly images or very short." "Nothing summarized."
      else
        _recap_msg "Only $words words came back." "The page may be paywalled, need a login or be mostly scripts." "Nothing summarized."
      fi
      _recap_msg "Extracted text saved so you can look:" "  $srcfile"
      rm -f "$tmp"; return 1
    fi
    if (( words > ${RECAP_URL_MAX:-10000} )); then
      _recap_msg "That is $words words: too long to summarize reliably in one go." "The part-by-part method is only tested up to about 6,600 words, and past roughly 10,000 words its notes probably no longer fit in the model's memory."
      _recap_msg "Text saved so you can copy one chapter or section and use recaplong:" "  $srcfile"
      _recap_msg "To try the whole text anyway, run:" "  RECAP_URL_MAX=$((words + 1000)) recapurl \"$url\""
      rm -f "$tmp"; return 1
    fi
    if (( paywall )); then
      _recap_msg "Stopped: the page marks its article as paywalled (members only)." "What came back is probably a teaser or a subscription notice." "Nothing summarized."
      _recap_msg "Extracted text saved so you can look:" "  $srcfile"
      _recap_msg "To summarize it anyway, run:" "  RECAP_URL_FORCE=1 recapurl \"$url\""
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

  host="${${url#*://}%%[/?#]*}"; host="${host#www.}"
  if (( is_yt )); then
    byline="Site: youtube.com"; [[ -n "$channel" ]] && byline="Channel: $channel | $byline"
  elif (( local_pdf )); then
    byline="File: ${url:t}"; [[ -n "$author" ]] && byline="Author: $author | $byline"
  else
    byline="Site: ${site:-$host}"; [[ -n "$author" ]] && byline="Author: $author | $byline"
  fi

  if (( words > ${RECAP_LONG_WORDS:-4000} )); then
    case "$1" in
      short|changes)
        _recap_msg "'$1' only applies under ${RECAP_LONG_WORDS:-4000} words." "Summarizing in parts without it."
        shift ;;
    esac
    RECAP_NO_LEAD=1 RECAP_QUIET_DONE=1 RECAP_BYLINE="$byline" RECAP_INPUT="$tmp" RECAP_SOURCE="$src_note" recaplong "$@" || rc=$?
  else
    RECAP_NO_LEAD=1 RECAP_QUIET_DONE=1 RECAP_BYLINE="$byline" RECAP_INPUT="$tmp" RECAP_SOURCE="$src_note" recap "$@" || rc=$?
  fi
  rm -f "$tmp"
  return $rc
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
  local -a urls keys cleans skipped failed reasons lines seen_lines expanded pdfs kc reused
  local i=0 ok=0 rc=0 j u c k line d rest total mode="" coll="" final="" again=0 t0=$SECONDS folder_used=0 ans saved_file saved_date uniq_seen="" flag=""
  while [[ "$1" == --single || "$1" == --separate || "$1" == --again || "$1" == --notify ]]; do
    case "$1" in
      --single|--separate) mode="${1#--}" ;;
      --again) again=1 ;;
      --notify) local RECAP_NOTIFY=1 ;;
    esac
    shift
  done
  if [[ -z "$1" || "$1" == help || "$1" == -h || "$1" == --help ]]; then
    _recap_msg -b "Usage: recapurl [--single | --separate] [--again] [--notify] \"ADDRESS\" [\"ADDRESS\" ...] [short | changes | \"focus text\"]" "Put each address in quotes (addresses with ? or & break otherwise)."
    _recap_msg "Fetches a web article, strips menus and ads, and summarizes it. For a YouTube video it reads the captions." "A PDF (an address or a file on this Mac) is read too. A folder gives every PDF in it. Not for other audio or video." "Several are summarized one after another; extra ones must start with https:// or www., or be a PDF file or a folder." "Duplicate addresses are skipped. The page's author and site are shown under the heading when they can be found." "An address you summarized before is not summarized again: the saved summary is shown (add --again to redo it)." "For several addresses, --single saves all summaries in one file and --separate gives each its own." "Without a flag it asks (or set RECAP_BATCH=single or separate). With --notify (or RECAP_NOTIFY=1) a long run ends with a notification and a sound." "The flags can come before or after the addresses." "To skip the paywall and short-text checks:" "  RECAP_URL_FORCE=1 recapurl \"ADDRESS\""
    [[ -z "$1" ]] && return 1
    return 0
  fi
  if [[ "$1" == --* ]]; then
    _recap_msg -b "Unknown option: $1" "Options: --single, --separate, --again, --notify."
    return 1
  fi
  _recap_ensure_ollama || return 1
  urls=("$1"); shift
  while [[ -n "$1" ]] && _recap_is_addr "$1"; do urls+=("$1"); shift; done
  while [[ "$1" == --single || "$1" == --separate || "$1" == --again || "$1" == --notify ]]; do   # flags may follow the addresses too
    case "$1" in
      --single|--separate) mode="${1#--}" ;;
      --again) again=1 ;;
      --notify) local RECAP_NOTIFY=1 ;;
    esac
    shift
  done

  # a folder stands for the PDF files inside it
  for u in "${urls[@]}"; do
    d="$u"; [[ "$d" == "~/"* ]] && d="$HOME/${d:2}"
    if [[ "$u" != http://* && "$u" != https://* && -d "$d" ]]; then
      pdfs=("$d"/*.[pP][dD][fF](N.on))
      if (( ${#pdfs} == 0 )); then
        _recap_msg -b "No PDF files in that folder:" "  $u"
        continue
      fi
      folder_used=1
      _recap_msg -b "Found ${#pdfs} PDF file(s) in:" "  $u"
      expanded+=("${pdfs[@]}")
    else
      expanded+=("$u")
    fi
  done
  urls=("${expanded[@]}")
  (( ${#urls} )) || return 1
  if (( folder_used && ${#urls} > ${_RECAP_FOLDER_ASK:-10} )) && [[ -t 0 && -t 2 ]]; then
    read -k 1 "ans?Summarize all ${#urls} files? Each one can take a minute or more. [y/N] "
    print -u2 ""
    [[ "$ans" == [yY] ]] || { _recap_msg -b "Stopped. Nothing summarized."; return 1; }
  fi

  # clean the addresses and skip duplicates (the same page with tracking junk, a trailing slash, www., youtu.be ...)
  kc=(${(f)"$(_recap_urltool keys "${urls[@]}" 2>/dev/null)"})
  if (( ${#kc} == ${#urls} )); then
    for ((j=1; j<=${#urls}; j++)); do
      line="${kc[j]}"; k="${line%%$'\t'*}"; c="${line#*$'\t'}"
      if [[ $'\n'"$uniq_seen"$'\n' == *$'\n'"$k"$'\n'* ]]; then
        skipped+=("${urls[j]}")
      else
        uniq_seen+="$k"$'\n'; keys+=("$k"); cleans+=("$c")
      fi
    done
  else
    cleans=("${urls[@]}")
  fi
  (( ${#skipped} )) && _recap_msg -b "Skipped ${#skipped} duplicate address(es):" "${(@)skipped/#/  }"
  total=${#cleans}

  # addresses already summarized earlier (only for a plain summary: a mode or focus text asks for something different)
  if (( ! again && $# == 0 && ${#keys} )); then
    seen_lines=(${(f)"$(_recap_urltool seen "$RECAP_DIR" "${keys[@]}" 2>/dev/null)"})
  fi

  if (( total > 1 )); then
    mode=$(_recap_batch_mode "$mode")
    if [[ "$mode" == single ]]; then
      coll=$(mktemp)
      _recap_msg -b "Saving all summaries in one combined file."
    else
      _recap_msg -b "Saving one file per address."
    fi
  fi

  for ((i=1; i<=total; i++)); do
    u="${cleans[i]}"
    (( total > 1 )) && _recap_msg -b "Link $i of $total"
    saved_file=""; saved_date=""
    if (( ${#keys} && ${#seen_lines} )); then
      for line in "${seen_lines[@]}"; do
        if [[ "${line%%$'\t'*}" == "${keys[i]}" ]]; then
          rest="${line#*$'\t'}"; saved_file="${rest%%$'\t'*}"; saved_date="${rest#*$'\t'}"
          break
        fi
      done
    fi
    if [[ -n "$saved_file" ]]; then
      if [[ "${saved_file:t}" == *batch-of-* ]]; then
        _recap_msg -b "Already summarized on $saved_date, as part of a combined file:" "  ${saved_file/#$HOME/~}" "To summarize it again, add --again."
      else
        _recap_msg -b "Already summarized on $saved_date:" "  ${saved_file/#$HOME/~}" "Showing the saved summary. To summarize it again, add --again."
        cat "$saved_file"
        if [[ -n "$coll" ]]; then
          [[ -s "$coll" ]] && { print -r -- "---"; print ""; } >> "$coll"
          cat "$saved_file" >> "$coll"
        fi
      fi
      reused+=("$u"); ok=$((ok+1))
      continue
    fi
    if (( total > 1 )); then
      if RECAP_COLLECT="$coll" RECAP_NO_LEAD=1 RECAP_QUIET_DONE=1 _recap_url_one "$u" "$@"; then
        ok=$((ok+1))
      else
        failed+=("$u"); reasons+=("$_RECAP_FIRST_MSG")
      fi
    else
      RECAP_QUIET_DONE=1 _recap_url_one "$u" "$@"; rc=$?
    fi
  done

  if (( total == 1 )); then
    (( ${#reused} )) && rc=0
    (( rc == 0 )) || flag=issues
    _recap_notify "$t0" "$( (( rc == 0 )) && print 'Summary ready' || print 'Finished with issues' )" "recapurl" "$flag"
    return $rc
  fi

  if [[ -n "$coll" ]]; then
    if (( ok > 0 )); then
      final=$(mktemp)
      {
        print -r -- "# $ok link summaries, $(date +%Y-%m-%d)"; print ""
        cat "$coll"
        if (( ${#failed} )); then
          print ""; print -r -- "## Not summarized"; print ""
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
    _recap_msg -b "Finished: $ok of $total summarized." "Not summarized:" "${lines[@]}"
    flag=issues
  else
    _recap_msg -b "Finished: all $total summarized."
  fi
  (( ${#reused} )) && _recap_msg "${#reused} of them were already summarized earlier, so the saved summaries were shown."
  _recap_notify "$t0" "$ok of $total done" "recapurl" "$flag"
  (( ${#failed} == 0 ))
}

# recapurls [--single | --separate] ["ADDRESS" ...] ["focus text"]: summarize the addresses typed after it, or, with none,
# every web address found on the clipboard (one per line, anything else is ignored)
recapurls() {
  local -a urls flags
  while [[ "$1" == --single || "$1" == --separate || "$1" == --again || "$1" == --notify ]]; do flags+=("$1"); shift; done
  if [[ -n "$1" ]] && _recap_is_addr "$1"; then   # addresses typed after the command: same as recapurl
    recapurl "${flags[@]}" "$@"
    return $?
  fi
  urls=(${(f)"$(_recap_input | tr -d '\r' | grep -Eo 'https?://[^[:space:]]+' | awk '{ u = $0; while (u != "") { c = substr(u, length(u), 1); if (c ~ /[.,;:>!?]/) { u = substr(u, 1, length(u) - 1) } else if (c == ")" && gsub(/\(/, "(", u) < gsub(/\)/, ")", u)) { u = substr(u, 1, length(u) - 1) } else break } if (u != "" && !seen[u]++) print u }')"})
  if (( ${#urls} == 0 )); then
    _recap_msg -b "No web addresses found on the clipboard." "Copy the addresses first, one per line, each starting with http:// or https://."
    return 1
  fi
  _recap_msg -b "Found ${#urls} address(es) on the clipboard:" "${(@)urls/#/  }"
  recapurl "${flags[@]}" "${urls[@]}" "$@"
}

# --- Ollama: start it when it is not running ---------------------------
recapfind() {   # search the saved summaries: every word must appear; capital letters do not matter
  local dir="$RECAP_DIR" max=20 sources=0 w f d h n=0 shown=0
  local -a words files
  while [[ "$1" == --* ]]; do
    case "$1" in
      --sources) sources=1 ;;
      --max) max="$2"; shift ;;
      --help) set --; break ;;
      *) _recap_msg -b "Unknown option: $1" "Options: --max N, --sources."; return 1 ;;
    esac
    shift
  done
  [[ "$1" == help || "$1" == -h ]] && set --
  words=("$@")
  if (( ${#words} == 0 )); then
    _recap_msg -b "Usage: recapfind [--max N] [--sources] word [word ...]" "Searches your saved summaries in ${dir/#$HOME/~}. Every word must appear; capital letters do not matter." "--sources also searches the saved source texts and notes. Newest first, 20 at most (see --max)."
    return 1
  fi
  [[ "$max" == <-> ]] || max=20
  [[ -d "$dir" ]] || { _recap_msg -b "There is no summaries folder yet: ${dir/#$HOME/~}"; return 1; }
  files=("$dir"/*(.N.om))
  if (( sources )); then files=(${(M)files:#(*.md|*-source.txt|*-notes.txt)}); else files=(${(M)files:#*.md}); fi
  for w in "${words[@]}"; do
    (( ${#files} )) || break
    files=(${(f)"$(grep -l -i -F -- "$w" "${files[@]}" 2>/dev/null)"})
  done
  n=${#files}
  if (( n == 0 )); then
    _recap_msg -b "Nothing found for: ${words[*]}"
    return 1
  fi
  for f in "${files[@]}"; do
    (( shown >= max )) && break
    shown=$((shown+1))
    d="${${f:t}[1,10]}"
    h=$(grep -m1 -E '^#{1,2} ' "$f" 2>/dev/null | sed -E 's/^#+ +//')
    [[ -z "$h" ]] && h=$(grep -m1 -v '^[[:space:]]*$' "$f" 2>/dev/null | cut -c1-90)
    print -r -- "$d  $h"
    print -r -- "  ${f/#$HOME/~}"
    grep -v -E '^(#|Source:|Author:|Channel:|Site:|[[:space:]]*$)' "$f" 2>/dev/null | grep -i -F -m2 -- "${words[1]}" | cut -c1-150 | sed 's/^/    | /'
    print ""
  done
  (( n > shown )) && print -r -- "$((n - shown)) more not shown. Use --max N to see more."
  print -r -- "$n file(s) matched."
}

_recap_ensure_ollama() {   # makes sure the Ollama server is running, and starts it if it is not
  command -v ollama >/dev/null 2>&1 || {
    _recap_msg -b "Ollama is not installed." "Install it from https://ollama.com (download it and open the app), then try again."
    return 1
  }
  ollama list >/dev/null 2>&1 && return 0
  local i
  _recap_msg -b "Ollama is not running. Starting it now..." "This can take a few seconds."
  if [[ -d /Applications/Ollama.app || -d "$HOME/Applications/Ollama.app" ]] && open -g -j -a Ollama >/dev/null 2>&1; then
    :   # the Ollama app starts the server in the background (-j launches it hidden)
  else
    nohup ollama serve >/dev/null 2>&1 &!
  fi
  for ((i = 0; i < ${_RECAP_OLLAMA_WAIT:-30}; i++)); do
    sleep 1
    if ollama list >/dev/null 2>&1; then
      _recap_msg "Ollama is running."
      return 0
    fi
  done
  _recap_msg "Ollama did not start in time." "Open the Ollama app (or run: ollama serve in another Terminal window), wait a few seconds, then try again."
  return 1
}

_recap_has_summary() {   # does the saved text hold more than the heading and the Source line?
  grep -v -E '^(## |Source:|Author:|Channel:|Site:|[[:space:]]*$)' "$1" | grep -q .
}

# --- Python environment and model: setup and health check ------------
_recap_model_installed() {   # $1 = model name, $2 = the output of `ollama list`. A name without a tag also matches :latest
  local want="$1"
  [[ "$want" == *:* ]] || want="${want}:latest"
  print -r -- "$2" | awk 'NR>1 {print $1}' | grep -qx -- "$want"
}

# recapsetup: one command to get everything ready. It creates (or updates) Recap's private Python environment in
# $RECAP_HOME/venv for the address commands, and builds the summarizing model in Ollama if it is missing.
# Your own Python is not touched. Run it again to upgrade the packages. recapsetup --no-model skips the model.
recapsetup() {
  local base="${RECAP_BASE_PYTHON:-python3}" venv="$RECAP_HOME/venv" out ver list modelfile
  local no_model=0 todo=""
  [[ "$1" == --no-model ]] && no_model=1
  if ! command -v "$base" >/dev/null 2>&1; then
    _recap_msg -b "Python 3 was not found ($base)." "Install it from python.org or with Homebrew (brew install python), then run recapsetup again."
    return 1
  fi
  ver=$("$base" -c 'import sys; print(sys.version.split()[0])' 2>/dev/null)
  if [[ -z "$ver" ]]; then
    _recap_msg -b "Python 3 could not be run." "If macOS opened a window offering to install the command line developer tools, click Install, wait until it finishes, then run recapsetup again." "Otherwise install Python 3.9 or newer from python.org."
    return 1
  fi
  if ! "$base" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' 2>/dev/null; then
    _recap_msg -b "Python $ver is too old: Recap needs Python 3.9 or newer." "Install a newer Python, then run:" "  RECAP_BASE_PYTHON=/path/to/python3 recapsetup"
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
  _recap_msg "The Python packages are ready."

  # the summarizing model (one model does every job)
  if (( no_model )); then
    :
  elif ! command -v ollama >/dev/null 2>&1; then
    _recap_msg "Ollama is not installed, so the summarizing model was not set up." "Install it from https://ollama.com (download it and open the app), then run recapsetup again."
    todo="install Ollama, then run recapsetup again"
  elif ! _recap_ensure_ollama; then
    todo="start Ollama, then run recapsetup again"
  elif list=$(ollama list 2>/dev/null) && _recap_model_installed "$RECAP_MODEL_DEFAULT" "$list"; then
    _recap_msg "The summarizing model ($RECAP_MODEL_DEFAULT) is already set up."
  else
    _recap_msg "Setting up the summarizing model." "This downloads about 4.6 GB, once. Keep the Mac awake and connected to the internet." "Press Control+C to cancel; running recapsetup again resumes."
    if ! ollama pull gemma4:e2b; then
      _recap_msg "The model download failed." "Check your internet connection, then run recapsetup again."
      return 1
    fi
    modelfile=$(mktemp)
    printf 'FROM gemma4:e2b\nPARAMETER num_ctx 12288\nPARAMETER temperature 0.2\n' > "$modelfile"
    if ! ollama create "$RECAP_MODEL_DEFAULT" -f "$modelfile" >/dev/null 2>&1; then
      rm -f "$modelfile"
      _recap_msg "The model was downloaded but could not be set up." "Run recapdoctor and send its output with a bug report."
      return 1
    fi
    rm -f "$modelfile"
    _recap_msg "The summarizing model ($RECAP_MODEL_DEFAULT) is ready."
  fi

  if [[ -n "$todo" ]]; then
    _recap_msg "Almost done. Still to do: $todo."
  else
    _recap_msg "Setup is complete." "To check everything, run:" "  recapdoctor"
  fi
}

# recapdoctor: check the whole setup and say what to fix. Safe to paste into a bug report.
recapdoctor() {
  local problems=0 pyproblems=0 py list m pyout line
  local default_model="${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}"
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
      if _recap_model_installed "$default_model" "$list"; then
        print "  ok       model $default_model is installed (the default)"
      else
        print "  PROBLEM  model $default_model is not installed. Build it with the ollama create commands in the README."; problems=$((problems+1))
      fi
      if _recap_model_installed gemma-sum "$list"; then print "  ok       optional model gemma-sum is installed (second opinion)"
      else print "  optional model gemma-sum is not installed (only needed for a second opinion)"; fi
      if [[ -n "$RECAP_MAIL_MODEL" && "$RECAP_MAIL_MODEL" != "$default_model" ]]; then
        if _recap_model_installed "$RECAP_MAIL_MODEL" "$list"; then print "  ok       recapmail model $RECAP_MAIL_MODEL is installed"
        else print "  PROBLEM  recapmail model $RECAP_MAIL_MODEL (RECAP_MAIL_MODEL) is not installed"; problems=$((problems+1)); fi
      fi
    else
      print "  PROBLEM  Ollama is installed but not running. Recap commands start it automatically; you can also open the Ollama app, or run: ollama serve"; problems=$((problems+1))
    fi
  fi
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
  local model="${RECAP_MAIL_MODEL:-${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}}"
  local -a tf
  _recap_ensure_ollama || return 1
  tf=(${=$(_recap_flags "$model")})
  _recap_input | tr -d '\r' | ollama run --nowordwrap "${tf[@]}" "$model" \
"Summarize the email below in 3 lines. Then list: who sent it and what they want from me, any tasks or deadlines, and whether a reply is needed. If there are no tasks or deadlines, write None. Use only facts in the email. Do not ask me questions."
}
