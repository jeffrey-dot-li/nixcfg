# Universal Pi defaults

These instructions apply to every Pi installation managed by nixcfg.
They are defaults: machine-local and project-specific instructions may
specialize or override them. Keep machine-specific details and credentials
out of this file.

## Shell execution

- Foreground Bash commands have an enforced maximum timeout of 60 seconds.
- Run commands that might take longer through `task_start` (background tasks).
- A foreground timeout interrupts execution and may leave partial effects.
  Inspect those effects before retrying; never automatically restart a
  side-effecting command in the background.

## Background tasks: launch, then yield

- Keep `notifyOnCompletion: true` when launching background tasks. Completion
  notifications return to the conversation and let you continue the work.
- Do not follow `task_start` with `task_wait`. Do not use sleep commands,
  repeated `task_status`/`task_logs` calls, or other blocking waits as substitutes.
  Use a blocking wait only if the user explicitly requests it.
- Continue genuinely independent work while a task runs. If further work
  depends on its result, briefly report what is running and finish your turn
  so the user can interact. Resume on the completion notification; do not
  remain inside a waiting tool call or invent busywork to keep the turn alive.
- If a task's hard timeout is longer than its expected duration, schedule a
  one-shot inspection with `task_reminder` (`taskId`, `afterSeconds`, `message`)
  and then yield. Keep `cancelOnCompletion: true` unless you intentionally want
  a reminder even after completion. A reminder only wakes you; it does not
  change the task or restrict your normal ability to act autonomously.
- On a reminder, inspect task status and recent logs, then decide whether to
  continue, investigate, stop the task, or schedule another check-in. Elapsed
  time alone is not proof that a task is stalled. Never wait or poll just to
  reach a reminder's deadline.
- After completion, inspect the exit status and relevant logs before reporting
  success or proceeding with dependent work. Launching a task is not evidence
  that it succeeded. One-off status/log checks are appropriate for diagnosis
  or when the user asks for progress, but not as a polling loop.

<!-- Add your universal rules below. This file is packaged by Nix, not linked
     over ~/.pi/agent/AGENTS.md. That file remains available for local rules. -->
