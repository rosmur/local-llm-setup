# Usage

You need **two terminal windows**, because the engine has to keep running while you work.

## Window 1 — Start the engine

Start the engine and leave it running:

```bash
~/bin/llama-serve-<model-name>.sh
```

(The script tells you the exact filename when it finishes.) The first run may pause a while as the model loads into memory.

## Window 2 — Start the assistant

Go to whatever folder you want help with, and start the assistant:

```bash
cd ~/my-project
pi
```

Inside `pi`, press **Ctrl+L** (or type `/model`) and select your local model from the list.

## When you're done

Close window 2, then press `Ctrl-C` in window 1 to shut the engine down and free up your memory.

!!! warning "A word of caution about coding assistants generally"

    `pi` can read your files, write to them, and run commands on your Mac. That is what makes it useful, and it is also a real risk — a confused model can delete or overwrite things. Use it in folders tracked by version control (`git`), so any mistake can be undone. This applies to every tool of this kind, not just this one.
