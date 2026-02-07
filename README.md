# web-receipts

A macOS command-line tool that saves the current browser tab as a PDF to `~/Documents/Web Receipts/`.

## Features

- Supports Safari and Chrome
- Uses the tab title as the filename
- Handles duplicate filenames by appending `.2`, `.3`, etc.
- Records the source URL in macOS metadata (Finder "Where from")
- Designed to be triggered via hotkey

## Requirements

- macOS Tahoe (26) or later
- Accessibility permissions for controlling Safari/Chrome

## Installation

```bash
make release
cp .build/release/web-receipts /usr/local/bin/
```

## Usage

```bash
web-receipts          # Save current browser tab as PDF
web-receipts --help   # Show help
web-receipts --version # Show version
```

## Hotkey Setup

Bind the tool to a keyboard shortcut using:
- Automator (Quick Action)
- Shortcuts app
- Alfred
- Keyboard Maestro
- Karabiner-Elements

## License

Apache License 2.0
