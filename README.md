# agents-pub

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

## Plans

### v100-qwen-mtp

Question: is a custom-kernel fork (ninfer-style Volta `mma.sync` rewrite, ~66k CUDA lines) worth starting for Qwen3.8-27B Q6_K on a Tesla V100 32 GB, or does stock llama.cpp with the model's built-in multi-token-prediction head already sit near the bandwidth ceiling?

Steps: `build` (llama.cpp tag with `--spec-type draft-mtp`, CUDA sm_70) → `bench` (four server configs, greedy, same prompt; text equality across configs is the quality gate because speculative decoding is exact) → `verdict` (jq computes the decision, the model narrates it and must repeat it verbatim).

Decision rule: `FORK-WORTH-EXPLORING` only if the best config decodes below 60% of `CEILING` tok/s; `BUG-TEXT-MISMATCH` if any config's greedy text differs from baseline; otherwise `NO-FORK`.

## License

Apache-2.0
