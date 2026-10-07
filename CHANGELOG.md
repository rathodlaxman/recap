# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and version numbers follow [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-10-07

### Added

- **Duplicates skipped.** `recapurl` and `recapurls` treat the same page as one even when it has tracking parameters, `www.`, `http`, a trailing slash or a `#` part, or when a YouTube video is given as `youtu.be/…`, `watch?v=…` or `shorts/…`. The same file given two ways counts once too. Skipped duplicates are listed.
- **Author and clean source.** Under the heading, `Source:` shows the cleaned address, and a second line shows `Author: … | Site: …` (or `Channel: … | Site: youtube.com` for YouTube) when they can be found.
- **A notification and sound when a run ends.** Add `--notify` to a summarizing command, or set `RECAP_NOTIFY=1`. It fires only for runs longer than `RECAP_NOTIFY_AFTER` seconds (20), once per batch, with a warning sound if something failed. `RECAP_NOTIFY_SOUND` changes the sound.
- **Remembers what you summarized.** An address you already summarized shows the saved summary instead of running again. `--again` redoes it, and a mode or focus text always runs.
- **`recapfind`** searches your saved summaries (every word must appear, capital letters do not matter, newest first). `--max N` and `--sources` adjust it.
- **Folders of PDFs.** `recapurl FOLDER` summarizes every PDF directly inside the folder.
- **PDF author and file name.** For a PDF, `Author:` is read from a "by …" or "Prepared by …" line on page 1 (never from the PDF's metadata), and a PDF on your Mac shows `File: name.pdf`. A first line that looks like a document code, such as "IIMA/ BP0370," is no longer used as the heading: the file name is.
- **Flags after the addresses.** `--again`, `--notify`, `--single` and `--separate` now work after the addresses too, for example `recapurl "https://…" --again`. Before, a flag in that position was passed to the model as a focus text.

### Fixed

- Giving `recapurl` a folder used to print a misleading "No response from the site." A missing path now says "File not found," and a text file gets a pointer to `recap < file.txt`.
- The check for an empty summary now ignores the new author and site lines.

## [1.0.1] - 2026-10-07

### Fixed

- Recap now starts Ollama itself when it is not running, for example after a restart. Before, it fetched the page and then failed with "could not connect to ollama server." It opens the Ollama app hidden if the app is installed, otherwise it runs `ollama serve`, waits up to 30 seconds, and says what it is doing. `recapsetup` does the same.
- Recap no longer saves an empty summary (only a heading and a source line) when the model returns nothing. It says "No summary was produced" and saves nothing. In a batch of addresses, that address now counts as failed.

### Changed

- All documentation and on-screen messages now use US English (summarize, license, behavior, organization, gray), and dates in the documentation are written like "Oct 7, 2026." The summarizing prompts use the US spelling too.
- `recapdoctor` now says that Recap commands start Ollama automatically.

### Added

- Install with Homebrew: `brew install rathodlaxman/tap/recap` (the formula lives in the separate `homebrew-tap` repository). The README and MANUAL explain it, including Homebrew's tap trust, upgrading and removing.

## [1.0.0] - 2026-10-06

First public release.

### Added

- Summaries of copied text: `recap` (with `short`, `changes` and your own focus), `recaplong` for long texts, `recapall` for several articles at once, `recapc` to copy the result, and `recapmail` for emails. One model, `gemma4-sum`, does every job; `RECAP_MAIL_MODEL` can give `recapmail` a different one.
- `recapurl` and `recapurls`: summarize a web article, a YouTube video's captions, or a PDF (an address or a file on the Mac), one or several at a time, with `--single` or `--separate` output.
- Every command that takes text also accepts a file or a pipe: `recap < file.txt`, `cat file.txt | recap`. With nothing given, it reads the clipboard. `recapc` accepts a mode and a file too.
- A clear message when the clipboard holds a command instead of text (for example after copying `recap` from a web page), and how to fix it.
- Checks that stop instead of summarizing a paywall notice, an error page, a scanned PDF, or text over 10,000 words.
- `recapsetup`, a one-time setup that installs the Python packages in a private environment and downloads and builds the summarizing model, and `recapdoctor`, which checks the whole setup. `recap version` shows the version.
- Summaries are saved as Markdown in `~/Summaries`, with the source text kept beside them for address runs.
- A README with a quick start and an example for every feature, a step-by-step `GETTING-STARTED.md` for people new to Terminal, a printable MANUAL, and a `samples` folder of short fictional texts so every copied-text command can be tried in seconds.

### Known limitations

- macOS only (it uses `pbcopy`, `pbpaste` and `zsh`). Tested on one MacBook Air M1 with 8 GB of RAM. Other Macs and macOS versions are untested.
- Summaries come from a small local model and can be wrong in meaning, for example dropped hedges, wrong attribution, swapped figures, or a reversed argument in long texts. See "Known weaknesses" in the README.
- YouTube captions use an unofficial library that can stop working at any time.
- PDF text from two-column pages, tables and footnotes can come out jumbled. Scanned PDFs cannot be read.
- Not audited or certified for sensitive or regulated use.
