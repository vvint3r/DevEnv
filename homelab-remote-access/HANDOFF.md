# Handoff — Homelab Remote-Access Setup

**Context for any agent picking this up in another environment.** This documents a workstream
*separate* from the DevEnv/VS Code project that owns the rest of this repo (see the repo-root
`handoff.md` for that one). This folder is about **remote access + persistent terminal sessions**
across wynt3r's homelab: SSH keys, mosh, tmux, per-project sessions, Warp/Warpify, and running
Claude Code across machines.

- Companion file: [`CONFIG-CHANGES.md`](./CONFIG-CHANGES.md) — every dotfile/config edit, byte-exact, with how to use each.
- User-facing guide: [`Homelab-Remote-Access-Guide.md`](./Homelab-Remote-Access-Guide.md) — the readable reference (also lives at `C:\Users\DevCraft\OneDrive\Desktop\Homelab-Remote-Access-Guide.md`).

---

## Machines & topology

| Name | Address | Role |
|------|---------|------|
| **DevCraft** | local | Workstation: WSL2 Ubuntu on Windows, user `wynt3r`, terminal **Warp**. Where Claude Code + the agent run. |
| **wynt3rcompute1** | `192.168.5.200` | Ubuntu 24.04 server, Docker host. Key-based SSH + passwordless sudo. mosh 1.4.0 + tmux 3.4. |
| **wynt3rstorage** | `192.168.5.46` | Storage server, usually powered off. Still password-only — key/mosh/tmux setup deferred. |

Homes match on both boxes (`/home/wynt3r`), which is why local `$HOME` expansion in the `p` helper
produces a valid remote path. SSH aliases live in the **WSL** `~/.ssh/config`; VS Code uses a
**separate Windows** config at `C:\Users\DevCraft\.ssh\config`.

## How the agent operates here (important for continuation)

- This Claude Code session runs **on DevCraft's WSL**, and drives compute1 **directly** over SSH —
  it is **not** sandboxed away from the machines. Use `ssh -o BatchMode=yes wynt3rcompute1 '<cmd>'`
  for non-interactive server work.
- **Passwordless key auth (workstation→compute1) and passwordless sudo on compute1 are in place**,
  so the agent can run `sudo` remotely without a prompt. Do NOT re-introduce steps that require a
  human to type a password into the non-interactive tool — those need a real terminal (a TTY),
  which the Bash tool / Warp `!` runner lack. See the memory note
  `interactive-password-prompts-need-real-terminal`.
- `mosh` sessions are interactive and can't be scripted through the Bash tool; validate tmux
  behavior instead with detached sessions (`tmux new-session -d …` then inspect, then kill).

## What was accomplished

1. **SSH fixed + hardened.** WSL had no `~/.ssh/config` (root cause of "password not accepted" in
   Warp). Created it with `wynt3rcompute1` / `wynt3rstorage` aliases; set up ed25519 key auth to
   compute1; enabled passwordless sudo on compute1.
2. **mosh + tmux.** Installed mosh on both workstation and compute1 (freed a 34-day-stuck apt lock
   to do so); deployed `~/.tmux.conf` on compute1 (mouse, vi keys, sane splits, 256-color).
3. **Persistent-session workflow.** Workstation aliases `work` / `storage` / `cs` / `csl` — tmux
   over mosh. Detach/reattach survives disconnects.
4. **Per-project sessions (the current convention).** One tmux **session per project**, rooted at
   `~/projects/<name>` on compute1. Helpers: workstation **`p <name>`** (self-heals the dir, then
   attaches/creates the session rooted there) and compute1-side **`tat`** (session named after
   `$PWD`). Session = project, windows = roles, panes = side-by-side.
5. **Reboot persistence.** TPM + `tmux-resurrect` + `tmux-continuum` installed on compute1
   (`~/.tmux/plugins/`), `@continuum-restore on`. Restores layout/cwd on server start; does NOT
   resume running processes.
6. **Warp.** Local 2×2 panes for layout; "Warpify SSH Sessions" ON. Established that Warpify =
   features (Blocks/AI/completions), NOT persistence; and that a tmux session disables Warp Blocks
   (the deliberate tradeoff). Note: Warp's built-in AI agent is named **"Oz"**.
7. **Claude Code cross-machine.** CLI installed on compute1 (`~/.local/bin/claude`, v2.1.198);
   this session's transcript + memory copied there. Pattern: run `claude` inside a tmux session,
   optionally `claude remote-control --name compute1` for browser/mobile reach.
8. **Mouse-click selection disabled** in Claude Code prompts via
   `CLAUDE_CODE_DISABLE_MOUSE_CLICKS=1` in the workstation `~/.claude/settings.json` (keeps scroll).

## Reference materials

- **This folder** (portable, in-repo): `HANDOFF.md`, `CONFIG-CHANGES.md`, `Homelab-Remote-Access-Guide.md`.
- **Desktop guide (Windows, machine-local):** `C:\Users\DevCraft\OneDrive\Desktop\Homelab-Remote-Access-Guide.md`.
- **Agent memory (workstation):** `~/.claude/projects/-home-wynt3r/memory/` — `MEMORY.md` (index),
  `homelab-hosts.md`, `claude-code-on-compute1.md`, `interactive-password-prompts-need-real-terminal.md`.
- **This session transcript:** `~/.claude/projects/-home-wynt3r/1d8dd25f-c2e2-4b34-aff5-cccf3cdfdddc.jsonl`
  (also copied to compute1). Resume with `cd /home/wynt3r && claude --resume 1d8dd25f-c2e2-4b34-aff5-cccf3cdfdddc`.

## Current state / open items

- **#9 — Verify persistent + Warpify workflows end-to-end.** Server-side mechanics validated
  (`p` creates a session rooted at `~/projects/<name>`; continuum active). User to confirm the full
  loop after next Claude Code relaunch (needed to pick up the mouse-click setting — read at startup).
- **#10 — wynt3rstorage.** When powered on: copy SSH key, install mosh + tmux, deploy `~/.tmux.conf`,
  confirm the `storage` alias. Deferred (box usually off).

## Gotchas / lessons

- **Vanishing `~/projects`:** an empty `~/projects` on compute1 disappeared once between commands
  with **no reboot** (the `work` session has been alive since 2026-07-02). Unexplained — possibly
  odd home-dir storage on compute1. Mitigation: `p` recreates the dir every invocation. If it
  recurs, investigate compute1's home filesystem.
- **OS credential prompts ≠ Claude Code permissions.** Password-interactive steps fail in the
  non-interactive tool (no TTY); once keys + passwordless sudo exist, drive the box over SSH and
  stop handing steps back.
- **`tat`/`p` set the session's start dir via tmux `-c`** — tmux does not expand `$HOME`/`~`, so `p`
  passes a locally-expanded absolute path (safe because both homes are `/home/wynt3r`).
- **Reboot restore ≠ process restore.** resurrect/continuum bring back layout + cwd (and a pane-text
  snapshot), not the programs that were running.

## Not committed

These docs are new files in the repo working tree, **not yet committed** (mirrors the repo's
untracked-`handoff.md` convention). Commit them if you want them versioned/pushed.
