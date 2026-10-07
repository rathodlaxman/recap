# Getting started with Recap

This guide is for people who have never used Terminal. Follow the steps in order. You do not need to understand them to make them work. If something goes wrong, jump to "If something goes wrong" at the end.

**What Recap does.** You give it an article, a web page, a YouTube video or a PDF, and it writes a short summary for you. The summarizing happens on your own Mac, using an AI model that you download once. It is not an app with windows and buttons: you use it by typing short commands in a program called Terminal.

**What you need**

- A Mac. Recap was tested on a MacBook Air M1 with 8 GB of memory; other Macs have not been tested.
- An internet connection for the first-time setup.
- About 10 GB of free disk space, to be safe. The model alone is about 4.6 GB.
- Time. Most of the first-time wait is the model download, which depends on your internet speed. Keep the Mac awake and plugged in.

**Already use Homebrew?** There is a shorter route: see "Install with Homebrew" in the README. This guide uses the plain download, which works for everyone.

## Step 1. Install Ollama

Ollama is the program that runs the AI model on your Mac.

1. Open your web browser and go to **ollama.com**.
2. Click the download button for macOS and open what you download.
3. If it asks to move Ollama to the Applications folder, say yes. Then open **Ollama** from the Applications folder. If macOS asks whether you are sure you want to open an app from the internet, click **Open**.
4. If Ollama offers to install its "command line" tool, say yes. macOS may ask for your Mac's password.
5. Leave Ollama running. It normally shows a small icon in the bar at the top of the screen.

## Step 2. Download Recap

1. In your web browser, go to **github.com/rathodlaxman/recap**.
2. Click the green **Code** button, then **Download ZIP**.
3. Open your **Downloads** folder and double-click the ZIP file. A folder named **recap-main** appears.
4. Move that folder somewhere it will stay, for example into your **Documents** folder. Do not delete it later: Recap runs from it.

## Step 3. Open Terminal

1. Press **Command + Space**. A search box opens.
2. Type **Terminal** and press **Return**.
3. A window opens with a line of text that ends in a **%** sign. That is where you type.

**How to use the commands in this guide:** each command is in a gray box. Select the text in the box, copy it (**Command + C**), click in the Terminal window, paste it (**Command + V**), and press **Return**.

**One important exception.** Copying a command replaces whatever was on your clipboard. So whenever a step tells you to copy some text first (such as an article), **type the command yourself** instead of copying it from this page. Otherwise Recap finds your command, not your article. (The steps that give Recap a file with `<` do not have this problem.)

## Step 4. Go to the Recap folder

1. In Terminal, type the letters `cd` and then a **space**. Do not press Return yet.
2. In Finder, drag the **recap-main** folder into the Terminal window. Its location is typed in for you.
3. Press **Return**.
4. To check, type this and press Return:

```
ls
```

You should see a list of files that includes **recap.zsh**. If you do not, repeat this step.

## Step 5. Switch Recap on

Run these two commands, one at a time. The first adds one line to a settings file so Terminal knows about Recap every time it opens. The second loads it right now. You only need to do this once.

```
echo "source $PWD/recap.zsh" >> ~/.zshrc
```

```
source ~/.zshrc
```

Check that it worked:

```
recap version
```

You should see **Recap 1.1.0**.

## Step 6. Run the one-time setup

```
recapsetup
```

What to expect:

- **macOS may open a window about "command line developer tools."** This is normal. Click **Install**, wait until it finishes (it can take a while), and then run `recapsetup` again.
- Recap installs some helper software in its own private folder. This takes about a minute.
- Then it downloads the AI model. You will see progress bars. **This is the long part.** Keep the Mac awake and connected to the internet. If it stops, run `recapsetup` again.
- It ends with **Setup is complete.** If it says Ollama is not installed, install it (Step 1) and run `recapsetup` again. If Ollama is not running, Recap starts it for you. If it says it did not start in time, open the Ollama app yourself, wait a few seconds, and run `recapsetup` again.

## Step 7. Check that everything is fine

```
recapdoctor
```

You should see lines starting with **ok** and the result **all checks passed**. A line starting with **PROBLEM** says what to fix.

## Step 8. Your first summary

The Recap folder contains a **samples** folder with short texts, so your first result comes quickly and needs no internet. This tells Recap to read a sample news story and summarize it. You are still in the Recap folder from Step 4, so type:

```
recap < samples/sample-article.txt
```

The `<` means "read from this file." You will see a few messages, and then the summary, usually within a minute. The summary is also saved: open **Finder**, choose **Go**, then **Home**, and look in the **Summaries** folder.

Now try a shorter version of the same text:

```
recap short < samples/sample-article.txt
```

## Step 9. A web page

This summarizes a short article from the internet (about 1,100 words, so allow about a minute):

```
recapurl "https://collabfund.com/blog/ideas-that-changed-my-life/"
```

Type the quote marks as plain straight marks (`"`). If you copy a command from Word, Notes or WhatsApp, the quote marks can turn curly and the command will not work.

Very long pages take many minutes, and pages over 10,000 words are refused with a message. Wikipedia articles are often long, so they are not good first tries.

## Step 10. Text you copy yourself

1. Open any article and select all the text (**Command + A**).
2. Copy it (**Command + C**).
3. Go to Terminal and **type** the command yourself. Do not copy it from this page: that would replace the article you just copied.

```
recap
```

If your text is in a file instead, give Recap the file: `recap < myfile.txt`.

## Everyday cheat sheet

| What you want | What to type |
| --- | --- |
| Summarize the text you copied | `recap` |
| Summarize a text file | `recap < myfile.txt` |
| A shorter summary | `recap short` |
| A summary about one thing | `recap "focus on the costs"` |
| Summarize a very long text | `recaplong` |
| A circular or rule change | `recap changes` |
| An email | `recapmail` |
| Several articles at once (a line with only `@@@@` between them) | `recapall` |
| Summarize a web page | `recapurl "https://..."` |
| Summarize several pages | `recapurl "https://..." "https://..."` or `recapurls "https://..." "https://..."` |
| Summarize a list of addresses you copied (one per line) | `recapurls` |
| Summarize a YouTube video | `recapurl "https://www.youtube.com/watch?v=..."` |
| Summarize a PDF address | `recapurl "https://.../file.pdf"` |
| Summarize a PDF file on your Mac | `recapurl ` and then drag the file into Terminal |
| Summarize every PDF in a folder | `recapurl ` and then drag the folder into Terminal |
| Find something in your saved summaries | `recapfind word` (more words narrow it down) |
| Get a notification when a long run ends (off unless you ask) | add `--notify`, for example `recapurl --notify "https://..."`, or put `export RECAP_NOTIFY=1` in `~/.zshrc` to get it every time |
| Check that everything works | `recapdoctor` |
| See which version you have | `recap version` |

## If something goes wrong

| What you see | What to do |
| --- | --- |
| "The clipboard holds a command, not an article," or "Only 1 words found" (a very small number) | Almost always you copied the command after copying the article, and the command replaced the article. Copy the article again, then **type** `recap` (do not copy it). Or skip the clipboard and give Recap the file: `recap < myfile.txt`. |
| `command not found: recap` | Recap is not switched on in this window. Type `source ~/.zshrc`. If that does not help, repeat Steps 4 and 5. |
| `no matches found` or strange errors with an address | The quote marks are missing or curly. Put the address in plain straight quotes `"`. |
| "Ollama is not running. Starting it now..." | Normal, for example after a restart. Recap starts Ollama and carries on. Nothing to do. |
| "Ollama did not start in time" | Open the Ollama app yourself (Step 1), wait a few seconds, and try again. |
| "Already summarized on …" | Normal. You summarized that address before, so Recap shows the saved summary instead of starting again. To make a new one, add `--again`, for example `recapurl --again "https://..."`. |
| "Skipped 1 duplicate address" | Normal. You gave the same page twice (perhaps with different tracking parts), so it is summarized once. |
| "No summary was produced" | The model returned nothing, so nothing was saved. Run `recapdoctor`, then try again. |
| The model download stopped or failed | Check your internet connection and run `recapsetup` again. |
| "That is N words: too long" | Choose a shorter page, or copy part of the text and use `recaplong`. |
| "The page marks its article as paywalled" or "HTTP 403" | The site does not allow automatic reading. Copy the text yourself and use `recap`. |
| macOS asks about "command line developer tools" | Click **Install**, wait, and run the command again. |
| It worked before, but now says `command not found` | You may have moved or deleted the recap-main folder. Put it back, or repeat Steps 4 and 5. To remove the old line, type `open -e ~/.zshrc`, delete the line that starts with `source` and mentions recap.zsh, save, and close. |
| The summary looks wrong | Summaries can be wrong. Always check the original before relying on one, especially names, numbers and who said what. |

**Still stuck?** Run `recapdoctor` and look at what it says. If you report a problem on the project's GitHub page (the Issues tab), include its output, but **do not paste private or confidential text**: issues are public.

## Words used in this guide

- **Terminal:** a program on your Mac where you type commands.
- **Command:** a short instruction you type, followed by Return.
- **Folder location (path):** where a folder lives on your Mac. Dragging a folder into Terminal types it for you.
- **Model:** the AI program that writes the summaries. It runs on your Mac and is downloaded once.
- **Quote marks:** the plain straight marks `"` around an address.

## What stays on your Mac

Summarizing copied text and PDF files already on your Mac never leaves the Mac. Commands that take a web address download that page from its website first. Everything Recap saves in the Summaries folder is ordinary text that anyone using your Mac can read. See the README for details, including a note about sensitive material.
