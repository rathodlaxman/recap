# Getting started with Recap

This guide is for people who have never used Terminal. Follow the steps in order. You do not need to understand them to make them work. If something goes wrong, jump to "If something goes wrong" at the end.

**What Recap does.** You give it an article, a web page, a YouTube video or a PDF, and it writes a short summary for you. The summarising happens on your own Mac, using an AI model that you download once. It is not an app with windows and buttons: you use it by typing short commands in a program called Terminal.

**What you need**

- A Mac. Recap was tested on a MacBook Air M1 with 8 GB of memory; other Macs have not been tested.
- An internet connection for the first-time setup.
- About 10 GB of free disk space, to be safe. The model alone is about 4.6 GB.
- Time. Most of the first-time wait is the model download, which depends on your internet speed. Keep the Mac awake and plugged in.

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

**How to use the commands in this guide:** each command is in a grey box. Select the text in the box, copy it (**Command + C**), click in the Terminal window, paste it (**Command + V**), and press **Return**.

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

You should see **Recap 1.0.0**.

## Step 6. Run the one-time setup

```
recapsetup
```

What to expect:

- **macOS may open a window about "command line developer tools".** This is normal. Click **Install**, wait until it finishes (it can take a while), and then run `recapsetup` again.
- Recap installs some helper software in its own private folder. This takes about a minute.
- Then it downloads the AI model. You will see progress bars. **This is the long part.** Keep the Mac awake and connected to the internet. If it stops, run `recapsetup` again.
- It ends with **Setup is complete.** If it says Ollama is not installed or not running, open Ollama (Step 1) and run `recapsetup` again.

## Step 7. Check that everything is fine

```
recapdoctor
```

You should see lines starting with **ok** and the result **all checks passed**. A line starting with **PROBLEM** says what to fix.

## Step 8. Your first summary

This summarises a Wikipedia page:

```
recapurl "https://en.wikipedia.org/wiki/Republic_Day_(India)"
```

Type the quote marks as plain straight marks (`"`). If you copy a command from Word, Notes or WhatsApp, the quote marks can turn curly and the command will not work.

You will see messages while Recap fetches the page and reads it. The summary appears after a while, which can be a few minutes on a slower Mac. It is also saved: open **Finder**, choose **Go**, then **Home**, and look in the **Summaries** folder.

## Step 9. Summarise text you copy

1. Open any article and select all the text (**Command + A**).
2. Copy it (**Command + C**).
3. Go to Terminal and type:

```
recap
```

## Everyday cheat sheet

| What you want | What to type |
| --- | --- |
| Summarise the text you copied | `recap` |
| A shorter summary | `recap short` |
| A summary about one thing | `recap "focus on the costs"` |
| Summarise a very long text | `recaplong` |
| Summarise a web page | `recapurl "https://..."` |
| Summarise several pages | `recapurl "https://..." "https://..."` |
| Summarise a YouTube video | `recapurl "https://www.youtube.com/watch?v=..."` |
| Summarise a PDF file | `recapurl ` and then drag the file into Terminal |
| Check that everything works | `recapdoctor` |

## If something goes wrong

| What you see | What to do |
| --- | --- |
| `command not found: recap` | Recap is not switched on in this window. Type `source ~/.zshrc`. If that does not help, repeat Steps 4 and 5. |
| `no matches found` or strange errors with an address | The quote marks are missing or curly. Put the address in plain straight quotes `"`. |
| "Ollama is installed but not running" | Open the Ollama app (Step 1), wait a few seconds, and try again. |
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

Summarising copied text and PDF files already on your Mac never leaves the Mac. Commands that take a web address download that page from its website first. Everything Recap saves in the Summaries folder is ordinary text that anyone using your Mac can read. See the README for details, including a note about sensitive material.
