#!/usr/bin/env bash
# agents-pub driver: run a plan's steps in order and watch each to a terminal
# state. Deterministic work (build, bench, math) stays in shell; the pi harness
# (driver/pi.sh) only reads results and writes prose.
# ponytail: sequential steps, one plan per run; add a queue when two plans must share a GPU.
set -euo pipefail
PLAN=$(cd "${1:?usage: driver.sh plans/<name> [step...]}" && pwd); shift || true
export RUN=${RUN:-/tmp/agents-pub/runs/$(basename "$PLAN")/$(date -u +%Y%m%dT%H%M%SZ)}
mkdir -p "$RUN"
steps=("$@"); [ ${#steps[@]} -gt 0 ] || mapfile -t steps < "$PLAN/steps"
for s in "${steps[@]}"; do
  echo "[driver] $s start $(date -u +%FT%TZ) run=$RUN" | tee -a "$RUN/driver.log"
  st=done
  timeout "${STEP_TIMEOUT:-3600}" bash "$PLAN/$s.sh" >"$RUN/$s.log" 2>&1 || st="failed(exit=$?)"
  echo "$s $st" >>"$RUN/state"
  echo "[driver] $s $st $(date -u +%FT%TZ)" | tee -a "$RUN/driver.log"
  if [ "$st" != done ]; then
    # model reads the failed log and names the fault class; infra faults must not look like results
    "$(dirname "$0")/pi.sh" "@$RUN/$s.log" "Step '$s' failed. From the attached log, state in <=10 lines: the failing command, whether this is an infra/build fault or a real negative result, and the single next action." >"$RUN/$s.diagnosis.md" 2>>"$RUN/driver.log" || true
    exit 1
  fi
done
echo "[driver] plan complete run=$RUN" | tee -a "$RUN/driver.log"
