# Sample texts

Short texts for trying Recap's copied-text commands. They are fictional and were written for Recap's examples, so any names, places and figures in them are made up. They are free to use under the same MIT license as the rest of the project.

Run these from the Recap folder. The `<` tells Recap to read a file, so you do not need the clipboard.

| File | Try it with | About |
| --- | --- | --- |
| `sample-article.txt` | `recap < samples/sample-article.txt`, and also `recap short`, `recap "focus on the costs"`, `recapc` | A short news story (about 280 words) |
| `sample-circular.txt` | `recap changes < samples/sample-circular.txt` | A short circular that changes an earlier one |
| `sample-email.txt` | `recapmail < samples/sample-email.txt` | A short email with a task and a deadline |
| `sample-batch.txt` | `recapall < samples/sample-batch.txt` | Two short articles separated by a line with only `@@@@` |

Example:

```sh
recap < samples/sample-article.txt
```
