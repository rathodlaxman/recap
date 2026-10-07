# Security policy

## Supported versions

Only the latest release is supported. Please check that a problem still happens in the latest release before reporting it.

## Reporting a vulnerability

Please report security problems **privately**, not as a public issue.

Use GitHub's private vulnerability reporting: open this repository's **Security** tab and choose **Report a vulnerability**. Include what you found, how to reproduce it, and what you think the impact is.

Recap is maintained by one person on a best-effort basis. There is no guaranteed response time, but reports are read and taken seriously.

## What counts

Recap is a set of zsh functions that run on your own Mac. Problems in Recap itself are in scope, for example:

- text, a file name or an address that makes Recap run a command it should not, or write a file where it should not
- Recap sending data somewhere it should not
- a saved file or the clipboard exposing something the documentation says it will not

## What does not count

- Problems in Ollama, in a model, or in a Python package. Report those to their own projects.
- Summaries that are wrong or misleading. That is a known limitation (see "Known weaknesses" in the README), not a vulnerability. Ordinary bug reports are welcome as normal issues.
- Using Recap on material that your organization does not allow. Recap is not audited or certified, and nothing here is a claim that it meets any security or compliance requirement.

## Things to know before you rely on it

- Everything Recap saves is plain, unencrypted text (see "What stays on your Mac" in the README).
- Setup downloads Ollama, models and Python packages from the internet. There are no pinned or checksummed dependency versions yet, and offline installation is not documented.
