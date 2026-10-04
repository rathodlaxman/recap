# ============================================================
#  Recap - offline article summariser  (Ollama + Gemma 4)
#  Add this block to ~/.zshrc, then run:  source ~/.zshrc
#  Commands:  recap | recap short | recap changes | recaplong
#             recapall | recapc | recapmail | recap help
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
  RECAP_MODEL=gemma-sum recap    use a different model for one run
  Summaries are saved as Markdown in ~/Summaries
EOT
      return ;;
    "") ;;
    *) extra="Special focus for this summary: $*" ;;
  esac

  tmp=$(mktemp)
  pbpaste | tr -d '\r' > "$tmp"
  words=$(wc -w < "$tmp" | tr -d ' ')
  title=$(_recap_title "$tmp")

  if (( words < 20 )); then
    echo "Only $words words on the clipboard. Copy the article first." >&2
    rm -f "$tmp"; return 1
  fi

  echo "Reading $words words with $model. Options: short | changes | help | or your own focus in quotes" >&2
  if (( words > 4000 )); then
    echo "Note: $words words is long for one pass. Accuracy drops above about 2,500 words - consider recaplong." >&2
  elif (( words > 2500 )); then
    echo "Note: over 2,500 words. recaplong will be more accurate if this matters." >&2
  fi

  local out
  out=$(mktemp)
  {
    print -r -- "## $title"
    print ""
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
  echo "Saved: $file" >&2
}

alias recapc='recap | tee >(pbcopy)'

# --- several articles ----------------------------------------------
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
    echo "Nothing found on the clipboard." >&2; rm -rf "$tmp" "$out"; return 1
  fi
  (( n == 1 )) && echo "Only one article found. Put @@@@ alone on a line between articles." >&2

  for f in $parts; do
    words=$(wc -w < "$f" | tr -d ' ')
    (( words < 30 )) && continue
    i=$((i+1))
    title=$(_recap_title "$f")
    echo "Article $i of $n - $words words" >&2
    {
      print -r -- "## $title"
      print ""
      ollama run --nowordwrap ${=$(_recap_flags "${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}")} \
        "${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}" "$(_recap_prompt) $*" < "$f" | _recap_clean
      print ""
    } | tee -a "$out"
  done

  pbcopy < "$out"
  _recap_save "$out" "batch-of-$i-articles"
  rm -rf "$tmp"; rm -f "$out"
  echo "Done. All summaries are also on your clipboard." >&2
}

# --- long article or transcript (reads it in parts) -----------------
recaplong() {
  local tmp notes out f i=0 n words title chunk model
  model="${RECAP_MODEL:-$RECAP_MODEL_DEFAULT}"
  local -a tf parts
  tf=(${=$(_recap_flags "$model")})
  tmp=$(mktemp -d); notes=$(mktemp); out=$(mktemp)

  pbpaste | tr -d '\r' > "$tmp/full.txt"
  words=$(wc -w < "$tmp/full.txt" | tr -d ' ')
  title=$(_recap_title "$tmp/full.txt")

  if (( words < 20 )); then
    echo "Only $words words on the clipboard. Copy the text first." >&2
    rm -rf "$tmp"; rm -f "$notes" "$out"; return 1
  fi

  awk -v d="$tmp" -v max="${RECAP_CHUNK:-1200}" '
    BEGIN{n=1; c=0}
    { if (c + NF > max && c > 0) { n++; c=0 }
      print > sprintf("%s/chunk_%03d.txt", d, n); c += NF }' "$tmp/full.txt"

  parts=("$tmp"/chunk_*.txt(N))
  n=${#parts}
  echo "Reading $words words in $n parts with $model. This takes roughly $((n*45)) seconds." >&2

  for f in $parts; do
    i=$((i+1))
    echo "  part $i of $n..." >&2
    print -r -- "--- Part $i ---" >> "$notes"
    ollama run --nowordwrap "${tf[@]}" "$model" \
"This is one part of a longer document. List everything it contains as short bullets: the facts, figures, names, dates, claims, arguments and quotes. Say exactly who said or did each thing. Keep names and numbers exactly as written and keep hedges such as 'possibly' or 'the best explanation is'. Do not summarise, shorten or add anything, and write no introduction." \
      < "$f" >> "$notes"
    print "" >> "$notes"
  done

  echo "  combining..." >&2
  {
    print -r -- "## $title"
    print ""
    ollama run --nowordwrap "${tf[@]}" "$model" \
      "$(_recap_prompt) The text below is a set of notes taken in order from a longer document, not the document itself. Summarise what the document says. $*" \
      < "$notes" | _recap_clean
  } | tee "$out"

  _recap_save "$out" "$title"
  cp "$notes" "$RECAP_DIR/$(date +%Y-%m-%d)-$(_recap_slug "$title")-notes.txt"
  rm -rf "$tmp"; rm -f "$notes" "$out"
}

# --- email ----------------------------------------------------------
recapmail() {
  pbpaste | tr -d '\r' | ollama run --nowordwrap llama3.2:3b \
"Summarise the email below in 3 lines. Then list: who sent it and what they want from me, any tasks or deadlines, and whether a reply is needed. If there are no tasks or deadlines, write None. Use only facts in the email. Do not ask me questions."
}
