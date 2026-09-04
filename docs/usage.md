---
title: Usage
description: How to start the local LLM engine and use the pi coding assistant — two terminal windows, one command each.
---

# Usage

You need **two terminal windows**, because the engine has to keep running while you work.

## Window 1 — Start the engine

Start the engine and leave it running:

```bash
llama serve
```

The first run may pause a while as the model loads into memory — or, if you chose to skip the download during setup, it downloads the model first and then starts.

## Window 2 — Start the assistant

Go to whatever folder you want help with, and start the assistant:

```bash
cd ~/my-project
pi
```

The **pi-llama plugin** installed during setup makes pi auto-discover your local model, so it usually appears automatically. If it doesn't, press **Ctrl+L** (or type `/model`) and select your local model from the list.

## When you're done

Close window 2, then press `Ctrl-C` in window 1 to shut the engine down and free up your memory.

::: callout warning "A word of caution about coding assistants generally"
`pi` can read your files, write to them, and run commands on your machine. That is what makes it useful, and it is also a real risk — a confused model can delete or overwrite things. Use it in folders tracked by version control (`git`), so any mistake can be undone. This applies to every tool of this kind, not just this one.
:::
