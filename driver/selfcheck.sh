#!/usr/bin/env bash
# One runnable check: driver sequencing + failure stop, and the verdict arithmetic.
set -euo pipefail
R=$(cd "$(dirname "$0")/.." && pwd); T=$(mktemp -d)
# stub plan: ok, then a failing step; pi.sh replaced by a stub via PATH
mkdir -p "$T/plan" "$T/bin"
printf 'ok\nbad\nnever\n' >"$T/plan/steps"
echo 'echo hi' >"$T/plan/ok.sh"; echo 'exit 7' >"$T/plan/bad.sh"; echo 'echo unreachable' >"$T/plan/never.sh"
printf '#!/usr/bin/env bash\necho "DECISION: stub"\n' >"$T/bin/pi"; chmod +x "$T/bin/pi"
set +e; PATH="$T/bin:$PATH" RUN="$T/run" "$R/driver/driver.sh" "$T/plan" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 1 ] && grep -q '^ok done$' "$T/run/state" && grep -q '^bad failed(exit=7)$' "$T/run/state" && ! grep -q never "$T/run/state" && [ -s "$T/run/bad.diagnosis.md" ] || { echo FAIL driver; exit 1; }
# verdict math: mtp2 fastest, all same text, below 60% of ceiling 40 -> FORK-WORTH-EXPLORING
cat >"$T/results.json" <<'EOF'
[{"name":"baseline","decode_tps":10,"same_text_as_baseline":true},{"name":"mtp2","decode_tps":20,"same_text_as_baseline":true}]
EOF
RUN="$T" MODEL=x CEILING=40 PATH="$T/bin:$PATH" bash -c '. '"$R"'/plans/v100-qwen-mtp/env.sh; D='"$R"'/plans/v100-qwen-mtp
  jq --argjson c "$CEILING" -f /dev/stdin "$RUN/results.json"' <<'EOF' >"$T/m.json"
(.[0].decode_tps) as $b | (max_by(.decode_tps)) as $best |
{best:$best.name, delta_pct:(($best.decode_tps/$b-1)*100|round),
 decision:(if (map(.same_text_as_baseline)|all|not) then "BUG-TEXT-MISMATCH" elif $best.decode_tps < 0.6*$c then "FORK-WORTH-EXPLORING" else "NO-FORK" end)}
EOF
[ "$(jq -r '.best+" "+(.delta_pct|tostring)+" "+.decision' "$T/m.json")" = "mtp2 100 FORK-WORTH-EXPLORING" ] || { echo FAIL verdict; cat "$T/m.json"; exit 1; }
rm -rf "$T"; echo selfcheck ok
