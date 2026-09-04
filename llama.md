## AI that lives on your computer. Open-source, private & always local.

Run frontier AI entirely on your machine. No API keys, no telemetry, no limits. Own your models and conversation data.

[Download for Mac](https://github.com/ggml-org/Llama-macOS/releases/latest/download/Llama.dmg) or install the CLI

`curl -LsSf https://llama.app/install.sh | sh`

Prefer Brew or Winget? [Package managers](https://github.com/ggml-org/llama.cpp/blob/master/docs/install.md) · Rather build from source? [Follow instructions](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md)

## Pair it with a local coding agent.

Run `llama serve`, install the `pi-llama` plugin and launch [Pi](https://github.com/earendil-works/pi). It will automatically discover your local model. No config, no API keys. Files stay on your machine, requests never leave it.

```bash
# 1. Serve a model
llama serve

# 2. Install the pi-llama plugin
pi install git:github.com/huggingface/pi-llama

# 3. Run Pi, everything is set
pi
```
\
