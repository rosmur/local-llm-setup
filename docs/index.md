---
title: Home
description: Run local LLMs on your machine — fully offline, no account, no API key. One curl command sets everything up.
---

# Local LLM Setup

**Use AI freely — Your terms, your rules, no account, no API key, no subscription, and none of your information is sent to anybody else's computers.**

## Quick Install

Run this in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rosmur/local-llm-setup/main/setup-local-llm.sh)"
```

The script prompts you before every change, detects work already done, and is safe to re-run.

## What this sets up

Four pieces, installed in order, each one needed by the next:

| Piece | What it is |
|---|---|
| **llama.cpp** | Software that runs AI models on your own hardware |
| **A model** | The AI itself — a multi-gigabyte file you choose from a menu |
| **pi** | A coding assistant that lives in your terminal |
| **pi-llama plugin** | Connects pi to the model served by `llama serve` automatically |
