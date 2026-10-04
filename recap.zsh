# ============================================================
#  Recap - offline article summariser  (Ollama + Gemma 4)
#  Add this block to ~/.zshrc, then run:  source ~/.zshrc
#  Commands:  recap | recap short | recap changes | recaplong
#             recapall | recapc | recapmail | recapurl | recap help
# ============================================================

RECAP_DIR="${RECAP_DIR:-$HOME/Summaries}"
RECAP_MODEL_DEFAULT="gemma4-sum"

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
  print -u2 -rl -- "$@"
  print -u2 ""
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
  recapurl "ADDRESS"  fetch a web article and summarise it (quote the address; not video, audio or PDF)
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

# --- web page: fetch, clean, summarise ------------------------------
# Exit codes of _recap_fetch: 2 no response, 3 no article text, 4 HTTP error (http=NNN),
# 5 redirected to a login page. Other lines on stdout: paywall=1  cutoff=1
_recap_fetch() {   # $1 = address, $2 = output file
  python3 - "$1" "$2" <<'PY'
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
recapurl() {
  local url="$1" tmp info code words title slug srcfile http_status final cutoff=0 paywall=0 src_note
  if [[ -z "$url" || "$url" == help || "$url" == -h || "$url" == --help ]]; then
    _recap_msg -b "Usage: recapurl \"ADDRESS\" [short | changes | \"focus text\"]" "Put the address in quotes (addresses with ? or & break otherwise)."
    _recap_msg "Fetches a web article, strips menus and ads, and summarises it." "Not for video, audio or PDF." "To skip the paywall and short-text checks:" "  RECAP_URL_FORCE=1 recapurl \"ADDRESS\""
    [[ -z "$url" ]] && return 1
    return 0
  fi
  shift
  [[ "$url" == http://* || "$url" == https://* ]] || url="https://$url"

  case "${url:l}" in
    *youtube.com/*|*youtu.be/*|*vimeo.com/*|*spotify.com/*|*podcasts.apple.com/*|*soundcloud.com/*|*.mp3|*.mp4|*.m4a|*.wav|*.mov|*.webm)
      _recap_msg -b "That looks like a video or audio link." "recapurl reads web articles only."
      return 1 ;;
    *.pdf)
      _recap_msg -b "That looks like a PDF." "recapurl reads web pages only. Copy the text and use recap."
      return 1 ;;
  esac

  python3 -c 'import trafilatura' 2>/dev/null || {
    _recap_msg -b "trafilatura is not installed." "Run this, then try again:" "  python3 -m pip install trafilatura"
    return 1
  }

  tmp=$(mktemp)
  _recap_msg -b "Fetching:" "  $url"
  info=$(_recap_fetch "$url" "$tmp"); code=$?
  http_status=$(print -r -- "$info" | sed -n 's/^http=//p' | head -1)
  final=$(print -r -- "$info" | sed -n 's/^final=//p' | head -1)
  [[ "$info" == *cutoff=1* ]] && cutoff=1
  [[ "$info" == *paywall=1* ]] && paywall=1

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
    5) _recap_msg "The site redirected to a login or subscribe page:" "  $final" "Nothing summarised."
       rm -f "$tmp"; return 1 ;;
    3) _recap_msg "No article text found on that page." "It may need a login or be built with scripts." "Nothing summarised."
       rm -f "$tmp"; return 1 ;;
    *) _recap_msg "Could not read the page (error $code)." "Nothing summarised."
       rm -f "$tmp"; return 1 ;;
  esac

  words=$(wc -w < "$tmp" | tr -d ' ')
  title=$(_recap_title "$tmp")
  slug=$(_recap_slug "$title"); [[ -z "$slug" ]] && slug="page"
  mkdir -p "$RECAP_DIR"
  srcfile="$RECAP_DIR/$(date +%Y-%m-%d)-$slug-source.txt"
  { print -r -- "Source: $url"; print ""; cat "$tmp"; } > "$srcfile"

  if [[ "$RECAP_URL_FORCE" != 1 ]]; then
    if (( words < ${RECAP_URL_MIN:-150} )); then
      _recap_msg "Only $words words came back." "The page may be paywalled, need a login or be mostly scripts." "Nothing summarised."
      _recap_msg "Extracted text saved so you can look:" "  $srcfile"
      rm -f "$tmp"; return 1
    fi
    if (( paywall )); then
      _recap_msg "Stopped: the page marks its article as paywalled (members only)." "What came back is probably a teaser or a subscription notice." "Nothing summarised."
      _recap_msg "Extracted text saved so you can look:" "  $srcfile"
      _recap_msg "To summarise it anyway, run:" "  RECAP_URL_FORCE=1 recapurl \"$url\""
      rm -f "$tmp"; return 1
    fi
  fi
  _recap_msg "Fetched $words words." "Extracted text saved to:" "  $srcfile"
  _recap_msg "Text starts:" "  $(head -c 160 "$tmp" | tr '\n' ' ')"

  src_note="$url"
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
}

# --- email ----------------------------------------------------------
recapmail() {
  pbpaste | tr -d '\r' | ollama run --nowordwrap llama3.2:3b \
"Summarise the email below in 3 lines. Then list: who sent it and what they want from me, any tasks or deadlines, and whether a reply is needed. If there are no tasks or deadlines, write None. Use only facts in the email. Do not ask me questions."
}
