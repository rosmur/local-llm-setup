---
title: What's Installed
description: The pieces the setup script installs — llama.cpp, a model, pi, and the pi-llama plugin — and where they live on your machine.
---

# What's installed

Four pieces, installed in order, each one needed by the next:

| Piece | What it is | Why it's here |
|---|---|---|
| **llama.cpp** | Software that runs AI models on your own hardware | This is the engine |
| **A model** | The AI itself — a multi-gigabyte file you choose from a menu | This is the brain |
| **pi** | A coding assistant that lives in your terminal | This is the part you talk to |
| **pi-llama plugin** | Connects pi to the model served by `llama serve` | This is the wiring — no manual config needed |

On macOS, llama.cpp is installed via Homebrew (or the official direct installer); on Linux and Windows it uses the official direct installer. There is no separate Homebrew step anymore.

## How they connect

```mermaid
flowchart TD
    User@{ shape: manual-input, label: "User Input"}
    Pi["`**pi** — the agent`"]
    Server["`**llama-server** — runs the AI (part of llama.cpp)`"]
    AIModel["`the **LLM model** — a file sitting on your disk`"]

    User --> Pi
    Pi -- "talks over the local API" --> Server
    Server -- "serves" --> AIModel
```

## Exact paths and files

<div class="grid cards" markdown>

-   **llama.cpp** — Homebrew (`<brew prefix>/bin/llama-server`, `llama-cli`) on macOS, or the official direct installer (`~/.local/bin`, `~/.local/share/llama.cpp`) elsewhere
-   **Model weights** — `~/.cache/huggingface/hub/`
-   **pi-llama plugin** — managed by pi; no manual config file
-   **pi program** — npm's global prefix, or `~/.local`
-   **Private Node.js** — `~/.local/share/pi-node/` (only if no suitable Node)
-   **Shell profile** — one appended `export PATH=...` line (only after asking you)

</div>

### Not touched

System files, login items, launch agents, browser data, SSH keys, credentials. Nothing runs at startup. Nothing phones home.
