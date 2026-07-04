# VS Code UI selector reference (for custom CSS / JS)

A practical map of the VS Code **workbench DOM** so you can target specific UI elements
with `be5invis.vscode-custom-css` (or any injected CSS/JS). This is the piece the
official docs don't give you: the [Theme Color reference][theme-colors] lists *color
tokens* (settings keys), but not *which DOM element* each one paints or how to select it.

> **Read this first — two different customization systems**
>
> | System | What it edits | Stability | Use it for |
> |---|---|---|---|
> | **Theme colors** (`workbench.colorCustomizations` in settings) | Named color tokens like `list.activeSelectionBackground` | **Official & stable** | Recoloring anything that has a token — always prefer this |
> | **Custom CSS** (this doc, via custom-css extension) | Raw workbench DOM (classes like `.monaco-list-row`) | **Unofficial, version-fragile** | Layout, weight, spacing, sizing, effects with no color token |
>
> Rule of thumb: if you only want to change a **color**, do it with a theme token
> (stable). Reach for CSS selectors when you need **structure/typography/effects** the
> token system can't express — e.g. our bold-expanded-folders tweak
> (`vscode-explorer-bold.css`).

[theme-colors]: https://code.visualstudio.com/api/references/theme-color

---

## The one skill that never goes stale: inspect it yourself

Class names below are **internal**, not a public API, and they drift between VS Code
versions. The durable skill is reading them off the live DOM:

1. **Help → Toggle Developer Tools** (`Ctrl+Shift+I`, macOS `Cmd+Opt+I`). This opens
   Chrome DevTools against the workbench renderer.
2. Click the **element-picker** (top-left of DevTools, `Ctrl+Shift+C`) and hover/click
   the UI element you want. The Elements panel highlights its node and you can read its
   `class` list and walk up to parents.
3. In the **Styles** pane you can live-edit CSS and watch the result before committing
   it to your `.css` file.
4. For **editor text** (tokens/syntax, not chrome) use the command
   **Developer: Inspect Editor Tokens and Scopes** instead — that's a TextMate scope, not
   a DOM class.

Everything below is "as of VS Code ~1.9x (2026)"; when something doesn't match, inspect.

---

## Workbench layout → root selectors

```
┌───────────────────────────────────────────────── .part.titlebar ┐
│ menubar          window-title            layout/actions          │
├──┬────────────────────────────────────────────────┬─────────────┤
│  │ .part.sidebar (Explorer / Search / SCM / …)     │             │
│ .│  ┌ .pane-header (section title) ─────────────┐  │  .part.     │
│ p│  └ .pane-body → .monaco-list (the tree) ─────┘  │  .auxiliary │
│ a│                                                 │  bar        │
│ r├─────────────────── .part.editor ───────────────┤  (secondary │
│ t│ .tabs-container → .tab   |  .breadcrumbs        │   side bar) │
│ .│ ┌─────────── .monaco-editor ───────────────┐   │             │
│ a│ │  .view-lines / .minimap / .margin        │   │             │
│ c│ └──────────────────────────────────────────┘   │             │
│ t├──────────────────── .part.panel ───────────────┤             │
│ i│  Terminal (.xterm) / Problems / Output          │             │
│ v│                                                 │             │
│ .├─────────────────────────────────────────────────┴────────────┤
│  │ .part.statusbar   left items      right items                 │
└──┴───────────────────────────────────────────────────────────────┘
```

Root is `.monaco-workbench`. Each major region is a `.part`:

| Region | Selector | Notes |
|---|---|---|
| Whole shell | `.monaco-workbench` | prefix for high-specificity overrides |
| Title bar | `.monaco-workbench .part.titlebar` | custom title bar; holds menubar + `.window-title` |
| Menu bar | `.menubar`, `.menubar .action-item` | items in the title bar |
| Activity bar | `.monaco-workbench .part.activitybar` | the icon rail |
| Side bar | `.monaco-workbench .part.sidebar` | Explorer/Search/SCM container |
| Secondary side bar | `.monaco-workbench .part.auxiliarybar` | the right-hand panel |
| Editor area | `.monaco-workbench .part.editor` | tabs + editors |
| Panel | `.monaco-workbench .part.panel` | terminal/problems/output |
| Status bar | `.monaco-workbench .part.statusbar` | bottom bar |

---

## Explorer / tree (the most-targeted area)

The file tree is a `monaco-list` of virtualized rows. This is what our bold-folder CSS
hooks into.

| Element | Selector | Notes |
|---|---|---|
| Explorer viewlet | `.explorer-viewlet` / `.explorer-folders-view` | the Explorer as a whole |
| The list | `.monaco-list` | scroll/focus container |
| A row | `.monaco-list-row` (a.k.a. `.monaco-tl-row`) | one file/folder line |
| Twistie (chevron) | `.monaco-tl-twistie` | expand/collapse arrow |
| Indent guides | `.monaco-tl-indent .indent-guide` | the vertical guides |
| Icon + label wrap | `.monaco-icon-label` | holds icon, name, description |
| File/folder icon | `.monaco-icon-label::before` | the themed icon glyph |
| **Name text** | `.label-name` / `.monaco-icon-label .label-name` | what we bold |
| Dimmed suffix | `.label-description` | e.g. git path, symbol detail |
| Git/problem badge | `.monaco-decoration-iconBadge`, `.explorer-item` decorations | file-decoration colors have tokens |

**State selectors (combine with the above):**

| State | Selector | Example use |
|---|---|---|
| Expanded folder | `.monaco-list-row[aria-expanded="true"]` | our bold tweak |
| Collapsed folder | `.monaco-list-row[aria-expanded="false"]` | |
| Selected | `.monaco-list-row.selected` | |
| Focused (keyboard) | `.monaco-list:focus .monaco-list-row.focused` | active-list only |
| Hover | `.monaco-list-row:hover` | |
| Is a folder (has twistie) | `.monaco-list-row:has(.monaco-tl-twistie:not(.collapsible))` | `:has()` is supported in modern VS Code Electron |
| Cut (pending move) | `.monaco-list-row.cut` | |

Example — bold **and** slightly indent expanded folders, color via a theme token:

```css
.explorer-folders-view .monaco-list-row[aria-expanded="true"] .label-name {
  font-weight: 700 !important;
  color: var(--vscode-foreground) !important;   /* theme-safe; see token section */
}
```

---

## Editor tabs, breadcrumbs, editor body

| Element | Selector | Notes |
|---|---|---|
| Editor group | `.editor-group-container` | one split |
| Tab strip | `.tabs-container` | the row of tabs |
| A tab | `.tab` | |
| Active tab | `.tab.active` | focused editor's tab |
| Dirty (unsaved) tab | `.tab.dirty` | shows the dot |
| Pinned tab | `.tab.pinned` | |
| Tab label | `.tab .label-name` (`.monaco-icon-label`) | tab filename text |
| Tab close/actions | `.tab .tab-actions` | |
| Breadcrumbs | `.monaco-breadcrumbs`, `.breadcrumbs-control` | path bar under tabs |
| Breadcrumb item | `.monaco-breadcrumb-item` | |
| Editor (Monaco) | `.monaco-editor` | the code surface |
| Text rows | `.view-lines`, `.view-line` | actual code lines |
| Current line highlight | `.monaco-editor .current-line` | |
| Line-number gutter | `.monaco-editor .margin`, `.line-numbers` | |
| Cursor | `.monaco-editor .cursor` | |
| Minimap | `.monaco-editor .minimap` | |
| Sticky scroll | `.sticky-widget`, `.sticky-line-content` | pinned headers |

---

## Other regions

**Activity bar**
| Element | Selector |
|---|---|
| Icon item | `.activitybar .action-item` |
| Active item | `.activitybar .action-item.active`, `.activitybar .action-item.checked` |
| Active indicator bar | `.activitybar .action-item.active .active-item-indicator` |
| Badge (e.g. SCM count) | `.activitybar .badge`, `.badge-content` |

**Side-bar section headers**
| Element | Selector |
|---|---|
| Pane header | `.pane-header`, `.pane-header .title` |
| Pane body | `.pane-body` |
| Viewlet title (Explorer:) | `.composite.title`, `.sidebar .title-label` |

**Panel / integrated terminal**
| Element | Selector |
|---|---|
| Panel title tabs | `.part.panel .composite.title`, `.panel-switcher-container` |
| Terminal | `.terminal`, `.integrated-terminal` |
| xterm surface | `.xterm`, `.xterm-rows`, `.xterm-screen` | (terminal colors have their own `terminal.*` tokens) |

**Status bar**
| Element | Selector |
|---|---|
| An item | `.statusbar .statusbar-item` |
| Left / right groups | `.statusbar-item.left`, `.statusbar-item.right` |
| Item icon | `.statusbar-item .codicon` |
| Prominent item | `.statusbar-item.has-background-color` |

**Command palette / quick input**
| Element | Selector |
|---|---|
| Widget | `.quick-input-widget` |
| Input box | `.quick-input-box .input` |
| Results list | `.quick-input-list .monaco-list-row` |
| Highlighted match | `.quick-input-list .highlight` |

**Context menus**
| Element | Selector |
|---|---|
| Menu | `.monaco-menu`, `.context-view .monaco-menu` |
| Menu item | `.monaco-menu .action-item` |
| Separator | `.monaco-menu .action-item .action-label.separator` |

**Notifications**
| Element | Selector |
|---|---|
| Toasts (corner) | `.notifications-toasts`, `.notification-toast` |
| Center (bell) | `.notifications-center`, `.notification-list-item` |

**Scrollbars** (everywhere)
| Element | Selector |
|---|---|
| Track | `.monaco-scrollable-element > .scrollbar` |
| Thumb | `.monaco-scrollable-element > .scrollbar > .slider` |

**Icons (global)** — VS Code uses the **codicon** font. Any glyph is
`.codicon.codicon-<name>` (e.g. `.codicon-chevron-right`). Great for restyling arrows,
close buttons, etc.

---

## Using theme tokens *inside* your CSS (the bridge to the official reference)

Every entry in the [Theme Color reference][theme-colors] is exposed to the DOM as a CSS
variable named `--vscode-<token>` with `.` replaced by `-`. So you can pull stable,
theme-aware colors into custom CSS instead of hardcoding hex:

```css
/* token  list.activeSelectionForeground  ->  --vscode-list-activeSelectionForeground */
.monaco-list:focus .monaco-list-row.focused.selected .label-name {
  color: var(--vscode-list-activeSelectionForeground) !important;
}
```

This is why our folder tweak uses `var(--vscode-foreground)` — it stays legible on light
**and** dark themes. Handy tokens and where they live:

| Token → variable | Paints |
|---|---|
| `foreground` → `--vscode-foreground` | default UI text |
| `focusBorder` → `--vscode-focusBorder` | focus outlines |
| `list.activeSelectionBackground` / `…Foreground` | selected tree row (focused list) |
| `list.hoverBackground` | tree row hover |
| `sideBar.background` / `sideBar.foreground` | the side bar |
| `editorGroupHeader.tabsBackground` | tab strip background |
| `tab.activeBackground` / `tab.activeForeground` | active tab |
| `statusBar.background` / `statusBar.foreground` | status bar |
| `activityBar.background` / `activityBar.foreground` | activity bar |
| `terminal.background` / `terminal.foreground` | integrated terminal |

Prefer setting these via `workbench.colorCustomizations` when you just want a recolor;
use `var(--vscode-*)` in CSS only when you're *also* doing something structural.

---

## JS injection (advanced, use sparingly)

The custom-css extension also accepts `.js` files in `vscode_custom_css.imports`. Injected
JS runs in the workbench renderer with DOM access — you can add elements, observe the tree
with a `MutationObserver`, wire up buttons, etc. Caveats:

- It runs with full renderer privileges — only import scripts **you** wrote/trust.
- It re-runs on every **Reload Custom CSS and JS**; make it idempotent (guard against
  double-inserting nodes).
- Virtualized lists (Explorer, editor tabs) recycle DOM nodes on scroll — target via
  stable containers + delegation, not one-shot queries.
- It's unsupported and can break on any VS Code update — keep it small and defensive.

---

## Deploying & reloading (ties into this repo)

1. Put your `.css`/`.js` in this repo (`vscode/`), keep it as the source of truth.
2. Deploy it to the **client** and wire the import — on a Remote-SSH/WSL setup that's the
   Windows client, so use the bootstrap helper:
   ```bash
   bash scripts/bootstrap-vscode-portable.sh \
     --css-dest "/mnt/c/Users/<you>/.vscode-explorer-bold.css" --skip-install --skip-font-check
   ```
   (See **[SETUP.md](../SETUP.md)** → "Custom CSS on a Remote-SSH / Remote-WSL client".)
3. In the editor: **Reload Custom CSS and JS**, then **Developer: Reload Window**. Re-run
   the CSS reload after each VS Code update — updates overwrite the extension's patch.

## Stability & maintenance

- These selectors are **not a public API**. When one stops working, inspect the live DOM
  (top of this doc) and update it here.
- Always scope to a `.part`/viewlet container and add `!important` — the built-in styles
  are specific and load after nothing else does.
- Pin the mental model to **regions**, not exact classes: the `.part.*` layout and the
  `monaco-list` / `monaco-icon-label` / `codicon` building blocks have been stable for
  years even as leaf classes churn.
