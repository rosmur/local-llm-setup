---
title: Requirements
description: What you need before running the setup — a Mac, disk space, RAM, patience, and an internet connection for the download.
---

# Requirements

| Item | Requirement or Recommendation |
|---|---|
| **Memory (RAM)** | The script prints how much memory your machine has and shows the download size of each option next to it. As a rough rule, the model should be comfortably smaller than your RAM. Choosing a model that's too big won't break anything, but it will be painfully slow. Besides the model itself, RAM is also needed for the cache while it runs |
| **Operating System** | Any (macOS, Linux, or Windows). The script auto-detects your OS. On macOS it can install llama.cpp via Homebrew or the official direct installer; on Linux and Windows it uses the official direct installer. No Homebrew required. |
| **Disk Space** | Recommended Between 5 GB and 20 GB, depending on which model you pick. |
| **Patience for one step** | The model download is several gigabytes. It can take anywhere from a few minutes to an hour depending on the quality of your connection. |
| **Internet Connection** | Needed only during setup. Afterwards, the assistant works offline. |

You can also choose **skip** at the model step and install nothing yet — steps 3 and 4 still run, and `llama serve` downloads a model on its first run.

