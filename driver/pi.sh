#!/usr/bin/env bash
# One pi harness call on the public lane: provider arc-pub, model auto-llm
# (classify-and-route pool behind an OpenAI-compatible proxy). Prompt = args;
# attach files as @path. AS_USER=<silo user> runs it inside that user's home via
# sudo -n; the silo user holds no sudo itself, so this grants no escalation.
set -euo pipefail
args=(pi -p --no-session --provider "${PI_PROVIDER:-arc-pub}" --model "${PI_MODEL:-auto-llm}" "$@")
if [ -n "${AS_USER:-}" ]; then
  h=$(getent passwd "$AS_USER" | cut -d: -f6)
  exec sudo -n -u "$AS_USER" -- env HOME="$h" XDG_RUNTIME_DIR="/run/user/$(id -u "$AS_USER")" "${args[@]}"
fi
exec "${args[@]}"
