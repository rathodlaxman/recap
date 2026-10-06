# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and version numbers follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-06

First public release.

### Added

- Summaries of copied text: `recap` (with `short`, `changes` and your own focus), `recaplong` for long texts, `recapall` for several articles at once, `recapc` to copy the result, and `recapmail` for emails. One model, `gemma4-sum`, does every job; `RECAP_MAIL_MODEL` can give `recapmail` a different one.
- `recapurl` and `recapurls`: summarise a web article, a YouTube video's captions, or a PDF (an address or a file on the Mac), one or several at a time, with `--single` or `--separate` output.
- Every command that takes text also accepts a file or a pipe: `recap < file.txt`, `cat file.txt | recap`. With nothing given, it reads the clipboard. `recapc` accepts a mode and a file too.
- A clear message when the clipboard holds a command instead of text (for example after copying `recap` from a web page), and how to fix it.
- Checks that stop instead of summarising a paywall notice, an error page, a scanned PDF, or text over 10,000 words.
- `recapsetup`, a one-time setup that installs the Python packages in a private environment and downloads and builds the summarising model, and `recapdoctor`, which checks the whole setup. `recap version` shows the version.
- Summaries are saved as Markdown in `~/Summaries`, with the source text kept beside them for address runs.
- A README with a quick start and an example for every feature, a step-by-step `GETTING-STARTED.md` for people new to Terminal, a printable MANUAL, and a `samples` folder of short fictional texts so every copied-text command can be tried in seconds.

### Known limitations

- macOS only (it uses `pbcopy`, `pbpaste` and `zsh`). Tested on one MacBook Air M1 with 8 GB of RAM. Other Macs and macOS versions are untested.
- Summaries come from a small local model and can be wrong in meaning, for example dropped hedges, wrong attribution, swapped figures, or a reversed argument in long texts. See "Known weaknesses" in the README.
- YouTube captions use an unofficial library that can stop working at any time.
- PDF text from two-column pages, tables and footnotes can come out jumbled. Scanned PDFs cannot be read.
- Not audited or certified for sensitive or regulated use.
