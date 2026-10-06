# Recap

A local article summariser for macOS. Copy an article (or give a web address, a YouTube link or a PDF), type one word, read the gist.

Everything is summarised on the machine through [Ollama](https://ollama.com), so no article text is sent to any AI service. The clipboard commands (`recap`, `recaplong`, `recapall`, `recapmail`) work without a network connection. The address commands (`recapurl`, `recapurls`) need one to fetch a web page, a YouTube video's captions or a PDF at an address. A PDF file already on the Mac is read offline. Built and tuned on a MacBook Air M1 with 8 GB of RAM.

## Before you start

- **A Mac.** The commands use `pbcopy` and `pbpaste` and run in `zsh`, so this is macOS only. Linux and Windows are not supported.
- **Tested on one machine:** a MacBook Air M1 with 8 GB of RAM. Other Macs, Intel Macs and other macOS versions have not been tested.
- **[Ollama](https://ollama.com)**, which runs the language models on your Mac. See its site for its own system requirements. The default model is about 4.6 GB.
- **Python 3.9 or newer**, only for `recapurl` and `recapurls` (web pages, YouTube, PDFs). The clipboard commands do not need it. `recapsetup` installs what they need in a private environment, so your own Python is left alone.

## What stays on your Mac

| What you do | What leaves your Mac |
| --- | --- |
| Summarise copied text (`recap`, `recaplong`, `recapall`, `recapmail`) | Nothing. The model runs locally |
| Summarise a PDF file already on your Mac | Nothing |
| `recapurl` or `recapurls` with a web address, YouTube link or PDF address | Your Mac downloads the page, captions or PDF directly from that site, which sees the request and your IP address. The text is then summarised locally |
| First-time setup | Downloads of Ollama, the models and (with `recapsetup`) the Python packages |

Recap itself sends nothing anywhere except the downloads you ask for. It does not control what Ollama or the Python packages do; see their own documentation.

Everything Recap saves is plain, unencrypted text: summaries, source texts and notes in `~/Summaries`, and, for `recapc` and `recapall`, summaries on the clipboard, which other apps can read. For sensitive material, delete the files afterwards, point `RECAP_DIR` at a folder on an encrypted volume, and clear the clipboard.

## Accuracy and limits

Summaries come from a small local model and can be wrong. In testing, no invented facts were found in the summaries checked, but meaning errors did occur: dropped hedges, wrong attribution, swapped figures, and in one long text a reversed argument (see "Known weaknesses"). Treat a summary as a map of the article, never as the final word, and check the source before relying on it. Do not use a summary alone for a legal, medical or financial decision.

## Sensitive material

Recap summarises on your Mac, so copied text and PDF files already on the Mac are not sent to an AI service. It is not audited or certified, and this README makes no claim that it meets any organisation's security or compliance requirements. Before using it on official, confidential or regulated material, check what your organisation permits. Weigh these points:

- Setup downloads Ollama, models and Python packages from the internet, and offline installation is not documented.
- The address commands contact the sites you name.
- Saved files and clipboard contents are unencrypted.
- Summaries can be wrong in meaning.
- It is maintained by one person on a best-effort basis.

To report a security problem privately, see `SECURITY.md`.

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
| `recapsetup` | Creates or updates the private Python environment that `recapurl` and `recapurls` use |
| `recapdoctor` | Checks the whole setup and says what to fix. Safe to paste into a bug report |
| `recap help` | Lists the options |
| `recap version` | Shows which version of Recap this is |

Every summary is written as Markdown to `~/Summaries/YYYY-MM-DD-title.md` and printed on screen.

## Setup

Get the code, and install [Ollama](https://ollama.com) if you do not have it:

```sh
git clone https://github.com/rathodlaxman/recap.git
cd recap
```

Or use the green Code button on the repository page and choose Download ZIP, then unzip it and open Terminal in that folder.

Then build the model:

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

Optional second-opinion model, used with `RECAP_MODEL=gemma-sum recap` (see "Known weaknesses"):

```sh
ollama pull gemma3:4b
printf 'FROM gemma3:4b\nPARAMETER num_ctx 12288\nPARAMETER temperature 0.2\n' > ~/Modelfile.sum
ollama create gemma-sum -f ~/Modelfile.sum
```

`recapurl` and `recapurls` need three Python packages (`trafilatura`, `youtube-transcript-api`, `pypdfium2`). One command installs them:

```sh
recapsetup
```

It creates a private Python environment in `~/.recap/venv` and installs the packages there. This takes about a minute and needs a network connection. It never touches your own Python, so it also works when `pip` refuses to install into a Python managed by Homebrew (the `externally-managed-environment` error). Run it again any time to upgrade the packages, for example if YouTube captions stop working.

Then check everything:

```sh
recapdoctor
```

`recapdoctor` reports on macOS, Ollama, the models, the Python packages and the output folder, and says what to fix. If something does not work, paste its output into your bug report.

Recap picks its Python in this order: `RECAP_PYTHON` if you set it, then the private environment, then `python3` from your path. The last option keeps older setups working. If you use your own environment, install the three packages in it yourself. `pypdf` is an optional fallback PDF reader: if `pypdfium2` is missing but `pypdf` is installed, `recapurl` falls back to it and says so, but `pypdf` can garble page headers and small capitals.

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
| `RECAP_HOME` | `~/.recap` | Where `recapsetup` puts the private Python environment |
| `RECAP_PYTHON` | (none) | A Python to use instead of the private environment |
| `RECAP_BASE_PYTHON` | `python3` | The Python `recapsetup` uses to create the environment |
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

## Third-party software and terms

- **Models.** Each model has its own licence and terms, shown on its page in the Ollama library. By pulling a model you accept them. Recap does not include or redistribute any model.
- **Python packages.** `trafilatura`, `youtube-transcript-api` and `pypdfium2` (and the optional `pypdf`) are installed from PyPI by `recapsetup` under their own licences.
- **YouTube.** Captions are read with an unofficial library that uses YouTube's undocumented access. It can stop working at any time and YouTube may restrict it. Use it at your own discretion.
- **Web content.** You are responsible for having the right to read and summarise what you fetch. Recap does not bypass paywalls: when a page marks itself members-only it stops, and `RECAP_URL_FORCE=1` only skips the checks, so it summarises whatever text the site returned.

## Repository contents

- `recap.zsh` — the shell functions
- `Modelfile.g4` — the default model definition
- `Modelfile.sum` — the optional second-opinion model
- `MANUAL.pdf` — printable reference
- `README.md` — this file
- `LICENSE` — the MIT licence
- `CHANGELOG.md` — what changed in each version
- `CONTRIBUTING.md` — how to report a problem or send a change
- `SECURITY.md` — how to report a security problem privately
- `.github/` — issue and pull request templates
- `.gitignore` — files git should skip

## Contributing and security

Bug reports and ideas are welcome. See `CONTRIBUTING.md` for how to report a problem or send a change, and for the project's conventions. Please do not paste private text into a public issue. Security problems are reported privately: see `SECURITY.md`. Changes between versions are listed in `CHANGELOG.md`.

## Licence and support

MIT, see `LICENSE`. Provided as is, without warranty of any kind.

It is maintained on a best-effort basis. Bug reports are welcome, but replies and fixes are not guaranteed.
