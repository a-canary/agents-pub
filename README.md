# agents-pub

Mission: one optimized inference engine for Qwen3.8-27B (Q6_K) at 131k context on a Tesla V100 32 GB, at maximum quality and speed.
Ideas are absorbed from three sources: ninfer (multi-token-prediction decode, hand-written kernels; itself RTX 5090 / CUDA 13 only), llama.cpp (baseline, CUDA backend, built-in `draft-mtp`), and the rootless CUDA 12.8 sm_70 build approach that made the V100 usable without a system-wide driver toolkit.
Every change is gated by measurement; the first plan below decides whether custom kernels are worth writing at all.
A second lane applies the same discipline to open-source pi extensions (`plans/pi-vcc-fork`): fork, patch, measure against a published stress corpus, verdict.

Open driver for agent-run engineering plans on a public model lane.
Deterministic steps (build, benchmark, arithmetic) run in shell; the model only reads results and writes prose, through the [pi](https://github.com/badlogic/pi-mono) harness on provider `arc-pub`, model `auto-llm` (a classify-and-route pool behind an OpenAI-compatible proxy).

## Run

```
MODEL=/path/to/Qwen3.8-27B-UD-Q6_K.gguf driver/driver.sh plans/v100-qwen-mtp
```

Each step's log, the results JSON, the mechanical verdict and the model's verdict land under `/tmp/agents-pub/runs/<plan>/<utc-stamp>/`.
A failed step stops the plan and the model writes `<step>.diagnosis.md` naming the fault class (infra vs real negative result).

Environment knobs: `WORK` (clone+build dir), `LLAMA_DEVICE` (name from `llama-server --list-devices`), `CUDA_ARCH`, `PORT`, `CEILING`, `STEP_TIMEOUT`, `AS_USER` (run pi inside a separate silo user), `PI_PROVIDER` / `PI_MODEL`.
Requires `cmake`, `ninja`, `nvcc`, `jq`, `curl`, `pi` in PATH.

Self-check: `driver/selfcheck.sh` runs the driver against a stub plan and the verdict jq against fixture rows (no GPU, no model calls).

## Model facts (read from the GGUF header)

Architecture `qwen35`: hybrid Gated DeltaNet (SSM) with full attention every 4th layer, 64 layers + 1 next-token-prediction layer, trained context 262144.
Full-attention KV per token: 16 layers × 2 × 4 KV heads × 256 = 32768 elements ≈ 64 KB f16, ≈ 34 KB q8_0.
131k context therefore costs ≈ 8.6 GB f16 or ≈ 4.5 GB q8_0 on top of ≈ 22 GB weights; the SSM state is per-sequence and small.
So 131k fits on the card, and the binding constraints are decode speed (≈ 40 tok/s bandwidth ceiling for 22 GB at 900 GB/s) and prompt-processing speed, not memory.

## Plans

### v100-qwen-mtp

Question: is a custom-kernel fork (ninfer-style Volta `mma.sync` rewrite, ~66k CUDA lines) worth starting for Qwen3.8-27B Q6_K on a Tesla V100 32 GB, or does stock llama.cpp with the model's built-in multi-token-prediction head already sit near the bandwidth ceiling?

Steps: `build` (llama.cpp tag with `--spec-type draft-mtp`, CUDA sm_70) → `bench` (five server configs incl. one at 131072 context with q8_0 KV, greedy, same prompt; text equality across configs is the quality gate because speculative decoding is exact) → `verdict` (jq computes the decision, the model narrates it and must repeat it verbatim).

Decision rule: `FORK-WORTH-EXPLORING` only if the best config decodes below 60% of `CEILING` tok/s; `BUG-TEXT-MISMATCH` if any config's greedy text differs from baseline; otherwise `NO-FORK`.

### pi-vcc-fork

Question: can the `a-canary/pi-vcc` fork bound the context tail that pi-vcc keeps across a compaction, without regressing any cut into a defer?

Upstream `buihongduc132/pi-vcc` has issues and discussions disabled, so the bug reports from [pi-compaction-rank](https://github.com/a-canary/pi-compaction-rank) have no delivery channel — the fork is the channel (CHOICES D4).

Steps: `clone` (fork at upstream master + corpus-only clone of pi-compaction-rank) → `baseline` (pristine `buildOwnCut` over 20 pathological cases) → `patch` (apply `patches/*.patch` in order, then run the fork's vitest suite) → `measure` (same corpus, patched) → `verdict`.

Measured per case: kept-tail tokens (`tail_tok`), kept message count, summarized tokens, flags (`TAIL_OVER_BUDGET`, `SYNTH_ANCHOR`, `defer:<reason>`, `crash`).

Decision rule: `PASS` only if no case exceeds `TAIL_TOKEN_BUDGET` (default 8000 tok), no case regressed `cut` → `defer`, nothing crashed, and the fork's own tests are green; `INFRA_FAULT` if the import or install failed (never a result, per D2); otherwise `FAIL` with the offending rows named.

Run: `driver/driver.sh plans/pi-vcc-fork` (needs `bun`, `git`, network for the first clone).

## License

Apache-2.0
