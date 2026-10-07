# Recap

**Recap is a free, open-source command-line tool for macOS that summarizes articles, web pages, YouTube videos and PDFs on your own Mac, using a local AI model.** You type one short command in Terminal and read the gist. It is not an app with windows and buttons: you run it from Terminal.

**New to Terminal? Start with [GETTING-STARTED.md](GETTING-STARTED.md).** It walks through every step in plain language.

The summarizing happens on your Mac through [Ollama](https://ollama.com), so no article text is sent to any AI service. The clipboard commands (`recap`, `recaplong`, `recapall`, `recapmail`) work without a network connection. The address commands (`recapurl`, `recapurls`) need one to fetch a web page, a YouTube video's captions or a PDF at an address. A PDF file already on the Mac is read offline. Built and tuned on a MacBook Air M1 with 8 GB of RAM.

## Quick start

1. **Install [Ollama](https://ollama.com)** (download it, open it once).
2. **Download Recap:** on the repository page click the green **Code** button, then **Download ZIP**, and unzip it.
3. **Open Terminal** and go to the Recap folder: type `cd ` (with a space after it), drag the unzipped folder into the Terminal window, and press Enter.
4. **Switch Recap on** (this adds one line to your `~/.zshrc`; do it once):
   ```sh
   echo "source $PWD/recap.zsh" >> ~/.zshrc
   source ~/.zshrc
   ```
5. **Run the one-time setup.** It installs what the address commands need and downloads the summarizing model (about 4.6 GB, once):
   ```sh
   recapsetup
   ```
6. **Check that everything is fine:**
   ```sh
   recapdoctor
   ```
7. **Summarize a short sample.** The Recap folder has a `samples` folder with short texts. This tells Recap to read one of them (`<` means "read from this file"; it needs no internet):
   ```sh
   recap < samples/sample-article.txt
   ```

Keep the Recap folder where it is. If you move it, repeat step 4 and delete the old `source` line from `~/.zshrc`.

**Use Homebrew?** Replace steps 2 to 4 with the commands in "Install with Homebrew" below.

## Examples

Start with the samples, which need no internet and finish quickly. Then try a web page. Copy a command from a gray box and paste it into Terminal. **Type or copy the straight quote marks (`"`).** If you copy from Word, Notes or WhatsApp, the quotes can turn curly (`“ ”`) and the command fails.

**How long things take.** On the tested Mac (an M1 with 8 GB of memory), allow 30 to 90 seconds for a text of about 1,000 words. Longer texts are read in parts and take minutes: the Wikipedia article "AI agent" (about 7,300 words) is read in seven parts, which Recap estimates at about five minutes, and "Generative artificial intelligence" (about 13,000 words) is refused as too long. The examples below are short on purpose.

### Text from a file, or text you copy (works offline)

Give Recap a file with `<`, or copy text yourself (select it, press Command + C) and run the command with nothing after it. **If you copy text, type the command; do not copy it from a web page or a chat**, because copying the command replaces your text on the clipboard. Giving a file with `<` has no such problem. Run these from the Recap folder:

```sh
recap < samples/sample-article.txt
```

Variations on the same file:

```sh
recap short < samples/sample-article.txt
recap "focus on the costs" < samples/sample-article.txt
recapc < samples/sample-article.txt
```

- `recap`: the standard summary (gist, main points, and "Worth noting" if there is more).
- `recap short`: one sentence and up to three takeaways.
- `recap "focus on the costs"`: a summary that pays special attention to what you name.
- `recapc`: the same as `recap`, and the summary is also copied to the clipboard so you can paste it.

**A circular or rule change.** `recap changes` says which clauses are new and which already existed:

```sh
recap changes < samples/sample-circular.txt
```

**An email:**

```sh
recapmail < samples/sample-email.txt
```

**Several articles in one go.** Put a line containing only `@@@@` between the articles and run `recapall`:

```sh
recapall < samples/sample-batch.txt
```

**A long article or transcript** (over about 4,000 words): give it to `recaplong` (`recaplong < file.txt`, or copy it first). It reads the text in parts, is more accurate, and takes several minutes.

Every command that takes text accepts a file (`< file.txt`) or text piped in (`cat file.txt | recap`). With nothing given, it reads the clipboard.

### Web pages (needs internet)

These two pages are short (each under 2,000 words): "Ideas That Changed My Life" by Morgan Housel, and Jeff Bezos's 2010 Princeton speech on James Clear's site.

```sh
recapurl "https://collabfund.com/blog/ideas-that-changed-my-life/"
```

A short version, and a version with your own focus:

```sh
recapurl "https://collabfund.com/blog/ideas-that-changed-my-life/" short
recapurl "https://collabfund.com/blog/ideas-that-changed-my-life/" "focus on competitive advantage"
```

Both pages one after another (`recapurls` does the same with the same addresses):

```sh
recapurl "https://collabfund.com/blog/ideas-that-changed-my-life/" "https://jamesclear.com/great-speeches/what-matters-more-than-your-talents-by-jeff-bezos"
```

```sh
recapurls "https://collabfund.com/blog/ideas-that-changed-my-life/" "https://jamesclear.com/great-speeches/what-matters-more-than-your-talents-by-jeff-bezos"
```

Saved as one combined file (`--single`) or one file each (`--separate`):

```sh
recapurls --single "https://collabfund.com/blog/ideas-that-changed-my-life/" "https://jamesclear.com/great-speeches/what-matters-more-than-your-talents-by-jeff-bezos"
```

**A list of addresses from the clipboard.** Copy lines like these (one address per line, from a note or an email), then run `recapurls` with nothing after it:

```
https://collabfund.com/blog/ideas-that-changed-my-life/
https://jamesclear.com/great-speeches/what-matters-more-than-your-talents-by-jeff-bezos
```

```sh
recapurls
```

### A PDF

From an address, or from a file on your Mac. This paper is five pages, roughly 2,500 words:

```sh
recapurl "https://www.nakedcapitalism.com/wp-content/uploads/2015/08/How-Complex-Systems-Fail.pdf"
```

Some sites refuse automatic downloads (Recap then says `HTTP 403`). In that case download the PDF in your browser and use the file form below.

For a file you already have, type `recapurl ` and drag the PDF into the Terminal window to fill in its path:

```sh
recapurl ~/Downloads/report.pdf
```

A whole book is refused as too long. Copy one chapter's text and use `recaplong` instead.

### A YouTube video

Recap reads the captions, so pick a video that shows the CC button. Spoken words run at roughly 150 a minute, so a 10-minute video is about 1,500 words and gives a quick result. Recap stops above 10,000 words, which is about an hour of speech. Replace `VIDEOID` with the code from the video's address:

```sh
recapurl "https://www.youtube.com/watch?v=VIDEOID"
```

The first messages show how many words of captions were found, so you can press Control + C straight away if a video is longer than you want to wait for.

### Folders, duplicates and searching your summaries

Give `recapurl` a folder, and it summarizes every PDF in it (not the folders inside it, and not other kinds of file), in name order. With more than 10 files in a terminal it asks first, because each one can take a minute or more:

```sh
recapurl ~/Desktop/Reports
```

Duplicates are skipped. The same page with tracking junk after the address, a trailing slash, `www.` or `http`, or the same YouTube video as `youtu.be/…`, counts as one:

```sh
recapurl "https://collabfund.com/blog/ideas-that-changed-my-life/" "https://www.collabfund.com/blog/ideas-that-changed-my-life?utm_source=newsletter"
```

An address you summarized before is not summarized again. Recap shows the saved summary instead and says when it was made. Add `--again` to summarize it afresh. This applies only to a plain summary: with `short` or a focus text you get a new one:

```sh
recapurl --again "https://collabfund.com/blog/ideas-that-changed-my-life/"
```

Search everything you have saved. Every word must appear, and the newest summaries come first:

```sh
recapfind interest rates
recapfind --max 5 library
recapfind --sources zebra
```

### A notification when a long run ends

Notifications are off unless you ask for them. Add `--notify` to any of the summarizing commands (before or after the addresses). If the run takes longer than 20 seconds, macOS shows a notification with a sound, so you can do something else meanwhile. A batch gives one notification at the end, and a batch with failures uses a warning sound:

```sh
recapurl --notify "https://example.com/a" "https://example.com/b"
recap --notify < long-report.txt
```

To have it every time, add `export RECAP_NOTIFY=1` to your `~/.zshrc`. The first time, macOS may ask whether to allow notifications.

### Check your setup or version at any time

```sh
recapdoctor
recap version
```

Every summary is also saved as a Markdown file in the `Summaries` folder in your home folder.

## Before you start

- **A Mac.** The commands use `pbcopy` and `pbpaste` and run in `zsh`, so this is macOS only. Linux and Windows are not supported.
- **Tested on one machine:** a MacBook Air M1 with 8 GB of RAM. Other Macs, Intel Macs and other macOS versions have not been tested.
- **[Ollama](https://ollama.com)**, which runs the language model on your Mac. See its site for its own system requirements. The model is about 4.6 GB and is downloaded once by `recapsetup`.
- **Python 3.9 or newer**, only for `recapurl` and `recapurls` (web pages, YouTube, PDFs). The clipboard commands do not need it. `recapsetup` installs what they need in a private environment, so your own Python is left alone.

## What stays on your Mac

| What you do | What leaves your Mac |
| --- | --- |
| Summarize copied text (`recap`, `recaplong`, `recapall`, `recapmail`) | Nothing. The model runs locally |
| Summarize a PDF file already on your Mac, or every PDF in a folder | Nothing |
| `recapfind`, and the notification when a run ends | Nothing. Both use only your Mac |
| `recapurl` or `recapurls` with a web address, YouTube link or PDF address | Your Mac downloads the page, captions or PDF directly from that site, which sees the request and your IP address. The text is then summarized locally |
| First-time setup | Downloads of Ollama, the model (about 4.6 GB) and the Python packages, all done by `recapsetup` |

Recap itself sends nothing anywhere except the downloads you ask for. It does not control what Ollama or the Python packages do; see their own documentation.

Everything Recap saves is plain, unencrypted text: summaries, source texts and notes in `~/Summaries`, and, for `recapc` and `recapall`, summaries on the clipboard, which other apps can read. For sensitive material, delete the files afterwards, point `RECAP_DIR` at a folder on an encrypted volume, and clear the clipboard.

## Accuracy and limits

Summaries come from a small local model and can be wrong. In testing, no invented facts were found in the summaries checked, but meaning errors did occur: dropped hedges, wrong attribution, swapped figures, and in one long text a reversed argument (see "Known weaknesses"). Treat a summary as a map of the article, never as the final word, and check the source before relying on it. Do not use a summary alone for a legal, medical or financial decision.

## Sensitive material

Recap summarizes on your Mac, so copied text and PDF files already on the Mac are not sent to an AI service. It is not audited or certified, and this README makes no claim that it meets any organization's security or compliance requirements. Before using it on official, confidential or regulated material, check what your organization permits. Weigh these points:

- Setup downloads Ollama, models and Python packages from the internet, and offline installation is not documented.
- The address commands contact the sites you name.
- Saved files and clipboard contents are unencrypted.
- Summaries can be wrong in meaning.
- It is maintained by one person on a best-effort basis.

To report a security problem privately, see `SECURITY.md`.

## What it does

| Command | What it does |
| --- | --- |
| `recap` | Adaptive summary of the text on the clipboard, or of a file you give it (`recap < file.txt`): gist, main points, and "Worth noting" only if there is more |
| `recap short` | One sentence plus up to three takeaways |
| `recap changes` | For circulars and rule changes: which clauses are new, which are unchanged, who acts and from when |
| `recap "focus on costs"` | Summary with a focus you choose |
| `recaplong` | Long articles and transcripts: reads the text in parts, then combines. Slower but far more accurate |
| `recapall` | Several articles in one run, separated by lines containing only `@@@@`. An article over 4,000 words is read in parts automatically |
| `recapc` | Same as `recap`, and also copies the summary to the clipboard |
| `recapmail` | Short email summary: sender, tasks, deadlines, whether a reply is needed. Uses the same model as everything else |
| `recapurl "ADDRESS"` | Fetches a web article, the captions of a YouTube video, or a PDF (an address or a file on the Mac), and summarizes it |
| `recapurl "A" "B"` | Several addresses or PDF files in one run. `--single` saves one combined file, `--separate` one file each |
| `recapurl FOLDER` | Summarizes every PDF in a folder (not its subfolders), in name order |
| `recapfind "words"` | Searches your saved summaries. Every word must appear; capital letters do not matter |
| `recapurls` | Summarizes the addresses typed after it, or every web address on the clipboard (one per line). Same flags as `recapurl` |
| `recapsetup` | One-time setup: the private Python environment and the summarizing model |
| `recapdoctor` | Checks the whole setup and says what to fix. Safe to paste into a bug report |
| `recap help` | Lists the options |
| `recap version` | Shows which version of Recap this is |

Every summary is written as Markdown to `~/Summaries/YYYY-MM-DD-title.md` and printed on screen.

## Setup

The quick start above is all most people need. This section explains it in more detail.

**1. Get Ollama.** Install [Ollama](https://ollama.com) and open it once. It runs the language model on your Mac.

**2. Get the code.** Download the ZIP from the repository page, or use git:

```sh
git clone https://github.com/rathodlaxman/recap.git
cd recap
```

**3. Switch Recap on.** In the Recap folder, add one `source` line to your `~/.zshrc`:

```sh
echo "source $PWD/recap.zsh" >> ~/.zshrc
source ~/.zshrc
```

Use a `source` line and not a pasted copy: with two copies of a function, the old one can keep running.

**4. Run the setup.** One command does the rest:

```sh
recapsetup
```

It does two things:

- **The Python packages.** `recapurl` and `recapurls` need three (`trafilatura`, `youtube-transcript-api`, `pypdfium2`). `recapsetup` creates a private Python environment in `~/.recap/venv` and installs them there. This takes about a minute and needs a network connection. It never touches your own Python, so it also works when `pip` refuses to install into a Python managed by Homebrew (the `externally-managed-environment` error).
- **The summarizing model.** It downloads `gemma4:e2b` (about 4.6 GB, once) and builds the model `gemma4-sum` from it, with the settings Recap needs. If Ollama is not running, Recap starts it for you (it opens the Ollama app in the background, or runs `ollama serve`). If Ollama is not installed, it says so; install it and run `recapsetup` again.

**Recap starts Ollama when needed.** After a restart you do not have to open the Ollama app first: every command that needs the model checks that Ollama is running, starts it if it is not, and waits up to 30 seconds. You can also have the Ollama app open at login if you prefer.

**One model does every job.** `gemma4-sum` is used for `recap`, `recaplong`, `recapall`, `recapurl`, `recapurls` and `recapmail`. You do not need any other model. `recapsetup --no-model` skips the model step if you want to set it up yourself.

Run `recapsetup` again any time to upgrade the Python packages, for example if YouTube captions stop working.

**5. Check everything:**

```sh
recapdoctor
```

`recapdoctor` reports on macOS, Ollama, the model, the Python packages and the output folder, and says what to fix. If something does not work, paste its output into your bug report.

**Setting up the model by hand** (optional; `recapsetup` does exactly this):

```sh
ollama pull gemma4:e2b
printf 'FROM gemma4:e2b\nPARAMETER num_ctx 12288\nPARAMETER temperature 0.2\n' > ~/Modelfile.g4
ollama create gemma4-sum -f ~/Modelfile.g4
```

**Optional: a second opinion.** For an important document you can run it a second time with a different model and compare (see "Known weaknesses"). This is the only reason to install a second model:

```sh
ollama pull gemma3:4b
printf 'FROM gemma3:4b\nPARAMETER num_ctx 12288\nPARAMETER temperature 0.2\n' > ~/Modelfile.sum
ollama create gemma-sum -f ~/Modelfile.sum
```

Then use `RECAP_MODEL=gemma-sum recap`.

**Which Python runs the address commands:** `RECAP_PYTHON` if you set it, then the private environment, then `python3` from your path. The last option keeps older setups working. If you use your own environment, install the three packages in it yourself. `pypdf` is an optional fallback PDF reader: if `pypdfium2` is missing but `pypdf` is installed, `recapurl` falls back to it and says so, but `pypdf` can garble page headers and small capitals.

## Install with Homebrew

If you use [Homebrew](https://brew.sh), one command installs Recap instead of the ZIP download:

```sh
brew install rathodlaxman/tap/recap
```

Use the **full name** exactly as written. Since Homebrew 6.0.0, code from third-party taps is not run until you trust it, and installing by the full name trusts only Recap's formula. If you add the tap first with `brew tap rathodlaxman/tap` and want to install by the short name, run `brew trust --formula rathodlaxman/tap/recap` first. See [Homebrew's Tap Trust page](https://docs.brew.sh/Tap-Trust).

Homebrew installs the files but does not change your `~/.zshrc`. Switch Recap on, run the one-time setup, and check it:

```sh
echo "source $(brew --prefix)/opt/recap/share/recap/recap.zsh" >> ~/.zshrc
source ~/.zshrc
recapsetup
recapdoctor
```

Try it on a sample:

```sh
recap < "$(brew --prefix)/opt/recap/share/recap/samples/sample-article.txt"
```

The samples are in `$(brew --prefix)/opt/recap/share/recap/samples/` and the documentation, including the guide for beginners, is in `$(brew --prefix)/opt/recap/share/doc/recap/`.

- **Upgrade:** `brew update`, then `brew upgrade recap`.
- **Remove:** `brew uninstall recap` and `brew untap rathodlaxman/tap`, then delete the `source` line from `~/.zshrc`. Your summaries and the private Python environment in `~/.recap` are not removed.
- **Use one copy only.** If you have both a ZIP download and a Homebrew install, keep only one `source` line in `~/.zshrc`, or two copies will load.
- Homebrew does not install Ollama. Install it yourself (see "Before you start"); `recapsetup` then does the rest, exactly as in the ZIP route.

The formula lives in a separate repository, [rathodlaxman/homebrew-tap](https://github.com/rathodlaxman/homebrew-tap).

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
- **PDFs.** Give a PDF address (one that serves a PDF is detected even without ".pdf" in its name) or the path of a PDF on the Mac. The text is cleaned before summarizing: the line breaks of each printed line are joined into paragraphs, words split by a hyphen at a line end are mended, and page numbers, headers and footers repeated on many pages, web addresses at the page edge and copyright lines are dropped. The title is the first short line of page 1 (the PDF's own title field is unreliable), or the file name if there is none. A PDF with no readable text (scanned pages), a password-protected one, a file that is not really a PDF, a damaged one and one over 30 MB are refused with a message.
- **Author and site.** Under the heading, `Source:` shows the cleaned address (tracking parameters such as `utm_source` and `fbclid` and the `#` part are removed), and the next line shows `Author: … | Site: …`. For YouTube it shows `Channel: … | Site: youtube.com`. The author appears only when the page declares one; the site falls back to the address's host name. For a PDF, the author is read from an explicit line on page 1 ("by …", "Prepared by …" or "Author: …"), never from the PDF's own metadata, which is unreliable. A PDF on your Mac also shows `File: name.pdf`, and a PDF at an address shows its site. A first line that looks like a document code (such as "IIMA/ BP0370") is not used as the heading: the file name is.
- **Duplicates and repeats.** Duplicate addresses in one command are skipped and listed. An address already summarized (found by reading the `Source:` lines of your saved summaries) is not summarized again: Recap shows the saved summary. `--again` redoes it, and `short`, `changes` or a focus text always run, because they ask for something different.
- **Folders.** A folder stands for the PDF files directly inside it. With more than 10 and a terminal, Recap asks before starting.
- **Files saved.** The summary gets a `Source:` line, marked `(PDF)`, `(YouTube captions, automatic)` or `(text appears cut off: possibly a paywalled teaser)` where that applies. The exact text the model read is saved next to it as `YYYY-MM-DD-title-source.txt`, so a summary can be checked against it. Long texts also save a `-notes.txt` file.
- **It stops instead of summarizing** when the page marks its article as members-only, when fewer than 150 words come back (60 for YouTube and PDFs), when the site answers with an HTTP error (the status is shown), or when it redirects to a login page. `RECAP_URL_FORCE=1 recapurl "ADDRESS"` skips the paywall, short-text and length checks.
- **Several addresses** run one after another. A failed address does not stop the rest, and the final list shows each failure with its reason. Extra addresses must start with `https://` or `www.`, or be a `.pdf` file. A mode or focus placed after the addresses applies to all of them.
- **One file or many.** For two or more addresses, `--single` saves one combined file and `--separate` gives each address its own. Without a flag, `RECAP_BATCH` decides, then the command asks once (only in a terminal), otherwise separate files are used. The combined file is `YYYY-MM-DD-batch-of-N-links.md`: one heading per summary, `---` between them, and a "Not summarized" section with reasons. In that mode no individual summary files are created. The source files are still saved, and the clipboard is not touched.

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

Alternatives were tried on one three-article batch each (Oct 5, 2026). `phi4-mini` copied the example sentence from the prompt into its output and skipped the gist. `qwen3.5:4b` did not fit fully on the GPU of an 8 GB Mac (23%/77% CPU/GPU) and invented one figure. `gemma4:e2b` stays the default. One run each is guidance, not a measured result.

Settings that can be put before a command, or exported in `~/.zshrc`:

| Setting | Default | What it changes |
| --- | --- | --- |
| `RECAP_MODEL` | `gemma4-sum` | Model for one run |
| `RECAP_MAIL_MODEL` | (the model above) | A different model for `recapmail` only |
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
| `RECAP_NOTIFY` | off | `1` shows a macOS notification with a sound when a long run ends (the same as `--notify`) |
| `RECAP_NOTIFY_AFTER` | 20 | Seconds a run must last before it notifies |
| `RECAP_NOTIFY_SOUND` | `Glass` | Any macOS alert sound name, for example `Ping`. A run with failures always uses `Basso` |

## Length limits

The context window holds roughly 7,000 words, but accuracy can fall before that ceiling. Measured against the source texts:

| Article length | Behavior |
| --- | --- |
| Up to ~1,500 words | Reliable. Figures, names and attribution generally correct |
| 1,500-4,500 words | Mostly good (a 4,400-word essay and a 1,200-word one checked clean); occasional dropped detail |
| Above ~5,000 words | Meaning can reverse in a single pass. Use `recaplong` |

One real failure found at length: in a 5,900-word essay the single-pass summary turned "without solitude there would be no America" into "independent thinking without solitude," reversing the argument. Because that failure came from a single run, treat the thresholds above as guidance, not a measured limit. `recaplong` reads long text in roughly 1,200-word parts and combines the notes; on a 6,600-word transcript it kept every claim checked accurate, but its "Worth noting" section repeated points. A filter now drops "Worth noting" bullets that mostly repeat the main points, and it worked on the same transcript. `recapall`, `recapurl` and `recapurls` apply the part-by-part method automatically above 4,000 words. The method has an untested ceiling: the combined notes must fit the same 12,288-token window, which by estimate allows about 10,000 words of source text, so `recapurl` stops above that unless told otherwise.

## Known weaknesses

No invented facts were found in the summaries checked, but five faults repeat. Treat a summary as a map of the article, not a replacement for it.

- **Dropped hedges.** Qualifiers such as "very difficult," "possibly" or "the best explanation is" get trimmed, making claims sound firmer than the source.
- **Who said what.** A conclusion the author drew is credited to the person being quoted. Verify any "according to X" before repeating it.
- **New versus unchanged rules.** In circulars, existing clauses can appear as if they were the changes. Use `recap changes`, then read the clauses it names.
- **Flattened names.** "A journalist" or "a report" in place of the named person or publication.
- **Figures.** A number belonging to one scenario can migrate to another.

Five more apply to the address commands and to `recap` itself:

- **Web extraction.** The text that comes back can be a paywall teaser, a notice or an advert, and the summary will describe it confidently. Read the "Text starts" lines and the saved `-source.txt` file. The stop messages catch the common cases, not all.
- **YouTube automatic captions.** They have no speaker names, little punctuation and some misheard words, so attribution is the weakest point. Check names, figures and who said what against the video.
- **PDF layout.** Two-column pages, tables and footnotes can come out jumbled or flattened, and the summary then describes the jumble. Scanned PDFs cannot be read. Read the saved `-source.txt` first when the layout is complicated.
- **Author and site lines.** On a web page they come from tags the page itself declares, so the author can be missing or, rarely, wrong (a company name, for example). In a PDF they come from a "by …" line on page 1. They appear only when found, and a generic name such as "admin" or "The Editors" is dropped.
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

- **Models.** Each model has its own license and terms, shown on its page in the Ollama library. `recapsetup` downloads `gemma4:e2b`, and by downloading a model you accept its terms. Recap does not include or redistribute any model.
- **Python packages.** `trafilatura`, `youtube-transcript-api` and `pypdfium2` (and the optional `pypdf`) are installed from PyPI by `recapsetup` under their own licenses.
- **YouTube.** Captions are read with an unofficial library that uses YouTube's undocumented access. It can stop working at any time and YouTube may restrict it. Use it at your own discretion.
- **Web content.** You are responsible for having the right to read and summarize what you fetch. Recap does not bypass paywalls: when a page marks itself members-only it stops, and `RECAP_URL_FORCE=1` only skips the checks, so it summarizes whatever text the site returned.

## Repository contents

- `recap.zsh` — the shell functions
- `Modelfile.g4` — the default model definition
- `Modelfile.sum` — the optional second-opinion model
- `MANUAL.pdf` — printable reference
- `README.md` — this file
- `GETTING-STARTED.md` — a step-by-step guide for people new to Terminal
- `samples/` — short fictional texts for trying the copied-text commands
- `LICENSE` — the MIT license
- `CHANGELOG.md` — what changed in each version
- `CONTRIBUTING.md` — how to report a problem or send a change
- `SECURITY.md` — how to report a security problem privately
- `.github/` — issue and pull request templates
- `.gitignore` — files git should skip

## Contributing and security

Bug reports and ideas are welcome. See `CONTRIBUTING.md` for how to report a problem or send a change, and for the project's conventions. Please do not paste private text into a public issue. Security problems are reported privately: see `SECURITY.md`. Changes between versions are listed in `CHANGELOG.md`.

## License and support

MIT, see `LICENSE`. Provided as is, without warranty of any kind.

It is maintained on a best-effort basis. Bug reports are welcome, but replies and fixes are not guaranteed.
