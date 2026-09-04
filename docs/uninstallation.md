---
title: Uninstallation
description: Commands to remove everything the setup script installed — pi, llama.cpp, models, and config.
---

# Uninstallation

Run the following commands to uninstall/remove everything that was set up:

```bash
npm uninstall -g @earendil-works/pi-coding-agent   # remove pi
pi uninstall git:github.com/huggingface/pi-llama   # remove the pi-llama plugin
brew uninstall llama.cpp                          # remove the engine (macOS / Homebrew)
rm -rf ~/.cache/huggingface/hub                    # reclaim the model files (the big one)
rm -rf ~/.cache/llama.cpp                          # older llama.cpp builds cached here instead
rm -rf ~/.pi                                       # remove pi's config and saved sessions
```

On Linux or Windows (where llama.cpp was installed via the official direct installer), remove the engine with `rm -rf ~/.local/share/llama.cpp ~/.local/bin/llama` instead of `brew uninstall llama.cpp`.

Homebrew itself is left in place, since you may have other things depending on it.
