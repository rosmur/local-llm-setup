# Local LLM Setup

[![Documentation](https://img.shields.io/badge/docs-docmd-blue?style=flat-square)](https://rosmur.github.io/local-llm-setup/)

This repo contains scripts and resources to set up local LLMs and AI on macOS, Linux, and Windows.

**Use AI freely — Your terms, your rules, no account, no API key, no subscription, and none of your information is sent to anybody else's computers.**

---

## Quick Install

Copy and paste this into your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/rosmur/local-llm-setup/main/setup-local-llm.sh)"
```

The script prompts you before every change, detects work already done, and is safe to re-run.

---

## What you get

| Piece | What it is |
|---|---|
| **llama.cpp** | The engine that runs AI models on your own hardware |
| **A model** | The AI itself — pick from a menu of open-weight models |
| **pi** | A coding assistant that lives in your terminal |
| **pi-llama plugin** | Connects pi to the model served by `llama serve` automatically |

Everything is free, open-source, and runs fully offline after setup.

---

## Documentation

Full documentation is available at **[https://rosmur.github.io/local-llm-setup/](https://rosmur.github.io/local-llm-setup/)**

| Page | What's there |
|---|---|
| [Quick Start](https://rosmur.github.io/local-llm-setup/quick-start/) | Install options, what to expect, and what happens step by step |
| [Requirements](https://rosmur.github.io/local-llm-setup/requirements/) | What you need before running the script |
| [What's Installed](https://rosmur.github.io/local-llm-setup/whats-installed/) | Exact paths, files, and how it all connects |
| [Model Choices](https://rosmur.github.io/local-llm-setup/model-choices/) | The three models offered and how to pick one |
| [Usage](https://rosmur.github.io/local-llm-setup/usage/) | How to start the engine and use the assistant |
| [Manual Installation](https://rosmur.github.io/local-llm-setup/script-manual/) | Every command explained step by step |
| [Troubleshooting](https://rosmur.github.io/local-llm-setup/TROUBLESHOOTING/) | Common issues and known caveats |
| [Uninstallation](https://rosmur.github.io/local-llm-setup/uninstallation/) | Commands to remove everything |
| [Glossary](https://rosmur.github.io/local-llm-setup/glossary/) | QAT, MoE, GGUF, context window, and other terms |

---

## Project structure

```
├── setup-local-llm.sh      # The setup script — run this
├── docs/                   # docmd documentation source
│   ├── index.md
│   ├── quick-start.md
│   ├── whats-installed.md
│   ├── requirements.md
│   ├── model-choices.md
│   ├── usage.md
│   ├── uninstallation.md
│   ├── script-manual.md
│   ├── TROUBLESHOOTING.md
│   └── glossary.md
├── docmd.config.json      # docmd site configuration
├── package.json           # Node dependencies + scripts (dev/build/validate)
├── .github/
│   └── workflows/
│       └── deploy-docs.yml # GitHub Pages deployment
```

---

## Contributing

Contributions are welcome. Please see the full documentation site for details.
