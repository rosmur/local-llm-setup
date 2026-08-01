# Model Choices

Step 3 of the setup script offers three options. All are free and open-weight. These are the best overall models *targeted for RAM <32 GB* available as of July 2026 with relatively large user validation and maturity.

|   | Model | Download | Notes |
|---|---|---|---|
| **1** | Gemma 4 E4B | ~4.6 GB | The small, fast one. Works on modest machines. A reasonable first choice if you're unsure. |
| **2** | Gemma 4 26B-A4B (QAT) | ~15 GB | Much more capable, but only activates a small slice of itself per word, so it stays fast. Wants ~24 GB of RAM. |
| **3** | Qwen3.5 35B-A3B | ~20 GB | Same idea, different family. Strong at code. Wants ~32 GB of RAM. |

If you pick wrong, nothing is lost. Re-run the script and choose a different one; both models stay cached on disk and the script will simply point `pi` at whichever you chose most recently.

!!! tip "Exploring other models"

    If you wish to use a more powerful model (if you have more RAM) or just want to explore, there are literally 1000s of options available. The best place to find them is [huggingface.co](https://huggingface.co).
