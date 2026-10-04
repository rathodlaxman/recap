# Recap

A local, offline article summariser for macOS. Copy an article, type one word, read the gist.

Everything runs on the machine through [Ollama](https://ollama.com) — no article text leaves the laptop, and it works without a network connection. Built and tuned on a MacBook Air M1 with 8 GB of RAM.

## What it does

| Command | What it does |
| --- | --- |
| `recap` | Adaptive summary of whatever is on the clipboard: gist, main points, and "Worth noting" only if there is more |
| `recap short` | One sentence plus up to three takeaways |
| `recap changes` | For circulars and rule changes: which clauses are new, which are unchanged, who acts and from when |
| `recap "focus on costs"` | Summary with a focus you choose |
| `recaplong` | Long articles and transcripts — reads the text in parts, then combines. Slower but far more accurate |
| `recapall` | Several articles in one run, separated by lines containing only `@@@@` |
| `recapc` | Same as `recap`, and also copies the summary to the clipboard |
| `recapmail` | Short email summary: sender, tasks, deadlines, whether a reply is needed |
| `recap help` | Lists the options |

Every summary is written as Markdown to `~/Summaries/YYYY-MM-DD-title.md` and printed on screen.

## Setup

Install Ollama, then build the model:

```sh
ollama pull gemma4:e2b
printf 'FROM gemma4:e2b\nPARAMETER num_ctx 12288\nPARAMETER temperature 0.2\n' > ~/Modelfile.g4
ollama create gemma4-sum -f ~/Modelfile.g4
```

Add the functions to the shell:

```sh
cat recap.zsh >> ~/.zshrc
source ~/.zshrc
recap help
```

`recapmail` additionally needs `ollama pull llama3.2:3b`.

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

Use a different model for a single run with `RECAP_MODEL=gemma-sum recap`. Override the output folder with `RECAP_DIR`, and the chunk size used by `recaplong` with `RECAP_CHUNK` (default 1200 words).

## Length limits

The context window holds roughly 7,000 words, but accuracy can fall before that ceiling. Measured against the source texts:

| Article length | Behaviour |
| --- | --- |
| Up to ~1,500 words | Reliable. Figures, names and attribution generally correct |
| 1,500-4,500 words | Mostly good (a 4,400-word essay and a 1,200-word one checked clean); occasional dropped detail |
| Above ~5,000 words | Meaning can reverse in a single pass. Use `recaplong` |

One real failure found at length: in a 5,900-word essay the single-pass summary turned "without solitude there would be no America" into "independent thinking without solitude", reversing the argument. Because that failure came from a single run, treat the thresholds above as guidance, not a measured limit. `recaplong` reads long text in roughly 1,200-word parts and combines the notes; on a 6,600-word transcript it kept every claim checked accurate, but its "Worth noting" section repeated points.

## Known weaknesses

No invented facts were found in the summaries checked, but five faults repeat. Treat a summary as a map of the article, not a replacement for it.

- **Dropped hedges.** Qualifiers such as "very difficult", "possibly" or "the best explanation is" get trimmed, making claims sound firmer than the source.
- **Who said what.** A conclusion the author drew is credited to the person being quoted. Verify any "according to X" before repeating it.
- **New versus unchanged rules.** In circulars, existing clauses can appear as if they were the changes. Use `recap changes`, then read the clauses it names.
- **Flattened names.** "A journalist" or "a report" in place of the named person or publication.
- **Figures.** A number belonging to one scenario can migrate to another.

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
