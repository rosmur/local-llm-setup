---
title: Manual Installation
description: Step-by-step terminal commands to install llama.cpp, models, and pi manually without the setup script.
---

# Manual Installation

Manual installation is recommended if you:

- Are familiar with the terminal, bash, config files, etc.
- Wish to install only a subset of items
- Want modifications not supported by the script, like alternate models
- Are using a container (docker, podman etc.)

## Step 1 — LLM Running Software (Inference Engine) - llama.cpp

If you have homebrew installed:

```bash
brew install llama.cpp
```

or install directly with llama.cpp's install script:

```bash
curl -LsSf https://llama.app/install.sh | sh
```

NOTE: Recent builds of llama.cpp provide a unified `llama` command (`llama cli`, `llama serve`, `llama --version`).

## Step 2 — Model

Model weights (the actual stuff that comprises of the LLM) can be downloaded from https://huggingface.co. This website is the de facto place that all companies use to share their models.

Choose a model from the choices [here](model-choices.md)


Each of the above have several flavors when you search HF. Recommend  

- Using quantized versions a.k.a quants. 4-bit (Q4_K_M) quantization is a happy medium that preserves accuracy reasonably while being small. 
- Use quants from either official sources (google, Qwen etc.) or from unsloth/bartwoski (the latter two are independent developers but have been in the ecosystem from the start in 2023 and are reliable, trusted sources)

To get and use the model:

1) Click on the quantization of your choice. 
2) Click the "Use this model button" towards the top right in the sidebar that opens.
3) Copy the llama serve... command (second line)
4) Paste into a new terminal tab and hit enter
5) The model will start downloading and will be served (will be live) after the download completes
6) To use in the future, simply run the same command again (it will not re-download as the model is saved to your hard disk. Defaults to the cache folder)

## Step 3 — Agent - pi

Follow the installation process here: https://pi.dev/

The direct install script command is copied here for convenience: 

```bash
curl -fsSL https://pi.dev/install.sh | sh
```

::: collapsible "Notes on the installer"
Step 3 pipes a remote script into a shell. That deserves scrutiny, so here is what `pi.dev/install.sh` does, from reading it:

- **Node.js.** Requires ≥ 22.19.0. If missing or too old it asks, then uses `brew install node` when Homebrew exists (macOS). Without Homebrew it downloads a Node 22 tarball from `nodejs.org` and verifies it against the published `SHASUMS256.txt` before extracting.
- **Interactivity.** It opens `/dev/tty` explicitly for its prompts, which is why piping into `sh` doesn't break it. It shows you the exact `npm` command it intends to run and offers install / uninstall / do-nothing. Choosing "do nothing" exits cleanly.
- **What it runs.** By default: `npm install -g --ignore-scripts --min-release-age=0 @earendil-works/pi-coding-agent`. An alternative pinned-dependency path exists but is gated behind an environment variable and is off by default.
- **Privileges.** No `sudo` on macOS. The `sudo` calls in the file are confined to the Linux `apt`/`apk` branches.
- **Writes.** npm's prefix or `~/.local`, plus `~/.local/share/pi-node`, plus temp files. Its one edit to your shell profile is prompted and checks for a duplicate line first.
- No `eval`, no telemetry, no credential access.

To read it yourself before running anything:

```bash
curl -fsSL https://pi.dev/install.sh | less
```
:::

## Step 4 — connect pi to your local model

### Step 4a — the pi-llama plugin

pi auto-discovers the model served by `llama serve`:

```bash
pi install git:github.com/huggingface/pi-llama
```

### Step 4b — start the model server

Run the server in its own terminal tab/window and leave it running:

```bash
llama serve
```

`llama serve` starts the local server on `127.0.0.1:8080`. The pi-llama plugin finds it automatically. If you skipped the model download, the first `llama serve` run fetches the weights for you.


## Everything is set! Run Pi

To start pi, simply type:

`pi`

in the terminal. Recommend changing directory (`cd path/to/folder`) to a specific project or new folder and then starting `pi`
