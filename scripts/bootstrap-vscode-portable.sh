#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS_URL_DEFAULT="https://raw.githubusercontent.com/vvint3r/devenv/main/vscode/vscode-explorer-bold.css"
EXT_FILE_DEFAULT="$ROOT_DIR/vscode/extensions.required.txt"
FONTS_FILE_DEFAULT="$ROOT_DIR/vscode/fonts.required.txt"

CSS_URL="$CSS_URL_DEFAULT"
EXT_FILE="$EXT_FILE_DEFAULT"
FONTS_FILE="$FONTS_FILE_DEFAULT"
SETTINGS_PATH="${VSCODE_SETTINGS_PATH:-}"
WRITE_SETTINGS=0
SKIP_INSTALL=0
SKIP_FONT_CHECK=0
INSTALL_FONTS=0
CSS_DEST=""
CSS_URI_OVERRIDE=""

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

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
  grep -qi microsoft /proc/version 2>/dev/null
}

usage() {
  cat <<'USAGE'
Usage:
  bootstrap-vscode-portable.sh [options]

Options:
  --settings <path>     Path to local VS Code user settings.json to validate.
  --write-settings      Add CSS URL into settings if missing.
  --css-url <url>       Override default CSS URL.
  --css-dest <path>     Copy the repo CSS to <path> (a client-readable location) and
                        point the settings import at it. On WSL a /mnt/<drive>/ dest is
                        auto-translated to the Windows file:///C:/... URI the UI
                        extension actually needs. Backs up any existing file first.
  --css-uri <uri>       Explicit import URI to write into settings (overrides the URI
                        derived from --css-dest or the default CSS source).
  --ext-file <path>     Extension list file (default: vscode/extensions.required.txt).
  --fonts-file <path>   Font list file (default: vscode/fonts.required.txt).
  --skip-font-check     Skip checking whether required fonts are installed.
  --install-fonts       Try installing missing fonts on Linux (apt).
  --skip-install        Skip extension installation.
  -h, --help            Show help.

Examples:
  Native Windows (PowerShell/Git Bash, $APPDATA is a real env var there):
    bash scripts/bootstrap-vscode-portable.sh \
      --settings "$APPDATA/Code - Insiders/User/settings.json" \
      --write-settings

  Native Linux / Cursor:
    bash scripts/bootstrap-vscode-portable.sh \
      --settings "$HOME/.config/Cursor/User/settings.json" \
      --css-url "https://raw.githubusercontent.com/vvint3r/devenv/main/vscode/vscode-explorer-bold.css" \
      --write-settings

  Remote-SSH / Remote-WSL (editor UI runs on Windows, connects into this host):
  $APPDATA is a Windows-only env var and is NOT exported into a WSL/SSH remote
  shell - it silently resolves to an empty string there. Also, on a remote
  target the flat User/settings.json often doesn't exist or is empty, because
  most UI-level settings stay client-side; the ones that apply to *this*
  remote host live in that remote's Machine scope instead. Don't guess - verify
  what's actually there first:
    find ~/.vscode-server-insiders/data -maxdepth 2 -iname "settings.json"
  then, typically:
    bash scripts/bootstrap-vscode-portable.sh \
      --settings "$HOME/.vscode-server-insiders/data/Machine/settings.json" \
      --write-settings
  See SETUP.md for the full decision table (covers Remote-SSH vs Remote-WSL,
  local-desktop, and what to do if that file doesn't exist yet).
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
    --css-dest)
      CSS_DEST="$2"
      shift 2
      ;;
    --css-uri)
      CSS_URI_OVERRIDE="$2"
      shift 2
      ;;
    --ext-file)
      EXT_FILE="$2"
      shift 2
      ;;
    --fonts-file)
      FONTS_FILE="$2"
      shift 2
      ;;
    --skip-font-check)
      SKIP_FONT_CHECK=1
      shift
      ;;
    --install-fonts)
      INSTALL_FONTS=1
      shift
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

check_font_present() {
  local font="$1"
  fc-list : family | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -Fxqi "$font"
}

# Direct-download fallback, sourced from Google's canonical open-source fonts repo
# (github.com/google/fonts). Installs per-user into ~/.local/share/fonts - no sudo/root
# needed, no distro package required, works identically on any Linux machine.
download_font_from_google_fonts() {
  local font="$1"
  local -a entries=()

  case "$font" in
    "Fira Code")
      entries=(
        "https://raw.githubusercontent.com/google/fonts/main/ofl/firacode/FiraCode%5Bwght%5D.ttf|FiraCode-VF.ttf"
      )
      ;;
    "Inter")
      entries=(
        "https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf|Inter-VF.ttf"
        "https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter-Italic%5Bopsz%2Cwght%5D.ttf|Inter-Italic-VF.ttf"
      )
      ;;
    "Nunito")
      entries=(
        "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf|Nunito-VF.ttf"
        "https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito-Italic%5Bwght%5D.ttf|Nunito-Italic-VF.ttf"
      )
      ;;
    "Google Sans Code")
      entries=(
        "https://raw.githubusercontent.com/google/fonts/main/ofl/googlesanscode/GoogleSansCode%5Bwght%5D.ttf|GoogleSansCode-VF.ttf"
        "https://raw.githubusercontent.com/google/fonts/main/ofl/googlesanscode/GoogleSansCode-Italic%5Bwght%5D.ttf|GoogleSansCode-Italic-VF.ttf"
      )
      ;;
    *)
      echo "INFO: No known Google Fonts source mapping for '$font'; install manually."
      return 1
      ;;
  esac

  if ! command -v curl >/dev/null 2>&1; then
    echo "WARN: curl not found; cannot download '$font'."
    return 1
  fi

  local dest_dir="${HOME}/.local/share/fonts/devenv"
  mkdir -p "$dest_dir"

  local entry url dest_name ok=0
  for entry in "${entries[@]}"; do
    url="${entry%%|*}"
    dest_name="${entry##*|}"
    if curl -fsSL "$url" -o "$dest_dir/$dest_name"; then
      ok=1
    else
      echo "WARN: Failed to download $url"
      rm -f "$dest_dir/$dest_name"
    fi
  done

  if [[ "$ok" -eq 1 ]]; then
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$dest_dir" >/dev/null 2>&1
    echo "Installed '$font' into $dest_dir (per-user, no sudo required)."
    return 0
  fi

  return 1
}

install_font_linux_apt() {
  local font="$1"
  local apt_cmd=""
  local pkg=""
  local -a candidates=()

  case "$font" in
    "Fira Code")
      candidates=("fonts-firacode")
      ;;
    "Inter")
      candidates=("fonts-inter")
      ;;
    *)
      candidates=()
      ;;
  esac

  if [[ "${#candidates[@]}" -gt 0 ]]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
      apt_cmd="sudo apt-get"
    elif command -v apt-get >/dev/null 2>&1 && [[ "$(id -u)" -eq 0 ]]; then
      apt_cmd="apt-get"
    fi

    if [[ -n "$apt_cmd" ]]; then
      for pkg in "${candidates[@]}"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
          echo "Installing package '$pkg' for font '$font'"
          $apt_cmd install -y "$pkg" && return 0
        fi
      done
      echo "WARN: No available apt package found for '$font' (checked: ${candidates[*]})."
    else
      echo "INFO: No passwordless sudo/root available; skipping apt install for '$font'."
    fi
  fi

  echo "INFO: Falling back to direct download from Google's open-source fonts repo for '$font'."
  download_font_from_google_fonts "$font"
}

if [[ "$SKIP_FONT_CHECK" -eq 0 ]]; then
  echo "==> Checking required fonts"
  if [[ ! -f "$FONTS_FILE" ]]; then
    echo "WARN: Font manifest not found: $FONTS_FILE"
  elif ! command -v fc-list >/dev/null 2>&1; then
    echo "WARN: fc-list not found (fontconfig missing); cannot verify installed fonts."
  else
    missing_fonts=()
    while IFS= read -r line; do
      font="${line%%#*}"
      font="$(echo "$font" | xargs)"
      [[ -z "$font" ]] && continue
      if check_font_present "$font"; then
        echo "FONT OK: $font"
      else
        echo "FONT MISSING: $font"
        missing_fonts+=("$font")
      fi
    done < "$FONTS_FILE"

    if [[ "$INSTALL_FONTS" -eq 1 && "${#missing_fonts[@]}" -gt 0 ]]; then
      echo "==> Attempting to install missing fonts"
      if command -v apt-get >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1 && sudo -n true >/dev/null 2>&1; then
          sudo apt-get update -y || true
        fi
      fi

      for font in "${missing_fonts[@]}"; do
        install_font_linux_apt "$font" || true
      done

      echo "==> Re-checking fonts after install attempt"
      for font in "${missing_fonts[@]}"; do
        if check_font_present "$font"; then
          echo "FONT OK: $font"
        else
          echo "FONT STILL MISSING: $font"
        fi
      done
    fi
  fi
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

# --- Optional: deploy CSS to a client-readable location -----------------------
# be5invis.vscode-custom-css is a CLIENT/UI extension: it reads the CSS file from the
# machine running the VS Code *window*, not the remote/server it is connected to. When
# bootstrapping from inside WSL or a Remote-SSH target, "the client" is the Windows host
# - so the CSS must be copied somewhere Windows can read, and the import URI must be the
# Windows path (file:///C:/...), NOT the WSL path (file:///mnt/c/...). --css-dest does
# both: copy the repo CSS to <path> and derive the correct client URI for the settings write.
if [[ -n "$CSS_DEST" ]]; then
  echo "==> Deploying CSS to client location: $CSS_DEST"
  css_dest_dir="$(dirname "$CSS_DEST")"
  if [[ ! -d "$css_dest_dir" ]]; then
    echo "ERROR: --css-dest parent directory does not exist: $css_dest_dir" >&2
    echo "       Point --css-dest at a path whose parent already exists." >&2
    exit 1
  fi
  if [[ -f "$CSS_DEST" ]]; then
    css_backup="${CSS_DEST}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "$CSS_DEST" "$css_backup"
    echo "BACKUP: $css_backup"
  fi
  cp "$ROOT_DIR/vscode/vscode-explorer-bold.css" "$CSS_DEST"
  echo "COPIED: repo CSS -> $CSS_DEST"

  if [[ -n "$CSS_URI_OVERRIDE" ]]; then
    TARGET_CSS_URL="$CSS_URI_OVERRIDE"
  elif [[ "$CSS_DEST" == /mnt/[A-Za-z]/* ]] && command -v wslpath >/dev/null 2>&1; then
    # WSL path pointing at a Windows file: the Windows client needs a Windows URI.
    css_win_path="$(wslpath -w "$CSS_DEST")"   # e.g. C:\Users\Me\.vscode-explorer-bold.css
    TARGET_CSS_URL="file:///${css_win_path//\\//}"
  else
    TARGET_CSS_URL="$(to_file_uri "$CSS_DEST")"
  fi
  echo "CSS import URI (for --settings write): $TARGET_CSS_URL"
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

  # Remote-SSH/Remote-WSL server installs ship a real CLI binary under
  # ~/.vscode-server*/code[-insiders]-<commit-hash> - it's just not on PATH.
  # Several commit versions can coexist across reconnects; use the newest.
  local pattern binary
  local -a server_globs=(
    "${HOME}/.vscode-server-insiders/code-insiders-"*
    "${HOME}/.vscode-server/code-"*
  )
  local -a found=()
  for pattern in "${server_globs[@]}"; do
    [[ -f "$pattern" && -x "$pattern" ]] && found+=("$pattern")
  done

  if [[ "${#found[@]}" -gt 0 ]]; then
    binary="$(ls -t "${found[@]}" 2>/dev/null | head -n 1)"
    [[ -n "$binary" ]] && { echo "$binary"; return 0; }
  fi

  return 1
}

if [[ "$SKIP_INSTALL" -eq 0 ]]; then
  echo "==> Installing required extensions"
  if CLI="$(find_vscode_cli)"; then
    echo "Using VS Code CLI: $CLI"
    while IFS= read -r line; do
      line="${line%%#*}"
      line="$(echo "$line" | xargs)"
      [[ -z "$line" ]] && continue
      echo "Installing $line via $CLI"
      install_output="$("$CLI" --install-extension "$line" --force 2>&1)" && install_rc=0 || install_rc=$?
      # This specific failure mode prints its error to stdout and still exits 0,
      # so it must be checked independently of install_rc, not gated behind it.
      if [[ "$install_output" == *"declared to not run in this setup"* ]]; then
        echo "INFO: '$line' is UI-only and can't be installed on this remote/server side by design."
        echo "INFO: Install it yourself from the Extensions panel (search '$line'), using the"
        echo "      dropdown next to Install to choose 'Install Locally' if you're connected to a remote."
      elif [[ "$install_rc" -ne 0 ]]; then
        echo "WARN: Failed to install $line via $CLI"
        echo "$install_output" | sed 's/^/  /'
      fi
    done < "$EXT_FILE"
  else
    echo "WARN: Could not find VS Code CLI (code-insiders/code/cursor, including remote server binaries). Skipping extension install."
  fi
fi

if [[ -z "$SETTINGS_PATH" ]]; then
  if is_wsl; then
    echo "==> Settings check skipped (pass --settings <path> to validate/apply imports)"
    echo "INFO: On a Remote-SSH/Remote-WSL target, the file that matters is usually this"
    echo "      remote's Machine scope, not a local desktop path. Verify what's actually"
    echo "      present before guessing:"
    echo "        find ~/.vscode-server-insiders/data -maxdepth 2 -iname settings.json"
    echo "      See SETUP.md for the full decision table."
  else
    echo "==> Settings check skipped (pass --settings <path> to validate/apply imports)"
  fi
  echo "Done."
  exit 0
fi

echo "==> Validating settings at: $SETTINGS_PATH"
if [[ ! -f "$SETTINGS_PATH" ]]; then
  if [[ "$WRITE_SETTINGS" -eq 1 && -d "$(dirname "$SETTINGS_PATH")" ]]; then
    # A remote Machine-scope settings.json (and some fresh User-scope ones) simply
    # doesn't exist until the first setting is ever written there - VS Code treats
    # that as an empty {} scope, not an error. Only bail if the parent dir is also
    # missing, which means this location was never a real settings scope at all.
    echo "INFO: settings.json does not exist yet at this location - seeding an empty one (normal for a scope nothing has written to before)."
    printf '{}\n' > "$SETTINGS_PATH"
  else
    echo "ERROR: settings.json not found: $SETTINGS_PATH" >&2
    echo "TIP: if this is a remote Machine-scope path, its parent directory only appears" >&2
    echo "     after you've connected to that remote at least once in VS Code. Re-run with" >&2
    echo "     --write-settings to create the file if the parent directory does exist." >&2
    exit 1
  fi
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
