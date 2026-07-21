# DevEnv

Portable VS Code profile + bootstrap for consistent setup across machines.

For the full end-to-end replication walkthrough (new workstations, WSL, Remote-SSH,
what's one-time vs. recurring, publishing changes) see **[SETUP.md](SETUP.md)**.

## Included

- `vscode/vscode-explorer-bold.css`: Explorer bold-folder style (expanded folders).
- `vscode/extensions.required.txt`: Required extension IDs.
- `vscode/fonts.required.txt`: Required base fonts for consistent UI rendering.
- `vscode/REPLICATION_TIERS.md`: Tier 1/2/3 replication matrix.
- `vscode/SYNC_QUICK_REFERENCE.md`: End-to-end machine setup/update workflow.
- `vscode/UI_SELECTOR_REFERENCE.md`: Map of VS Code UI components → CSS/JS selectors for custom-css tweaks.
- `scripts/bootstrap-vscode-portable.sh`: One-run bootstrap script (CSS, fonts, VS Code extensions).
- `scripts/setup-agents.sh`: Installs Claude Code CLI and OpenAI Codex CLI; seeds their config templates.
- `agents/claude/settings.json`: Claude Code settings template (model, effort, theme, editor preferences).
- `agents/codex/config.toml`: Codex CLI config template (model, personality, TUI theme).
- `agents/.env.example`: API key reference — copy relevant lines to your shell profile.
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
- `--install-fonts`: Install missing fonts in `vscode/fonts.required.txt` - tries apt first (needs passwordless sudo or root), then falls back to a direct download from Google's open-source fonts repo into `~/.local/share/fonts` (no sudo required, works on any Linux machine).

If the cloud URL is not reachable (for example private GitHub repo), the script automatically falls back to a local file URI from your cloned repo.

## Agent CLIs

```bash
bash scripts/setup-agents.sh
```

What it does in one run:

1. Installs `@anthropic-ai/claude-code` and `@openai/codex` globally via npm (skips if already present).
2. Seeds `~/.claude/settings.json` and `~/.codex/config.toml` from the templates in `agents/` — only if the target does not already exist.

**Credentials are never stored in this repo.** After running, add your API keys to `~/.zshrc` or `~/.bashrc`:

```bash
export ANTHROPIC_API_KEY="sk-ant-api03-..."   # console.anthropic.com → API Keys
export OPENAI_API_KEY="sk-..."                # platform.openai.com/api-keys
```

Alternatively, authenticate interactively: `claude` launches a browser login flow for Max/Pro subscribers (no API key required); `codex` has its own interactive auth.

See `agents/.env.example` for the full credential reference. Partial setup options:

```bash
bash scripts/setup-agents.sh --skip-codex      # Claude only
bash scripts/setup-agents.sh --skip-claude     # Codex only
bash scripts/setup-agents.sh --force-configs   # Re-deploy config templates (backs up first)
bash scripts/setup-agents.sh --help
```

## Final Activation (in VS Code)

1. Run `Reload Custom CSS and JS`.
2. Run `Developer: Reload Window`.

## Notes

- Keep `vscode_custom_css.imports` in local user/profile settings, not remote workspace settings.
- On a Remote-SSH/Remote-WSL connection the custom-CSS extension runs on the **client** (your Windows host), so the CSS file and its import must live client-side. Use `--css-dest <path>` to copy the repo CSS to a client-readable location and auto-derive the correct `file:///C:/...` URI (a `/mnt/<drive>/` dest is translated for you on WSL); `--css-uri <uri>` overrides that derivation. See **[SETUP.md](SETUP.md)** → "Custom CSS on a Remote-SSH / Remote-WSL client".
- Re-run `Reload Custom CSS and JS` after VS Code updates.
- If you want direct cloud URL imports on any machine without cloning, make the repository (or the CSS file endpoint) publicly reachable.
- Fonts are validated by manifest; `--install-fonts` covers all four required fonts now (apt where a real package exists, direct download otherwise) - manual install is only needed if a machine has no internet access to `raw.githubusercontent.com`.
