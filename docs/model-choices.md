---
title: Model Choices
description: The three open-weight models offered by the setup script — Gemma 4 E4B, Gemma 4 26B, and Qwen3.6 35B — and how to pick one.
---

# Model Choices

Step 3 of the setup script offers three options plus a **0 (skip)** choice. All are free and open-weight. These are the best overall models *targeted for RAM <32 GB* available as of July 2026 with relatively large user validation and maturity.

|   | Model | Download | Min RAM | Notes |
|---|---|---|---|---|
| **1** | Gemma 4 E4B | ~4.6 GB | 8GB | The small, fast one. Works on modest machines. A reasonable first choice if you're unsure. |
| **2** | Gemma 4 26B-A4B (QAT) | ~15 GB | 24GB | Much more capable, but only activates a small slice of itself per word, so it stays fast. |
| **3** | Qwen3.6 35B-A3B | ~20 GB | 32 GB | Same idea, different family. Stronger at code. |

*NOTE: Minimum RAM values are recommendations only, not a hard requirement*

If you pick wrong, nothing is lost. Re-run the script and choose a different one; models stay cached on disk, and `llama serve` uses whichever you chose most recently (or downloads one on first run if you skipped).

## Model Finder Tool

To find models that fit in your RAM, this is a useful tool [LLMfit](https://www.llmfit.org/).

::: callout tip "Exploring other models"
If you wish to use a more powerful model (if you have more RAM) or just want to explore, there are literally 1000s of options available. The best place to find them is [huggingface.co](https://huggingface.co).
:::
