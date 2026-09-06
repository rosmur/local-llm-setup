---
title: Home
description: Run local LLMs on your machine — fully offline, no account, no API key. One curl command sets everything up.
---

# Local LLM Setup

**Own your own AI, completely free. Your terms, your rules, no account, no API key, no subscription, and none of your information is sent to someone else.**

## Automated Install

Simply run this in your terminal and it will handle the full installation

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rosmur/local-llm-setup/main/setup-local-llm.sh)"
```

The script 

- Tells you what its doing
- Asks for your approval before every install/change
- Detects existing setup and/or work already done, and is safe to re-run.

### What this sets up

Four items are installed, each one needed by the next:

| Piece | What it is |
|---|---|
| **llama.cpp** | Software that runs AI models on your own hardware |
| **A model** | The AI itself — a multi-gigabyte file |
| **pi** | An agentic "harness" that works in the terminal |
| **pi-llama plugin** | Connects pi to the model served by `llama serve` automatically |

### Manual Install

If you prefer to install each item manually, please see the steps [here](manual-installation.md)
