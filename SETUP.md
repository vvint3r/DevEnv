# Setup: replicating this environment on another workstation

End-to-end steps for getting a new machine to match this one - extensions, fonts,
custom CSS, editor settings, and agent CLIs. Primary target is **VS Code Insiders**. Notes on Cursor
are called out explicitly where they differ; don't assume Cursor unless you're
actually configuring a Cursor machine.

## Two layers this repo provides

- **Lightweight bootstrap** (`scripts/bootstrap-vscode-portable.sh`, documented in
  `README.md`): custom CSS import, font check/install, and the real portable
  extension set. Cross-platform (Windows/Linux/macOS - needs bash + python3).
- **Sync system** (`.vscode/scripts/extensions-lean.sh` in your workspace, documented
  in `vscode/SYNC_QUICK_REFERENCE.md` / `vscode/REPLICATION_TIERS.md`): version-locked
  extension installs, workspace `tasks.json`/`settings.json`, and a curated editor
  settings snapshot (`profile.settings.json`).
- **Agent CLI setup** (`scripts/setup-agents.sh`): installs Claude Code and Codex CLIs
  and seeds their config files from templates in `agents/`.

## Prerequisites

- bash, python3, curl, git
- Node.js / npm (or nvm) — required for the agent CLI setup step.
- A VS Code Insiders CLI reachable in `PATH` (`code-insiders`) for the extension-install
  steps to run for real instead of falling back to a manifest-only scan.

## New workstation: step by step

**1. Clone:**
```bash
git clone https://github.com/vvint3r/DevEnv.git ~/devenv
```

**2. Bootstrap CSS, fonts, and extensions.**

Point `--settings` at *this machine's actual* VS Code Insiders settings file - which
one that is depends on how you're running the editor here:

| How you're running VS Code Insiders on this machine | `--settings` path |
|---|---|
| Local desktop install (Linux) | `~/.config/Code - Insiders/User/settings.json` |
| Local desktop install (Windows) | `%APPDATA%\Code - Insiders\User\settings.json` |
| Remote-SSH target (editor runs on Windows, connects here) | `~/.vscode-server-insiders/data/Machine/settings.json` |
| Remote-WSL target (editor runs on Windows, connects into WSL) | `~/.vscode-server-insiders/data/Machine/settings.json` (inside the WSL filesystem) |

The Remote-SSH/Remote-WSL case is easy to get wrong - the flat `User/settings.json`
usually doesn't exist or is empty on the remote side, because most UI-level settings
stay client-side. The settings that actually apply to *this remote host* live in the
remote-machine scope instead. Verify before assuming - don't guess:
```bash
find ~/.vscode-server-insiders/data -maxdepth 2 -iname "settings.json"
```

```bash
cd ~/devenv
bash scripts/bootstrap-vscode-portable.sh \
  --settings "<path from the table above>" \
  --write-settings --install-fonts
```

Fonts: Fira Code and Inter try apt first (works if this machine has passwordless sudo
or you're root); otherwise, and always for Nunito and Google Sans Code, it downloads
straight from Google's canonical open-source fonts repo into `~/.local/share/fonts` -
no sudo needed, works on any Linux machine with internet access. Nothing here is
specific to any particular host.

### Custom CSS on a Remote-SSH / Remote-WSL client

`be5invis.vscode-custom-css` is a **client-side UI extension**: it reads both the CSS
file and its `vscode_custom_css.imports` setting from the machine running the VS Code
*window* - on a remote connection that's your **Windows host**, not the remote/WSL
target you're connected to. (This is why installing it on the remote fails with
"declared to not run in this setup", and why a `vscode_custom_css.imports` entry placed
in the remote's Machine-scope `settings.json` does not drive it.) So two things must
land on the client, not the remote:

1. the CSS file, copied somewhere the client can read, and
2. the import wired into the client's **active profile** settings.json - e.g.
   `%APPDATA%\Code - Insiders\User\profiles\<id>\settings.json` - using a client-native
   `file:///C:/...` URI.

From inside WSL you can do both in one run. `--css-dest` copies the repo CSS to the
given `/mnt/<drive>/...` path and auto-translates it (via `wslpath`) to the Windows
`file:///C:/...` URI the extension needs:

```bash
cd ~/devenv
bash scripts/bootstrap-vscode-portable.sh \
  --css-dest "/mnt/c/Users/<you>/.vscode-explorer-bold.css" \
  --settings "/mnt/c/Users/<you>/AppData/Roaming/Code - Insiders/User/profiles/<id>/settings.json" \
  --write-settings --skip-install --skip-font-check
```

Re-running this after you edit the CSS re-deploys it (backing up the previous client
copy first), so the repo stays the single source of truth and the client file never
drifts. Drop `--write-settings` to only re-deploy the file and *validate* (not modify)
the settings - use that once the import is already wired.

Note: `--write-settings` rewrites the target settings.json in a structured way
(4-space indent, strict JSON) - it drops any hand-written `//` comments from that file.
If you keep comments in that particular settings.json, add the one import line by hand
instead. To find the active profile's id, look under
`%APPDATA%\Code - Insiders\User\profiles\` (from WSL:
`/mnt/c/Users/<you>/AppData/Roaming/Code - Insiders/User/profiles/`) - the folder whose
`settings.json` matches the profile you actually work in.

**3. Set up agent CLIs (Claude Code and Codex).**

Requires Node.js / npm (or nvm). Run from the repo root:

```bash
bash scripts/setup-agents.sh
```

This installs `@anthropic-ai/claude-code` and `@openai/codex` globally, then seeds
`~/.claude/settings.json` and `~/.codex/config.toml` from the templates in `agents/`
(only if those files don't already exist — safe to re-run).

**Credentials are not configured by the script** — this repo is public. Add your keys
to `~/.zshrc` or `~/.bashrc` after the script completes:

```bash
export ANTHROPIC_API_KEY="sk-ant-api03-..."   # console.anthropic.com → API Keys
export OPENAI_API_KEY="sk-..."                # platform.openai.com/api-keys
```

See `agents/.env.example` for details, including subscription notes (ChatGPT Plus/Pro
does **not** include API credits — Codex requires a separate platform.openai.com billing
account). If you only have one subscription:

```bash
bash scripts/setup-agents.sh --skip-codex     # Claude only
bash scripts/setup-agents.sh --skip-claude    # Codex only
```

**4. Seed the sync engine into this workspace** (a fresh workspace has no
`.vscode/scripts/extensions-lean.sh` yet):
```bash
mkdir -p .vscode/scripts
tar -xzf ~/devenv/vscode/sync-bundles/latest.tar.gz -C /tmp/devenv-bundle
cp /tmp/devenv-bundle/*/extensions-lean.sh .vscode/scripts/
```

**5. Import the extension lock, workspace config, and editor settings:**
```bash
bash .vscode/scripts/extensions-lean.sh sync-import ~/devenv/vscode/sync-bundles/latest.tar.gz install-locked
```
This installs the version-locked extension set, restores `tasks.json`/`settings.json`,
and automatically merges the captured `profile.settings.json` into whichever local
settings file it can find on this machine (checking the same location set as the table
above, plus local desktop paths) - no manual step needed. Watch its output; if it can't
find a usable target it says so and tells you what to set in `.vscode/profile-map.env`.

**6. In the editor:** run **Reload Custom CSS and JS**, then **Developer: Reload
Window**. Re-run just the CSS reload after any VS Code Insiders version update - the
extension patches the editor's own files, and updates overwrite that patch.

## Connecting to WSL specifically

```powershell
wsl --install -d Ubuntu
```
Then in VS Code Insiders, install the **WSL** extension (`ms-vscode-remote.remote-wsl`,
official Microsoft extension - works cleanly since Insiders is an official Microsoft
build). Connect either by running `code-insiders .` from inside a WSL terminal in your
project directory, or via Command Palette -> **WSL: Connect to WSL**.

(If you're setting up a *Cursor* machine instead: Cursor ships its own built-in remote
extension for this - don't install Microsoft's `ms-vscode-remote.remote-wsl` on top of
it, that combination is currently causing connection conflicts.)

## What's one-time vs. what recurs

Everything in steps 1-5 writes to persistent storage (the machine's real filesystem,
not something that resets on reconnect) - fonts, extensions, settings, the cloned repo,
agent CLIs and their configs. None of it needs repeating just because you close/reopen
the editor, restart WSL (`wsl --shutdown` doesn't wipe the disk), or reboot. The only
recurring action is the CSS reload in step 6, and only after an editor version update -
not tied to session or WSL restarts at all.

## Publishing changes from a source machine

```bash
cd /path/to/workspace-root
bash .vscode/scripts/extensions-lean.sh sync-publish
cd ~/devenv
git add vscode/extensions.required.txt vscode/extensions.lock.txt vscode/sync-bundles
git commit -m "Publish latest sync bundle"
git push
```

`sync-publish` strips `user-data/` (real `mcp.json`/`settings.json`/`keybindings.json`/
`profiles/`) before anything reaches this repo - those files can carry inline API keys
for MCP servers, and this repo is public. Full data still gets captured locally in
`~/.vscode/portable-sync/` for machine-to-machine `sync-import` outside the repo.

Before publishing from a *new* source machine for the first time, set
`.vscode/profile-map.env` correctly for how you're actually running VS Code Insiders
there (see the table above) - a wrong or defaulted path here will silently capture and
publish the wrong editor's settings as the canonical profile snapshot.

## What doesn't replicate

See `vscode/REPLICATION_TIERS.md` for the full breakdown. Always manual regardless of
platform: fonts not covered by the direct-download fallback, any credential/auth/token
state (including agent API keys), OS-level packages, shell/PATH customization.
Cross-OS full settings/keybindings restore (not just the curated `profile.settings.json`)
only works between machines in the same OS family - the automatic restore path uses
Linux/XDG-style paths and has no Windows-native equivalent.
