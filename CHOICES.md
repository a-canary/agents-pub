# agents-pub — CHOICES

## Mission
One highly optimized engine that runs Qwen3.8-27B (Q6_K) with 131k context at max quality and speed on a Tesla V100 32 GB (sm_70), folding the useful ideas from ninfer, llama.cpp b10840 (draft-mtp), and the V100-skinny CUDA build into one path.
See README.md for model facts and the plan layout.

## Objectives
- O1 Decode speed: sustained ≥50 tok/s greedy decode at 131k context configured (KV q8_0). Measured so far: baseline 27.4, draft-mtp 52–53 tok/s (plans/v100-qwen-mtp; run 20260915T001738Z).
- O2 Quality: MTP output must be verified equal-or-better than baseline via a case ladder, not byte equality (baseline vs MTP diverge deterministically at byte 663 on the bench prompt; cause = batched-verify numerics on a greedy near-tie, unconfirmed).
- O3 Prompt processing at 131k: measure pp at 8k/32k/131k prompts (llama-bench -p); target stated only after measurement.
- O4 Reproducible driver: `driver/driver.sh plans/v100-qwen-mtp` runs build → bench → verdict end to end with the verdict step on provider arc-pub / model auto-llm.

## Decisions
- D1 ninfer is not usable on V100 (RTX 5090 / sm_120a / CUDA ≥13.1 only); llama.cpp CUDA sm_70 build is the base.
- D2 Unmeasured = not passed. Infra faults (missing provider, server crash) are reported as faults, never as results.
- D3 Public lane: no operator identity in any file.

## Open gaps
- G1 Verdict step fails with `Unknown provider "arc-pub"` when run outside the public-silo user; fix = run as the silo user or document provider setup.
- G2 BUG-TEXT-MISMATCH handling (O2).
- G3 GitHub remote not yet created (needs a human with repo-create permission).
