# VS Code Portable Sync Quick Reference

This is the end-to-end workflow for keeping your VS Code setup consistent across machines.

## What this sync system copies

- Extension inventories and install sets
- Extension version lock file
- Workspace VS Code helper files
- Profile map defaults
- User-data captures when available (settings, keybindings, snippets, profiles)
- Published bundle metadata and latest pointer

For detailed automation coverage, see:

- `vscode/REPLICATION_TIERS.md`

## Source of truth

- Tooling and published bundles live in this repo:
  - `devenv/vscode/sync-bundles/latest.tar.gz`
- Bundle generation/import commands run from your workspace where this script exists:
  - `.vscode/scripts/extensions-lean.sh`

## One-time setup on each machine

1. Clone or pull the repo:

```bash
git clone https://github.com/vvint3r/devenv.git ~/devenv
# or
cd ~/devenv && git pull
```

2. Ensure your profile map is set on the machine that will publish updates:

```bash
cd /path/to/workspace-root
bash .vscode/scripts/extensions-lean.sh profile-map-init
```

Then edit:

- `.vscode/profile-map.env`

Set these values if the files exist on that machine:

- `PROFILE_SETTINGS_FILE`
- `PROFILE_KEYBINDINGS_FILE`
- `PROFILE_SNIPPETS_DIR`

If snippets do not exist, keep `PROFILE_SNIPPETS_DIR` empty.

3. (Optional but recommended) Check/install required fonts from repo manifest:

```bash
cd ~/devenv
bash scripts/bootstrap-vscode-portable.sh --skip-install --install-fonts
```

Then verify with workspace sync tooling:

```bash
cd /path/to/workspace-root
bash .vscode/scripts/extensions-lean.sh fonts-check
cat .vscode/fonts.presence.txt
```

## New machine: replicate from latest bundle

From your workspace root (the one containing `.vscode/scripts/extensions-lean.sh`):

```bash
cd /path/to/workspace-root
bash .vscode/scripts/extensions-lean.sh sync-import ~/devenv/vscode/sync-bundles/latest.tar.gz install-locked
```

Then restart VS Code.

If you use Custom CSS features, also run:

1. Reload Custom CSS and JS
2. Developer: Reload Window

## Any machine: publish your latest changes

After changing themes, extensions, MCP/user settings, keybindings, etc.:

```bash
cd /path/to/workspace-root
bash .vscode/scripts/extensions-lean.sh sync-publish
```

This does all of the following in one command:

- Creates a fresh sync bundle
- Publishes it to `~/devenv/vscode/sync-bundles/`
- Updates stable pointers:
  - `latest.tar.gz`
  - `latest.txt`
  - `latest.json`

## Push published changes to GitHub

```bash
cd ~/devenv
git status
git add vscode/sync-bundles
git commit -m "Publish latest VS Code sync bundle"
git push
```

## Other machines: pull and apply

```bash
cd ~/devenv
git pull

cd /path/to/workspace-root
bash .vscode/scripts/extensions-lean.sh sync-import ~/devenv/vscode/sync-bundles/latest.tar.gz install-locked
```

## Recommended team habit

1. Always publish from the machine where you made config changes.
2. Always commit and push `devenv/vscode/sync-bundles` after publish.
3. On every other machine, pull repo first, then run sync-import from `latest.tar.gz`.

## Troubleshooting

- If extension listing from VS Code CLI fails in shell, the script automatically falls back to filesystem scanning.
- If profile settings are missing in bundle, verify `.vscode/profile-map.env` paths on the publishing machine.
- If visual tweaks are missing, run the two UI reload commands listed above.
- If fonts differ between machines, check `vscode/fonts.required.txt` and `.vscode/fonts.presence.txt`.
