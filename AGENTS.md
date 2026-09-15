# agents-pub

Public-lane agent work. Rules: no operator identity in any file; unmeasured = not passed; infra faults never look like results.
Layout: `driver/` runs plans, `plans/<name>/` holds steps + prompts, runs land in `/tmp/agents-pub/runs/`.

## Director bindings
event-bus: jsonl
task-delegation: native
workspace: worktree
on-task-verified: merge
todo-list: native
feedback-sink: jsonl
planning-target: prd-file
model:
  director: auto-llm            # pi session on the public pool router; observed live in a terminal pane
  director-effort: max
  worker: auto-llm
  worker-effort: max
scheduler:
  mode: none                    # steered live by an observer; no self-installed backstop cron
  backstop-hours: 12
budget:
  weekly: 500k
  bypass:
    - critical-failure
    - security
capacity: none
