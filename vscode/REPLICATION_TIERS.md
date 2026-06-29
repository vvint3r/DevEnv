# Replication Tiers Matrix

This matrix defines what is replicated by the current portable sync process and what remains manual.

## Tier 1: Auto-captured and auto-applied

These are captured into sync bundles and restored by sync-import.

- Extension lists and lock file:
  - `extensions.all.txt`
  - `extensions.active-noncosmetic.txt`
  - `extensions.visual.txt`
  - `extensions.global-defaults.txt`
  - `extensions.portable.txt`
  - `extensions.lock.txt`
- Workspace sync helper files:
  - `settings.json`
  - `tasks.json`
  - `extensions-lean.sh`
- Profile map defaults:
  - `profile-map.env`
- Captured user-data roots when present:
  - user settings/keybindings/mcp
  - snippets directories
  - profile extension metadata
- Sync metadata and latest pointer files in repo:
  - `vscode/sync-bundles/latest.tar.gz`
  - `vscode/sync-bundles/latest.txt`
  - `vscode/sync-bundles/latest.json`

Validation command:

```bash
bash .vscode/scripts/extensions-lean.sh sync-export
```

## Tier 2: Auto-captured with explicit mapping or checks

These are automated, but depend on profile mapping and local machine capabilities.

- Active profile paths mapped in `.vscode/profile-map.env`:
  - `PROFILE_SETTINGS_FILE`
  - `PROFILE_KEYBINDINGS_FILE`
  - `PROFILE_SNIPPETS_DIR`
- Font manifest and presence report:
  - `vscode/fonts.required.txt`
  - `.vscode/fonts.presence.txt` (workspace)
  - bundled `fonts.required.txt` + `fonts.presence.txt`
- Optional bootstrap font installation attempts (Linux apt):
  - `bash scripts/bootstrap-vscode-portable.sh --install-fonts`

Validation commands:

```bash
bash .vscode/scripts/extensions-lean.sh fonts-check
cat .vscode/fonts.presence.txt
```

```bash
bash scripts/bootstrap-vscode-portable.sh --skip-install --install-fonts
```

## Tier 3: Manual (documented, not guaranteed portable)

These require per-machine setup and cannot be fully captured in bundle tarballs.

- Font binaries not in package repos or proprietary sources
  - Example: Google Sans Code usually manual install
- Credentials/auth state
  - GitHub auth, cloud auth, tokens, extension sign-ins
- OS-level packages and system policy/security settings
  - apt packages, sysctl, sandbox/policy constraints
- Toolchain/runtime globals
  - shell profiles, PATH customizations, language toolchains

Manual checklist:

1. Install any missing fonts from `vscode/fonts.required.txt`.
2. Complete local editor sign-ins.
3. Verify OS tooling and package prerequisites.
4. Run UI activation commands after custom CSS changes:
   - Reload Custom CSS and JS
   - Developer: Reload Window

## Standard Process

1. Make changes on a source machine.
2. Publish:

```bash
bash .vscode/scripts/extensions-lean.sh sync-publish
```

3. Push repo updates:

```bash
cd ~/devenv
git add vscode/sync-bundles
# add docs/scripts too if changed
git commit -m "Publish latest VS Code sync bundle"
git push
```

4. On target machine pull and apply:

```bash
cd ~/devenv
git pull

bash .vscode/scripts/extensions-lean.sh sync-import ~/devenv/vscode/sync-bundles/latest.tar.gz install-locked
```
