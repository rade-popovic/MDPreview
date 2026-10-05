# MD Preview

A read-only Markdown viewer for macOS that behaves like Preview: double-click a `.md` file, get a window.

GitHub-style rendering (tables, task lists, code highlighting), light/dark mode, relative images,
live reload when the file changes, search, zoom and print. Everything works offline.

Includes a Quick Look extension, so pressing Space on a `.md` file in Finder shows the same rendering.

## Build

```bash
./build.sh            # builds build/MD Preview.app
./build.sh install    # also copies it to /Applications
```

Requires Xcode command line tools, macOS 14+.

To make it the default for `.md` files, use **MD Preview → Make Default Markdown Viewer**, or Finder's
Get Info → Open with → Change All.

## Layout

- `Sources/MDPreview` — SwiftUI app (`DocumentGroup(viewing:)`) hosting a `WKWebView`
- `Resources/web` — page template, renderer glue and styles; `vendor/` holds marked, DOMPurify,
  highlight.js and github-markdown-css
- `QuickLook` — Quick Look preview extension; renders with `Resources/web/core.js` in JavaScriptCore
- `scripts/make-icon.swift` — regenerates `Resources/AppIcon.icns`
