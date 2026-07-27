
## 6. Step-by-step, with the actual commands

**Step 1 — Homebrew.** Checks for `brew` on `PATH`, then probes `/opt/homebrew/bin/brew` and `/usr/local/bin/brew` directly, because Homebrew can be installed without being on the current shell's `PATH`. If genuinely absent, and only with your consent:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

This is the official installer. It uses `sudo` and will ask for your Mac password. If you decline, the script stops here and changes nothing.

**Step 2 — llama.cpp.** Checks for `llama-server`. If missing:

```bash
brew install llama.cpp
```

The formula is named `llama.cpp` but installs binaries called `llama-cli` and `llama-server`.

**Step 3 — the model.** Before showing the menu, the script searches for models you already have and labels each option `[on disk: 4.6G]` or `[not downloaded, ~4.6 GB]`. Cache roots are searched in the same precedence order `llama.cpp` itself uses:

```
$LLAMA_CACHE  →  $HF_HUB_CACHE  →  $HUGGINGFACE_HUB_CACHE  →  $HF_HOME/hub
              →  ~/.cache/huggingface/hub  →  ~/.cache/llama.cpp
              →  ~/Library/Caches/llama.cpp
```

Two on-disk layouts are recognised, because recent `llama.cpp` migrated to the standard Hugging Face hub cache while older builds used a flat directory of their own: a `models--<org>--<repo>` directory, or any `.gguf` file whose name contains the model name. Sizes come from `du -sh`.

If your chosen model is already present the download is skipped. You are still offered a verification pass, which is worth taking if a previous run was interrupted — the download resumes rather than restarting.

The download itself uses `llama.cpp`'s Hugging Face integration: `-hf` fetches the weights into the cache, and generating exactly one token makes the process exit immediately afterwards. It is a download that happens to warm up the model on the way past. You can decline it and let the server download on first launch instead.

Getting it to exit cleanly takes more care than it should. `llama-cli` auto-enables conversation mode whenever the model ships a chat template — which all three of these do — and then sits at an interactive prompt waiting for you, requiring a `Ctrl-C` to escape. The documented off-switch, `-no-cnv`, is not reliable across builds. The script therefore uses three independent guards:

```bash
llama-cli -hf <repo>:<quant> -p ok -n 1 -no-cnv -st --no-warmup < /dev/null
```

- `-st` / `--single-turn` — documented as non-interactive when a prompt is supplied with `-p`
- `-no-cnv` — the legacy flag, still honoured by most builds
- `< /dev/null` — the backstop. Even if both flags are ignored, any prompt that appears receives end-of-input and the process exits.

The flags are probed against `llama-cli --help` before use, so an older or newer build that lacks one of them degrades to whichever it does support rather than aborting on an unknown argument. `stdout` is discarded; `stderr` is kept so the download progress bar stays visible.

The three repositories:

```
ggml-org/gemma-4-E4B-it-GGUF:Q4_0
unsloth/gemma-4-26B-A4B-it-qat-GGUF:UD-Q4_K_XL
unsloth/Qwen3.5-35B-A3B-GGUF:Q4_K_M
```

**Step 4 — pi.** Checks `node --version` against pi's minimum of 22.19.0 and reports, but does not act — pi's own installer handles Node. Then:

```bash
curl -fsSL https://pi.dev/install.sh | sh
```

Afterwards, if `pi` isn't resolvable, the script probes `$(npm prefix -g)/bin`, `~/.local/bin`, and `~/.local/share/pi-node/current/bin` and prepends whichever contains it — this only affects the running script, not your shell permanently.

**Step 4c — the launcher.** Written to `~/bin/llama-serve-<alias>.sh`:

```bash
llama-server \
  -hf <repo>:<quant> \
  --alias <alias> \
  --host 127.0.0.1 --port 8080 \
  -ngl 99 \
  -c 32768 \
  -fa on \
  --jinja
```

- `--host 127.0.0.1` binds to the loopback interface only. Other machines on your network cannot reach it.
- `--alias` is the important one. It pins the name the server reports over the API, so the entry written into `models.json` is guaranteed to match. Without it the name is derived from the repository path and a mismatch fails silently.
- `-ngl 99` offloads all layers to the GPU (Metal, on a Mac).
- `-c 32768` sets a 32K-token context window. Raise it if you have memory to spare; lower it if the server won't start.
- `--jinja` uses the chat template embedded in the model file, which matters for tool-calling.

**Step 4d — pi's configuration.** Backs up `~/.pi/agent/models.json` with a timestamp, then merges in:

```json
{
  "providers": {
    "llama-cpp": {
      "baseUrl": "http://localhost:8080/v1",
      "api": "openai-completions",
      "apiKey": "none",
      "models": [
        {
          "id": "<alias>",
          "name": "<label> (local)",
          "contextWindow": 32768,
          "maxTokens": 8192,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    }
  }
}
```

The merge is a real merge, not an overwrite: existing providers survive, and re-running with the same model replaces that one entry rather than duplicating it. It is performed by `node` if available, otherwise `python3` — both branches are equivalent and both abort loudly if the existing file is malformed JSON.

The dummy `apiKey` is not vestigial. `pi` treats a model as unavailable until some credential exists for its provider, even for a keyless local server, so a placeholder is required for the model to appear in the `/model` picker.

## 7. Notes on the third-party installer

Step 4 pipes a remote script into a shell. That deserves scrutiny, so here is what `pi.dev/install.sh` does, from reading it:

- **Node.js.** Requires ≥ 22.19.0. If missing or too old it asks, then uses `brew install node` when Homebrew exists — which it will, because step 1 ran first. With no Homebrew it downloads a Node 22 tarball from `nodejs.org` and verifies it against the published `SHASUMS256.txt` before extracting.
- **Interactivity.** It opens `/dev/tty` explicitly for its prompts, which is why piping into `sh` doesn't break it. It shows you the exact `npm` command it intends to run and offers install / uninstall / do-nothing. Choosing "do nothing" exits cleanly.
- **What it runs.** By default: `npm install -g --ignore-scripts --min-release-age=0 @earendil-works/pi-coding-agent`. An alternative pinned-dependency path exists but is gated behind an environment variable and is off by default.
- **Privileges.** No `sudo` on macOS. The `sudo` calls in the file are confined to the Linux `apt`/`apk` branches.
- **Writes.** npm's prefix or `~/.local`, plus `~/.local/share/pi-node`, plus temp files. Its one edit to your shell profile is prompted and checks for a duplicate line first.
- No `eval`, no telemetry, no credential access.

To read it yourself before running anything:

```bash
curl -fsSL https://pi.dev/install.sh | less
```
