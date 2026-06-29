# devenv

Portable VS Code profile + bootstrap for consistent setup across machines.

## Included

- `vscode/vscode-explorer-bold.css`: Explorer bold-folder style (expanded folders).
- `vscode/extensions.required.txt`: Required extension IDs.
- `vscode/fonts.required.txt`: Required base fonts for consistent UI rendering.
- `vscode/REPLICATION_TIERS.md`: Tier 1/2/3 replication matrix.
- `vscode/SYNC_QUICK_REFERENCE.md`: End-to-end machine setup/update workflow.
- `scripts/bootstrap-vscode-portable.sh`: One-run bootstrap script.
- `profiles/Pro-Prime_26.code-profile`: Importable profile artifact.

## Bootstrap

Run from repo root:

```bash
bash scripts/bootstrap-vscode-portable.sh \
  --settings "$APPDATA/Code - Insiders/User/settings.json" \
  --write-settings
```

For Cursor:

```bash
bash scripts/bootstrap-vscode-portable.sh \
  --settings "$APPDATA/Cursor/User/settings.json" \
  --write-settings
```

What it does in one run:

1. Validates the cloud CSS URL.
2. Installs required extensions from `vscode/extensions.required.txt`.
3. Validates `vscode_custom_css.imports` in the supplied settings file.
4. Optionally writes missing import URL when `--write-settings` is provided.

Font options:

- `--skip-font-check`: Skip required font verification.
- `--install-fonts`: Attempt Linux apt install for missing fonts in `vscode/fonts.required.txt`.

If the cloud URL is not reachable (for example private GitHub repo), the script automatically falls back to a local file URI from your cloned repo.

## Final Activation (in VS Code)

1. Run `Reload Custom CSS and JS`.
2. Run `Developer: Reload Window`.

## Notes

- Keep `vscode_custom_css.imports` in local user/profile settings, not remote workspace settings.
- Re-run `Reload Custom CSS and JS` after VS Code updates.
- If you want direct cloud URL imports on any machine without cloning, make the repository (or the CSS file endpoint) publicly reachable.
- Fonts are validated by manifest, but some fonts (for example Google Sans Code) may still require manual install.
