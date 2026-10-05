# Recap

A local article summariser for macOS. Copy an article (or give a web address, a YouTube link or a PDF), type one word, read the gist.

Everything is summarised on the machine through [Ollama](https://ollama.com), so no article text is sent to any AI service. The clipboard commands (`recap`, `recaplong`, `recapall`, `recapmail`) work without a network connection. The address commands (`recapurl`, `recapurls`) need one to fetch a web page, a YouTube video's captions or a PDF at an address. A PDF file already on the Mac is read offline. Built and tuned on a MacBook Air M1 with 8 GB of RAM.

## What it does

| Command | What it does |
| --- | --- |
| `recap` | Adaptive summary of whatever is on the clipboard: gist, main points, and "Worth noting" only if there is more |
| `recap short` | One sentence plus up to three takeaways |
| `recap changes` | For circulars and rule changes: which clauses are new, which are unchanged, who acts and from when |
| `recap "focus on costs"` | Summary with a focus you choose |
| `recaplong` | Long articles and transcripts: reads the text in parts, then combines. Slower but far more accurate |
| `recapall` | Several articles in one run, separated by lines containing only `@@@@`. An article over 4,000 words is read in parts automatically |
| `recapc` | Same as `recap`, and also copies the summary to the clipboard |
| `recapmail` | Short email summary: sender, tasks, deadlines, whether a reply is needed |
| `recapurl "ADDRESS"` | Fetches a web article, the captions of a YouTube video, or a PDF (an address or a file on the Mac), and summarises it |
| `recapurl "A" "B"` | Several addresses or PDF files in one run. `--single` saves one combined file, `--separate` one file each |
| `recapurls` | Summarises every web address on the clipboard, one per line (same flags) |
| `recap help` | Lists the options |

Every summary is written as Markdown to `~/Summaries/YYYY-MM-DD-title.md` and printed on screen.

## Setup

Install Ollama, then build the model:

```sh
ollama pull gemma4:e2b
printf 'FROM gemma4:e2b\nPARAMETER num_ctx 12288\nPARAMETER temperature 0.2\n' > ~/Modelfile.g4
ollama create gemma4-sum -f ~/Modelfile.g4
```

Load the functions from `~/.zshrc` with one `source` line (run this in the repository folder):

```sh
echo "source $PWD/recap.zsh" >> ~/.zshrc
source ~/.zshrc
recap help
```

Use a `source` line and not a pasted copy: with two copies of a function, the old one can keep running.

`recapmail` additionally needs `ollama pull llama3.2:3b`.

`recapurl` and `recapurls` need three Python packages:

```sh
python3 -m pip install trafilatura youtube-transcript-api pypdfium2
```

`pypdfium2` reads PDFs. If it is missing but `pypdf` is installed, `recapurl` falls back to `pypdf` and says so. `pypdf` can garble page headers and small capitals.

## Web pages, YouTube and PDFs

```sh
recapurl "https://example.com/article"
recapurl "https://www.youtube.com/watch?v=VIDEOID"
recapurl "https://example.com/paper.pdf"
recapurl ~/Downloads/paper.pdf
recapurl "https://example.com/article" "focus on costs"
recapurl --single "https://example.com/one" "https://example.com/two"
recapurls
```

Put every address in double quotes. Addresses containing `?` or `&` break otherwise.

- **Web pages.** Menus, ads and comments are stripped (trafilatura), and the headline and byline are added. A page over 4,000 words is read in parts, the way `recaplong` does it. `short` and `changes` apply only below that length.
- **Length limit.** Above 10,000 words `recapurl` stops (web page, YouTube transcript or PDF), saves the text, and suggests copying one chapter or section and using `recaplong`. The part-by-part method has been tested only up to about 6,600 words, and past roughly 10,000 words its combined notes probably no longer fit in the model's memory. `RECAP_URL_MAX=20000 recapurl "ADDRESS"` raises the limit for one run.
- **YouTube.** The captions are read: English captions uploaded by the channel first, then YouTube's automatic English captions, then any language. The video title and channel are added at the top. The channel is the uploader, not necessarily the speaker. Channel and playlist pages, videos without captions, Vimeo, Spotify and audio or video files are refused with a message.
- **PDFs.** Give a PDF address (one that serves a PDF is detected even without ".pdf" in its name) or the path of a PDF on the Mac. The text is cleaned before summarising: the line breaks of each printed line are joined into paragraphs, words split by a hyphen at a line end are mended, and page numbers, headers and footers repeated on many pages, web addresses at the page edge and copyright lines are dropped. The title is the first short line of page 1 (the PDF's own title field is unreliable), or the file name if there is none. A PDF with no readable text (scanned pages), a password-protected one, a file that is not really a PDF, a damaged one and one over 30 MB are refused with a message.
- **Files saved.** The summary gets a `Source:` line, marked `(PDF)`, `(YouTube captions, automatic)` or `(text appears cut off: possibly a paywalled teaser)` where that applies. The exact text the model read is saved next to it as `YYYY-MM-DD-title-source.txt`, so a summary can be checked against it. Long texts also save a `-notes.txt` file.
- **It stops instead of summarising** when the page marks its article as members-only, when fewer than 150 words come back (60 for YouTube and PDFs), when the site answers with an HTTP error (the status is shown), or when it redirects to a login page. `RECAP_URL_FORCE=1 recapurl "ADDRESS"` skips the paywall, short-text and length checks.
- **Several addresses** run one after another. A failed address does not stop the rest, and the final list shows each failure with its reason. Extra addresses must start with `https://` or `www.`, or be a `.pdf` file. A mode or focus placed after the addresses applies to all of them.
- **One file or many.** For two or more addresses, `--single` saves one combined file and `--separate` gives each address its own. Without a flag, `RECAP_BATCH` decides, then the command asks once (only in a terminal), otherwise separate files are used. The combined file is `YYYY-MM-DD-batch-of-N-links.md`: one heading per summary, `---` between them, and a "Not summarised" section with reasons. In that mode no individual summary files are created. The source files are still saved, and the clipboard is not touched.

## How it is configured

| Setting | Value | Why |
| --- | --- | --- |
| Model | `gemma4:e2b` (2.3B effective) | The largest Gemma 4 that runs fully on the GPU of an 8 GB Mac |
| Temperature | 0.2 | Low randomness. Tested against 1.0; the higher setting gave a different factual error on almost every run |
| Context (`num_ctx`) | 12288 tokens | About 7,000 words of hard capacity. Larger values need more RAM than 8 GB allows |
| Thinking mode | Off | `--think=false` is added automatically for Gemma 4 and Qwen. Gemma 3 does not accept the flag |

Change the temperature by editing `~/Modelfile.g4`, then:

```sh
ollama create gemma4-sum -f ~/Modelfile.g4
ollama stop gemma4-sum
```

Use a different model for a single run with `RECAP_MODEL=gemma-sum recap`.

Alternatives were tried on one three-article batch each (5 Oct 2026). `phi4-mini` copied the example sentence from the prompt into its output and skipped the gist. `qwen3.5:4b` did not fit fully on the GPU of an 8 GB Mac (23%/77% CPU/GPU) and invented one figure. `gemma4:e2b` stays the default. One run each is guidance, not a measured result.

Settings that can be put before a command, or exported in `~/.zshrc`:

| Setting | Default | What it changes |
| --- | --- | --- |
| `RECAP_MODEL` | `gemma4-sum` | Model for one run |
| `RECAP_DIR` | `~/Summaries` | Output folder |
| `RECAP_CHUNK` | 1200 | Words per part when reading long text |
| `RECAP_LONG_WORDS` | 4000 | Above this, `recapall` and `recapurl` read in parts |
| `RECAP_OVERLAP` | 0.6 | How much a "Worth noting" bullet may repeat the main points before it is dropped (lower filters more) |
| `RECAP_BATCH` | (ask) | `single` or `separate` for several addresses |
| `RECAP_URL_MIN` | 150 (60 for YouTube and PDFs) | Fewest words `recapurl` accepts |
| `RECAP_URL_MAX` | 10000 | Most words `recapurl` accepts |
| `RECAP_PDF_MAX_MB` | 30 | Largest PDF `recapurl` downloads or opens |
| `RECAP_PDF_READER` | (pypdfium2) | `pypdf` forces the fallback reader, for troubleshooting |
| `RECAP_URL_FORCE` | off | `1` skips the paywall, short-text and length checks |

## Length limits

The context window holds roughly 7,000 words, but accuracy can fall before that ceiling. Measured against the source texts:

| Article length | Behaviour |
| --- | --- |
| Up to ~1,500 words | Reliable. Figures, names and attribution generally correct |
| 1,500-4,500 words | Mostly good (a 4,400-word essay and a 1,200-word one checked clean); occasional dropped detail |
| Above ~5,000 words | Meaning can reverse in a single pass. Use `recaplong` |

One real failure found at length: in a 5,900-word essay the single-pass summary turned "without solitude there would be no America" into "independent thinking without solitude", reversing the argument. Because that failure came from a single run, treat the thresholds above as guidance, not a measured limit. `recaplong` reads long text in roughly 1,200-word parts and combines the notes; on a 6,600-word transcript it kept every claim checked accurate, but its "Worth noting" section repeated points. A filter now drops "Worth noting" bullets that mostly repeat the main points, and it worked on the same transcript. `recapall`, `recapurl` and `recapurls` apply the part-by-part method automatically above 4,000 words. The method has an untested ceiling: the combined notes must fit the same 12,288-token window, which by estimate allows about 10,000 words of source text, so `recapurl` stops above that unless told otherwise.

## Known weaknesses

No invented facts were found in the summaries checked, but five faults repeat. Treat a summary as a map of the article, not a replacement for it.

- **Dropped hedges.** Qualifiers such as "very difficult", "possibly" or "the best explanation is" get trimmed, making claims sound firmer than the source.
- **Who said what.** A conclusion the author drew is credited to the person being quoted. Verify any "according to X" before repeating it.
- **New versus unchanged rules.** In circulars, existing clauses can appear as if they were the changes. Use `recap changes`, then read the clauses it names.
- **Flattened names.** "A journalist" or "a report" in place of the named person or publication.
- **Figures.** A number belonging to one scenario can migrate to another.

Four more apply to the address commands and to `recap` itself:

- **Web extraction.** The text that comes back can be a paywall teaser, a notice or an advert, and the summary will describe it confidently. Read the "Text starts" lines and the saved `-source.txt` file. The stop messages catch the common cases, not all.
- **YouTube automatic captions.** They have no speaker names, little punctuation and some misheard words, so attribution is the weakest point. Check names, figures and who said what against the video.
- **PDF layout.** Two-column pages, tables and footnotes can come out jumbled or flattened, and the summary then describes the jumble. Scanned PDFs cannot be read. Read the saved `-source.txt` first when the layout is complicated.
- **Missing gist.** Sometimes the summary starts straight with bullets and has no gist sentence (seen on one `recapall` run of an article and on one `recap` run of a fictional case study, so the cause is the model, not the batch code). Running it again restored the gist in the one case that was repeated.

Strongest on news, match reports, explainers, research write-ups and market pieces. Weakest on collections of quotes or anecdotes, where attribution slips most, and on regulatory texts.

For an important document, run it a second time with `RECAP_MODEL=gemma-sum recap` and compare. Where two different models agree, the summary is usually sound.

## Checking memory

While a summary is running, open a second terminal:

```sh
ollama ps
```

The `PROCESSOR` column should read `100% GPU`. A CPU/GPU split means the model no longer fits in memory and will be slow.

## Repository contents

- `recap.zsh` — the shell functions
- `Modelfile.g4` — the model definition
- `MANUAL.pdf` — printable reference
- `README.md` — this file

## Licence

MIT.
