---
title: Requirements
description: What you need before running the setup — a Mac, disk space, RAM, patience, and an internet connection for the download.
---

# Requirements

- **macOS, Linux, or Windows.** The script auto-detects your OS. On macOS it can install llama.cpp via Homebrew or the official direct installer; on Linux and Windows it uses the official direct installer. No Homebrew is required.
- **Disk space.** Between 5 GB and 20 GB depending on which model you pick.
- **Memory (RAM).** This is the one that actually matters. The script prints how much memory your machine has and shows the download size of each option next to it. As a rough rule, the model should be comfortably smaller than your RAM. Choosing a model that's too big won't break anything, but it will be painfully slow.
- **Patience for one step.** The model download is several gigabytes. It can take anywhere from a few minutes to over an hour.
- **An internet connection** — but only during setup. Afterwards, the assistant works offline.

You can also choose **skip** at the model step and install nothing yet — steps 3 and 4 still run, and `llama serve` downloads a model on its first run.

Then read each prompt and answer `y` or `n`. That's the whole thing.
