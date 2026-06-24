# devenv

Portable VS Code profile + bootstrap for consistent setup across machines.

## Included

- `vscode/vscode-explorer-bold.css`: Explorer bold-folder style (expanded folders).
- `vscode/extensions.required.txt`: Required extension IDs.
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

## Final Activation (in VS Code)

1. Run `Reload Custom CSS and JS`.
2. Run `Developer: Reload Window`.

## Notes

- Keep `vscode_custom_css.imports` in local user/profile settings, not remote workspace settings.
- Re-run `Reload Custom CSS and JS` after VS Code updates.
