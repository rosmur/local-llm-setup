## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `pi: command not found` | The install directory isn't on your `PATH` yet. Open a **new** terminal window; pi's installer offers to fix your shell profile permanently. |
| Your model isn't in `pi`'s `/model` list | Two usual causes. The server isn't running — check with `curl http://localhost:8080/v1/models`. Or `pi` has no stored credential for the provider — start it once with `pi --api-key none`. |
| Server exits with a memory error | The model is too big for your RAM. Lower `-c 32768` to `-c 8192` in the launcher, or re-run the script and pick a smaller model. |
| Painfully slow responses | Also memory. The Mac is swapping to disk. Same fix. |
| Download step drops you into a chat prompt | Should not happen — three separate guards prevent it. If it does, press `Ctrl-C`; the download has already finished by the time the prompt appears, and the script continues normally. |
| Port 8080 already in use | Something else has it. Change the port in **both** the launcher script and the `baseUrl` in `models.json` — they must agree. |
| `brew: command not found` after step 1 | Homebrew installed but isn't on this shell's `PATH`. Open a new terminal and re-run the script; it'll detect the existing install and skip ahead. |

---

## Known gaps and caveats

Stated plainly, because you are being asked to run this on your own machine.

- **The one-token download trick** (`llama-cli ... -n 1 -no-cnv`) is a construction, not a documented workflow. The documented approach is to let `llama-server -hf` download on first launch. If the flags misbehave on your build of `llama.cpp`, answer `n` at the download prompt and let the server handle it.
- **The "already downloaded" check is advisory, not authoritative.** It reliably detects that a model *repository* is cached, but in the Hugging Face layout the individual files are named by content hash, so it cannot always confirm that the specific compression level (quant) is present or that the files are complete. This is why the verification pass is still offered. A false "on disk" would at worst cause `llama-server` to download the missing piece on first launch.
- **The server flags are reasonable defaults, not tuned ones.** Model authors publish longer, more specific flag sets — particularly for KV-cache quantization and speculative decoding, which can meaningfully improve speed. Those are worth investigating once you have the basic setup working.
- **The `--min-release-age=0` flag** in pi's installer deliberately bypasses an npm safeguard that delays newly published packages. The stated justification is that pi ships a `npm-shrinkwrap.json` pinning its dependencies. That reasoning is sound in principle but has not been independently verified.
