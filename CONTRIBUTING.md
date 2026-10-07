# Contributing to Recap

Thank you for thinking about it. Recap is a small project maintained by one person on a best-effort basis, so reviews can be slow and some ideas will be declined to keep it simple. Bug reports, questions about unclear documentation and focused fixes are all welcome.

Please be respectful and patient with everyone in issues and pull requests. Treat others as you would like to be treated.

## Reporting a bug

Open an issue and fill in the template. The most useful things are:

- the exact command you ran and the message you saw
- the output of `recap version` and `recapdoctor`
- whether it happens with a public article, so it can be reproduced

**Do not paste private or confidential text into an issue.** Issues are public. If the problem only happens with private text, describe it and try to reproduce it with a public article.

Report security problems privately, as described in `SECURITY.md`.

## Suggesting a feature

Open an issue and describe the problem you are trying to solve before the solution. Small, focused features that fit the existing commands are more likely to be accepted.

## Sending a change

1. Fork the repository and create a branch for one change.
2. Make the change in `recap.zsh` (and the README or MANUAL if behavior changes).
3. Check your change (see below).
4. Open a pull request and say what changed, why, and how you tested it.

Keep each pull request to one thing. A small change is easier to review and more likely to be merged.

### Checking your change

There is no automated test suite yet, so please check by hand:

- `zsh -n recap.zsh` must print nothing.
- Run `source recap.zsh`, then `recapdoctor`.
- Run each command your change touches on a sample text, and say what you ran in the pull request.

### Conventions

- Recap is zsh on macOS only. It uses `pbcopy` and `pbpaste`.
- Helper functions start with `_recap_`. Messages shown on screen go through `_recap_msg`, so spacing stays consistent.
- Do not add a runtime dependency without opening an issue first. The address commands use only the packages installed by `recapsetup`.
- **The summarizing prompt (`_recap_prompt`) is deliberately short.** A much longer prompt gave worse results in testing. If you propose a change to it, show before and after summaries of the same texts, with the source text, so the effect can be judged.
- Do not commit saved summaries, source texts, or anyone's private text. Use your own writing or public-domain text for examples.
- Do not include copyrighted articles in the repository.

## Questions

If something in the README or MANUAL is unclear, that is a documentation bug. Please open an issue.
