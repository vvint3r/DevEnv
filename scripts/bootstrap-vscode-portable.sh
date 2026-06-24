#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS_URL_DEFAULT="https://raw.githubusercontent.com/vvint3r/devenv/main/vscode/vscode-explorer-bold.css"
EXT_FILE_DEFAULT="$ROOT_DIR/vscode/extensions.required.txt"

CSS_URL="$CSS_URL_DEFAULT"
EXT_FILE="$EXT_FILE_DEFAULT"
SETTINGS_PATH="${VSCODE_SETTINGS_PATH:-}"
WRITE_SETTINGS=0
SKIP_INSTALL=0

to_file_uri() {
  local path="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$path" <<'PY'
import pathlib
import sys
print(pathlib.Path(sys.argv[1]).resolve().as_uri())
PY
  else
    # Best-effort fallback for POSIX paths.
    echo "file://$path"
  fi
}

LOCAL_CSS_URI="$(to_file_uri "$ROOT_DIR/vscode/vscode-explorer-bold.css")"
TARGET_CSS_URL="$CSS_URL"

usage() {
  cat <<'USAGE'
Usage:
  bootstrap-vscode-portable.sh [options]

Options:
  --settings <path>     Path to local VS Code user settings.json to validate.
  --write-settings      Add CSS URL into settings if missing.
  --css-url <url>       Override default CSS URL.
  --ext-file <path>     Extension list file (default: vscode/extensions.required.txt).
  --skip-install        Skip extension installation.
  -h, --help            Show help.

Examples:
  bash scripts/bootstrap-vscode-portable.sh \
    --settings "$APPDATA/Code - Insiders/User/settings.json" \
    --write-settings

  bash scripts/bootstrap-vscode-portable.sh \
    --settings "$APPDATA/Cursor/User/settings.json" \
    --css-url "https://raw.githubusercontent.com/vvint3r/devenv/main/vscode/vscode-explorer-bold.css" \
    --write-settings
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --settings)
      SETTINGS_PATH="$2"
      shift 2
      ;;
    --write-settings)
      WRITE_SETTINGS=1
      shift
      ;;
    --css-url)
      CSS_URL="$2"
      shift 2
      ;;
    --ext-file)
      EXT_FILE="$2"
      shift 2
      ;;
    --skip-install)
      SKIP_INSTALL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$ROOT_DIR/vscode/vscode-explorer-bold.css" ]]; then
  echo "ERROR: Missing CSS file at $ROOT_DIR/vscode/vscode-explorer-bold.css" >&2
  exit 1
fi

if [[ ! -f "$EXT_FILE" ]]; then
  echo "ERROR: Extension manifest not found: $EXT_FILE" >&2
  exit 1
fi

echo "==> Resolving CSS source"
if command -v curl >/dev/null 2>&1; then
  if curl -fsSLI "$CSS_URL" >/dev/null 2>&1; then
    echo "OK: Cloud CSS URL is reachable"
    TARGET_CSS_URL="$CSS_URL"
  else
    echo "WARN: Cloud CSS URL not reachable: $CSS_URL"
    echo "INFO: Falling back to local CSS URI: $LOCAL_CSS_URI"
    TARGET_CSS_URL="$LOCAL_CSS_URI"
  fi
else
  echo "WARN: curl not found; using local CSS URI: $LOCAL_CSS_URI"
  TARGET_CSS_URL="$LOCAL_CSS_URI"
fi

find_vscode_cli() {
  local candidates=("${VSCODE_CLI:-}" code-insiders code cursor codium code-oss)
  local cmd
  for cmd in "${candidates[@]}"; do
    [[ -z "$cmd" ]] && continue
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "$cmd"
      return 0
    fi
  done
  return 1
}

if [[ "$SKIP_INSTALL" -eq 0 ]]; then
  echo "==> Installing required extensions"
  if CLI="$(find_vscode_cli)"; then
    while IFS= read -r line; do
      line="${line%%#*}"
      line="$(echo "$line" | xargs)"
      [[ -z "$line" ]] && continue
      echo "Installing $line via $CLI"
      "$CLI" --install-extension "$line" --force >/dev/null || {
        echo "WARN: Failed to install $line via $CLI"
      }
    done < "$EXT_FILE"
  else
    echo "WARN: Could not find VS Code CLI (code-insiders/code/cursor). Skipping extension install."
  fi
fi

if [[ -z "$SETTINGS_PATH" ]]; then
  echo "==> Settings check skipped (pass --settings <path> to validate/apply imports)"
  echo "Done."
  exit 0
fi

echo "==> Validating settings at: $SETTINGS_PATH"
if [[ ! -f "$SETTINGS_PATH" ]]; then
  echo "ERROR: settings.json not found: $SETTINGS_PATH" >&2
  exit 1
fi

python3 - "$SETTINGS_PATH" "$TARGET_CSS_URL" "$WRITE_SETTINGS" <<'PY'
import json
import os
import shutil
import sys
from datetime import datetime

settings_path, css_url, write_flag = sys.argv[1], sys.argv[2], sys.argv[3] == "1"

with open(settings_path, "r", encoding="utf-8") as f:
    data = json.load(f)

imports = data.get("vscode_custom_css.imports")
if not isinstance(imports, list):
    imports = []

if css_url in imports:
    print("OK: settings already include CSS URL")
else:
    if write_flag:
        imports.append(css_url)
        data["vscode_custom_css.imports"] = imports
        backup = f"{settings_path}.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
        shutil.copy2(settings_path, backup)
        with open(settings_path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=4)
            f.write("\n")
        print(f"UPDATED: added CSS URL to settings")
        print(f"BACKUP: {backup}")
    else:
        print("MISSING: settings do not include CSS URL")
        print("TIP: re-run with --write-settings")

print("NEXT: Run 'Reload Custom CSS and JS' then 'Developer: Reload Window'.")
PY

echo "Done."
