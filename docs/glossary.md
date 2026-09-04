---
title: Glossary
description: Definitions of technical terms used throughout the documentation — GGUF, quantization, QAT, MoE, context window, KV cache, and more.
---

# Glossary

**Context window**
:   The maximum number of tokens (roughly ~¾ of a word in English) the model can consider at once when generating a response. A larger context window lets the model handle longer conversations and larger code files. With the current `llama serve` approach the script doesn't set this explicitly; adjust it with `llama serve -c <tokens>` (the older launcher used 32768 / 32K tokens).

**GGUF**
:   GPT-Generated Unified Format — a file format for storing quantized LLM model weights. It is the format used by `llama.cpp` and supported by most local inference engines. GGUF files bundle the model's weights, tokenizer, and metadata (such as the chat template) into a single file.

**Jinja (chat template)**
:   A templating language used inside GGUF model files to define how conversations are formatted before being fed to the model. Each model family has its own chat template. The `--jinja` flag in `llama-server` tells it to use the template embedded in the model file rather than a hardcoded default, which is important for reliable tool-calling.

**KV cache**
:   Key-Value cache — a memory buffer where the model stores intermediate computations from earlier parts of a conversation. Without it, every new token would require re-processing the entire conversation history. The KV cache is the main consumer of RAM during inference. A larger context window means a larger KV cache.

**Metal**
:   Apple's GPU acceleration framework. On Macs with Apple Silicon (M1, M2, M3, M4), `llama.cpp` uses Metal via the `-ngl` flag to offload model layers to the GPU, significantly speeding up inference.

**MoE**
:   Mixture of Experts — a model architecture where only a subset of parameters (the "experts") activate for any given input. This allows much larger total model size while keeping inference fast, because most of the model stays dormant for each token. For example, Qwen3.5 35B-A3B has 35B total parameters but only activates ~3B per token.

**ngl**
:   "Number of GPU layers" — the `-ngl` flag in `llama.cpp` controls how many layers of the model are offloaded to the GPU. On a Mac this means Metal acceleration. `-ngl 99` offloads all layers.

**QAT**
:   Quantization Aware Training — a technique where the model is *trained* to survive being compressed, so it loses less quality than ordinary post-training quantization (PTQ) would cost. The Gemma 4 26B-A4B (QAT) model uses this approach.

**Quantization (quant)**
:   The process of reducing the precision of a model's weights (e.g., from 16-bit floats to 4-bit integers) to shrink file size and memory usage at the cost of a small quality loss. Quantization levels are denoted like `Q4_0` (4-bit, symmetric), `Q4_K_M` (4-bit, k-quant with medium quality), etc. A more aggressive quant (fewer bits) means a smaller file but lower output quality.
