# Homelab Remote-Access Reference

_Workstation: **DevCraft** (WSL2 Ubuntu, user `wynt3r`, terminal **Warp**)_
_Last updated: 2026-07-04_

---

## 1. The machines

| Name | IP | Role | Notes |
|------|----|----|-------|
| **DevCraft** | — (this box) | Workstation | WSL2 Ubuntu on Windows. Where you run Warp + Claude Code. |
| **wynt3rcompute1** | `192.168.5.200` | Ubuntu 24.04 server, runs Docker | Key-based SSH + passwordless sudo set up. mosh + tmux installed. |
| **wynt3rstorage** | `192.168.5.46` | Storage server | Often powered off. Still password-only — key/mosh/tmux setup deferred until it's online. |

SSH aliases live in `~/.ssh/config` (WSL side). VS Code uses the **Windows** config at
`C:\Users\DevCraft\.ssh\config` — that's a *separate* file. Keep both in sync if you add hosts.

---

## 2. The mental model (read this once)

Two **independent** concerns — don't conflate them:

| Concern | Handled by | What it gives you |
|---------|-----------|-------------------|
| **Persistence** (survive disconnects, keep long jobs alive) | **tmux** (on the server) + **mosh** (resilient transport) | Sessions/panes stay alive when you close the laptop or the network drops. |
| **Rich UI features** (command Blocks, AI, autocompletion) | **Warp / Warpify** | Boxed commands, click-to-copy output, AI command search, IDE-style editor. |

- **Persistence is a server/remote concern.** Local WSL is always there, so it needs no tmux.
- **Warpify is a features concern.** It does *not* provide persistence.
- **Tradeoff:** a tmux session takes over the terminal, so it **disables Warp Blocks**. Choose per use-case:
  - Long-running remote work → **tmux over mosh** (persistence, no Blocks).
  - Quick remote/local work → **plain Warp session** (Blocks + AI, no persistence).

---

## 3. Persistent sessions — tmux over mosh (server-side)

Workstation shortcuts are defined in `~/.bashrc`:

```bash
work            # mosh to compute1, attach-or-create tmux session "work"
storage         # mosh to storage,  attach-or-create tmux session "storage" (when online)
cs <name>       # attach-or-create ANY named session on compute1 (cs alone = "work")
p <name>        # attach-or-create a PROJECT session, rooted at ~/projects/<name>  (preferred)
csl             # list the tmux sessions currently running on compute1
```

Typical flow:

```bash
work            # jump into your persistent workspace
#  ... do stuff, open panes, run long jobs ...
#  detach with:  Ctrl+b  then  d      (leaves everything running)
work            # later — reattaches to the SAME session, jobs still running
csl             # see what's alive without attaching
```

**Why mosh?** It's the *transport* under tmux. If your IP changes (Wi-Fi → LAN) or the link
drops for minutes, mosh reconnects automatically and gives instant local echo. tmux keeps the
*session* alive on the server; mosh keeps your *connection* to it painless. They're complementary.

### Organizing work: one session per project

Best practice is **one tmux session per project** — not one giant `work` session, and not one per
random sub-directory. The levels map like this:

| tmux level | Use it for |
|-----------|-----------|
| **Session** | one **project** (named after it; this is your unit of persistence) |
| **Window** (tab) | a *role* within the project — `edit`, `server`, `logs`, `claude`, `git` |
| **Pane** (split) | things you watch side-by-side |

Convention: all projects live under **`~/projects/<name>`** on compute1. A session is created
**rooted in its project directory** (via tmux's `-c` flag) so every new window/pane opens there.
There is only ever **one** tmux server per user — you don't relaunch tmux per project, you create
one *session* per project.

Two helpers do this for you:

```bash
# From the workstation — jump straight into a project (creates it if needed, rooted correctly):
p myproject            # mosh in + attach-or-create session "myproject" at ~/projects/myproject

# On compute1, from inside a project directory — name the session after that dir:
cd ~/projects/myproject && tat
```

`p` (workstation `~/.bashrc`) is the everyday entry point. `tat` (compute1 `~/.bashrc`) is the
"I'm already on the box, in a dir, make a session here" shortcut.

### Reboot persistence (installed)

tmux persistence lives in the server's **RAM** — it survives disconnects, closing the laptop, and
mosh reconnects, **but not a reboot** of compute1. To cover reboots, **tmux-resurrect** +
**tmux-continuum** are installed (via TPM at `~/.tmux/plugins/`):

- **continuum** auto-saves the environment every ~15 min and **auto-restores on server start**
  (`@continuum-restore 'on'`), so sessions/windows/panes come back after a reboot.
- **resurrect** does the save/restore; pane *contents* are captured too
  (`@resurrect-capture-pane-contents 'on'`).
- Manual controls: **`Ctrl+b Ctrl+s`** = save now, **`Ctrl+b Ctrl+r`** = restore.

Note: running *programs* aren't magically resumed after a reboot — resurrect restores the layout,
working dirs, and (optionally) a snapshot of pane text; long-running processes need restarting.

---

## 4. tmux keybindings (prefix = `Ctrl+b`)

Notation: **`Ctrl+b d`** means press `Ctrl+b`, **release**, then press `d`. A space (no `+`) means
"then press" — it is a *sequence*, not a chord. `Ctrl+b |` means prefix, then the `|` key.

Custom bindings from `~/.tmux.conf` on the server:

| Keys | Action |
|------|--------|
| `Ctrl+b d` | **Detach** (leave session running) |
| `Ctrl+b \|` | Split pane **vertically** (left/right) |
| `Ctrl+b -` | Split pane **horizontally** (top/bottom) |
| `Ctrl+b h / j / k / l` | Move between panes (left/down/up/right) |
| `Ctrl+b c` | New **window** (like a tab) |
| `Ctrl+b 1..9` | Jump to window by number |
| `Ctrl+b s` | List/switch **sessions** (interactive picker) |
| `Ctrl+b r` | Reload `~/.tmux.conf` |
| `Ctrl+b [` | Scroll/copy mode (vi keys; `q` to quit) |
| `Ctrl+b Ctrl+s` | **Save** session state now (resurrect) |
| `Ctrl+b Ctrl+r` | **Restore** saved session state (resurrect) |

Mouse is enabled in the config, so you can also click panes and scroll.

---

## 5. Warp — local panes + Warpify

### Panes (local layout)
- **Split right:** `Ctrl+Shift+D`  •  **Split down:** `Ctrl+Shift+E`  •  **Close pane:** `Ctrl+Shift+W`
- You already run a **2×2 grid** in the WSL/Ubuntu session — that's the intended local layout.
- These are *Warp* panes (local, on DevCraft). They are **not** persistent — for persistence
  use tmux (Section 3). Don't nest tmux inside Warp panes unless you specifically want persistence
  (you'll lose Blocks in those panes).

### Warpify
- **What it is:** turns a shell into a full Warp session with **Blocks**, the multi-line input
  editor, autocompletions, and **AI (the agent is named "Oz")**. It is about *features*, not persistence.
- **SSH:** "Warpify SSH Sessions" is **ON** in Settings → so SSH sessions auto-Warpify.
- **WSL (local):** open it as its own Warp session and it's Warpified automatically —
  Settings → Features → Session → *Startup shell for new sessions* → select **Ubuntu**.
  Your existing `wynt3r@DevCraft` tab already shows Blocks, so it's already Warpified.
- **If you enter a subshell manually** (e.g. type `wsl` inside PowerShell): click the **Warpify**
  banner in that block, or Command Palette → "Warpify Subshell".
- **How to tell it worked:** each command renders in its own **Block**.

---

## 6. Claude Code across machines

- Sessions are stored **locally per machine** at
  `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`. There is **no cloud sync**.
- `claude --resume <id>` / `claude --continue` only see sessions on the machine you run them on.
- Claude Code **is installed on wynt3rcompute1** (v2.1.198, `~/.local/bin/claude`). This session's
  transcript + memory were copied there so it can be resumed on the server.

**Cross-machine pattern (Tier 2):**
```bash
work                                   # 1. mosh into a persistent tmux session on compute1
claude                                 # 2. run Claude Code there (survives disconnects via tmux)
claude remote-control --name compute1  # 3. (optional) reach it from browser/phone/other terminals
```
tmux keeps the process alive across drops; a long outage only times out the remote-control *link*,
not the underlying `claude` process.

### Setting: disable accidental mouse-click selection
In `~/.claude/settings.json`:
```json
{ "env": { "CLAUDE_CODE_DISABLE_MOUSE_CLICKS": "1" } }
```
Disables click/drag/hover selection in prompts while **keeping scroll-wheel scrolling**. Read at
startup — **restart Claude Code** to apply. (Set on DevCraft; add the same block on compute1 if wanted.)

---

## 7. Cheat sheet

```bash
# ── Connect ────────────────────────────────────────────────
p myproject          # PREFERRED: project session, rooted at ~/projects/myproject
work                 # general persistent tmux workspace on compute1 (over mosh)
cs project-x         # a different named persistent session
csl                  # list live sessions on compute1
ssh wynt3rcompute1   # plain SSH (Warpified, Blocks, but not persistent)
# on the box, in a project dir:  tat   # session named after the current directory

# ── Inside tmux (prefix Ctrl+b) ────────────────────────────
Ctrl+b d             # detach (keep running)
Ctrl+b |   /   -     # split vertical / horizontal
Ctrl+b h j k l       # move between panes
Ctrl+b c             # new window;  Ctrl+b s  = session picker

# ── Warp (local, on DevCraft) ──────────────────────────────
Ctrl+Shift+D / E     # split pane right / down
Ctrl+Shift+T         # new tab
```

---

## 8. Still to do

- **wynt3rstorage**: when it's powered on — copy SSH key, install mosh + tmux, deploy `~/.tmux.conf`,
  confirm the `storage` alias works. (Deferred; box is usually off.)
- Verify the full persistent + Warpify workflow end-to-end after the next Claude Code relaunch.
