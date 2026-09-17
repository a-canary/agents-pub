# agents-pub — CHOICES

## Mission
One highly optimized engine that runs Qwen3.8-27B (Q6_K) with 131k context at max quality and speed on a Tesla V100 32 GB (sm_70), folding the useful ideas from ninfer, llama.cpp b10840 (draft-mtp), and the V100-skinny CUDA build into one path.
See README.md for model facts and the plan layout.

## Objectives
- O1 Decode speed: sustained ≥50 tok/s greedy decode at 131k context configured (KV q8_0). Measured so far: baseline 27.4, draft-mtp 52–53 tok/s (plans/v100-qwen-mtp; run 20260915T001738Z).
- O2 Quality: MTP output must be verified equal-or-better than baseline via a case ladder, not byte equality (baseline vs MTP diverge deterministically at byte 663 on the bench prompt; cause = batched-verify numerics on a greedy near-tie, unconfirmed).
- O3 Prompt processing at 131k: measure pp at 8k/32k/131k prompts (llama-bench -p); target stated only after measurement.
- O5 pi-vcc fork: kept tail bounded — every corpus case's retained tail ≤ TAIL_TOKEN_BUDGET (default 8000 tok) with no case regressing from `cut` to `defer`, fork test suite green (plans/pi-vcc-fork).
- O4 Reproducible driver: `driver/driver.sh plans/v100-qwen-mtp` runs build → bench → verdict end to end with the verdict step on provider arc-pub / model auto-llm.

## Decisions
- D1 ninfer is not usable on V100 (RTX 5090 / sm_120a / CUDA ≥13.1 only); llama.cpp CUDA sm_70 build is the base.
- D2 Unmeasured = not passed. Infra faults (missing provider, server crash) are reported as faults, never as results.
- D3 Public lane: no operator identity in any file.
- D4 pi-vcc is forked, not patched upstream: `buihongduc132/pi-vcc` has issues and discussions disabled, 0 stars, 3 self-authored PRs ever, and npm 0.4.1 is behind master — so reports 3–5 of `a-canary/pi-compaction-rank/findings/upstream-reports.md` have no delivery channel. Fork = `a-canary/pi-vcc` off upstream master.
- D5 Upstream R1–R5 binds the fork (`flow/requirements/2026-08-26_vcc-over100-routing.md`): R5 forbids fixing the pi-core geometry trap (single-giant-turn empty summarize window, upstream pi#6879) from the extension layer. A kept-tail ceiling is not that trap — it is `buildOwnCut`'s own choice of `firstKeptEntryId`.
- D6 Measurement reuses the published harness corpus (`a-canary/pi-compaction-rank`, 20 pathological cases) instead of growing a second corpus here; the plan imports `stress/corpus.ts` and calls `buildOwnCut` directly.

## Open gaps
- G1 Verdict step fails with `Unknown provider "arc-pub"` when run outside the public-silo user; fix = run as the silo user or document provider setup.
- G2 BUG-TEXT-MISMATCH handling (O2).
- G3 ~~GitHub remote not yet created~~ — done 2026-09-17: https://github.com/a-canary/agents-pub (public, `main`).
- G4 pi-vcc bug #4: Strategy A (`src/hooks/before-compact.ts:209-224`) walks back to the last user-role entry with no token ceiling, so a single long turn keeps an unbounded tail. Patch goes in `plans/pi-vcc-fork/patches/01-tail-budget.patch`.
- G5 pi-vcc packaging: master still ships `demo.gif` + `scripts/` (16.4 MB tarball); `.npmignore` covers `test*/` only. Peer dep still `@mariozechner/pi-coding-agent` after the rename to `@earendil-works`.
- G6 The silo user `agent-pub` has no gh auth, so pushes to GitHub happen from the operator lane; the director merges locally (`on-task-verified: merge`) and the operator pushes.
