# Config Changes — exact edits & how to use them

Every dotfile/config change made for the homelab remote-access setup, byte-accurate as of
**2026-07-04**, with usage notes. Grouped by machine. See [`HANDOFF.md`](./HANDOFF.md) for context.

> Re-source after editing: `source ~/.bashrc` (bash) in any already-open shell; new shells load it
> automatically. tmux: `tmux source-file ~/.tmux.conf` or prefix + `r`.

---

## Workstation — DevCraft (WSL2 Ubuntu), user `wynt3r`

### `~/.ssh/config`  *(created — was absent, the root cause of Warp "password not accepted")*
```sshconfig
Host wynt3rcompute1
    HostName 192.168.5.200
    User wynt3r

Host wynt3rstorage
    HostName 192.168.5.46
    User wynt3r
```
Permissions: dir `~/.ssh` = 700, file = 600. ed25519 key at `~/.ssh/id_ed25519`, public key
already installed on compute1 (`ssh-copy-id`).

### `~/.bashrc`  *(appended block — persistent tmux over mosh)*
```bash
# --- wynt3r session shortcuts: persistent tmux over mosh ---
alias work='mosh wynt3rcompute1 -- tmux new -A -s work'
alias storage='mosh wynt3rstorage -- tmux new -A -s storage'
# attach-or-create ANY named persistent session on compute1:  cs <name>   (cs alone = "work")
cs() { mosh wynt3rcompute1 -- tmux new -A -s "${1:-work}"; }
# list the persistent sessions currently running on compute1
alias csl='ssh wynt3rcompute1 tmux ls'
# jump into a PROJECT session on compute1 (attach-or-create, rooted at ~/projects/<name>)
#   p foo   ->  mosh in and attach/create session "foo" starting in ~/projects/foo
p() { [ -z "$1" ] && { echo "usage: p <project>   (see: csl)"; return 1; }; ssh wynt3rcompute1 "mkdir -p ~/projects/$1"; mosh wynt3rcompute1 -- tmux new -A -s "$1" -c "$HOME/projects/$1"; }
```

| Command | What it does |
|---------|--------------|
| `work` | mosh → compute1, attach-or-create tmux session `work` |
| `storage` | mosh → storage, attach-or-create session `storage` (when the box is online) |
| `cs <name>` | attach-or-create any named session on compute1 (`cs` alone = `work`) |
| `csl` | list live tmux sessions on compute1 (plain SSH, no attach) |
| `p <name>` | **preferred**: ensure `~/projects/<name>` exists, then attach-or-create session `<name>` rooted there |

Why `p` uses `$HOME` (not `~` or `$HOME` on the remote): tmux's `-c` does not expand `~`/`$HOME`,
so the path is expanded **locally** to an absolute path. Valid because both machines' home is
`/home/wynt3r`. The `ssh … mkdir -p` guard makes `p` self-healing (see the vanishing-`~/projects`
gotcha in HANDOFF).

### `~/.claude/settings.json`  *(added the `env` block)*
```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_MOUSE_CLICKS": "1"
  }
}
```
Disables click/drag/hover-to-select in Claude Code prompts (keeps scroll-wheel scrolling). Read at
**startup** — restart `claude` to apply. `CLAUDE_CODE_DISABLE_MOUSE_CLICKS` needs v2.1.195+
(this box runs 2.1.198). Alternative `CLAUDE_CODE_DISABLE_MOUSE=1` kills all mouse tracking incl.
scroll. (Other keys in the file — `effortLevel`, `tui`, `theme`, `skipDangerousModePermissionPrompt`
— are user settings, not part of this workstream.)

---

## Server — wynt3rcompute1 (192.168.5.200)

### `~/.bashrc`  *(appended — project-scoped session helper)*
```bash
# --- wynt3r: project-scoped tmux session (named after current directory) ---
# Run from inside a project dir:  cd ~/projects/foo && tat  -> session "foo" rooted there
tat() { local n; n=$(basename "$PWD" | tr '.' '_'); tmux new -A -s "$n" -c "$PWD"; }
```
`tat` = "attach here": from inside any dir, make/attach a session named after that dir (dots → `_`
so the name is tmux-safe), rooted at the current path. The on-box counterpart to workstation `p`.

### `~/projects/`  *(created)*
Convention root: one sub-directory per project, `~/projects/<name>`; each maps 1:1 to a tmux session.

### `~/.tmux.conf`  *(full file)*
```tmux
set -g mouse on
set -g history-limit 50000
set -sg escape-time 10
set -g focus-events on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %
bind c new-window -c "#{pane_current_path}"
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
bind r source-file ~/.tmux.conf \; display-message "tmux.conf reloaded"
setw -g mode-keys vi
set -g status-interval 5
set -g status-left " #S | "
set -g status-right "#H  %Y-%m-%d %H:%M "

# --- plugins (TPM): reboot persistence via resurrect + continuum ---
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @resurrect-capture-pane-contents 'on'
set -g @continuum-restore 'on'
# Keep this run line LAST in the file:
run '~/.tmux/plugins/tpm/tpm'
```

Key custom bindings (prefix = `Ctrl+b`; space = "then press", a *sequence* not a chord):

| Keys | Action |
|------|--------|
| `Ctrl+b \|` / `Ctrl+b -` | split vertical / horizontal (inherit cwd) |
| `Ctrl+b h j k l` | move between panes |
| `Ctrl+b c` | new window (inherit cwd) |
| `Ctrl+b r` | reload `~/.tmux.conf` |
| `Ctrl+b [` | scroll/copy mode (vi keys) |
| `Ctrl+b Ctrl+s` / `Ctrl+b Ctrl+r` | resurrect: save / restore |

### TPM plugins  *(installed at `~/.tmux/plugins/`)*
- `tpm`, `tmux-resurrect`, `tmux-continuum`.
- Install/update headless (env var must be exported for the standalone installer, and the running
  server must have sourced the config so it knows the path):
  ```bash
  git clone --depth 1 https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  tmux start-server; tmux has-session 2>/dev/null || tmux new-session -d -s _tpm
  tmux source-file ~/.tmux.conf
  ~/.tmux/plugins/tpm/bin/install_plugins
  tmux kill-session -t _tpm 2>/dev/null
  ```
- `@continuum-restore 'on'` → auto-restore on server start; continuum auto-saves ~every 15 min.
  Restores layout + cwd (+ pane-text snapshot), **not** running processes.

---

## Quick verification

```bash
# workstation
bash -n ~/.bashrc                                   # syntax OK
# server
ssh -o BatchMode=yes wynt3rcompute1 'bash -n ~/.bashrc; tmux show-options -g @continuum-restore; ls -ld ~/projects'
# simulate "p demo" server-side without an interactive mosh:
ssh -o BatchMode=yes wynt3rcompute1 'mkdir -p ~/projects/demo; tmux new-session -d -s demo -c ~/projects/demo; tmux display-message -p -t demo "#{pane_current_path}"; tmux kill-session -t demo; rmdir ~/projects/demo'
```
