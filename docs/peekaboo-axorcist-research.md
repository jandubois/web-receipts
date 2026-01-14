# Peekaboo and AXorcist Research

**Date:** January 2026
**macOS Version:** Tahoe (26)
**Purpose:** Document alternative UI automation approaches for future reference

## Summary

Peekaboo is a macOS automation tool that uses direct accessibility APIs (via AXorcist) and CGEvents instead of AppleScript. This document captures research findings in case we need to make web-receipts more robust in the future.

## Current web-receipts Approach

We use AppleScript with System Events for UI automation:
```applescript
keystroke "p" using {command down}
click menu button 1
click menu item "Save to Web Receipts" of menu 1 of menu button 1
```

This works but is fragile - UI hierarchy paths like `splitter group 1 of sheet 1 of window "Print"` break when macOS updates change the UI structure.

## Peekaboo Architecture

Peekaboo (https://github.com/steipete/Peekaboo) is a comprehensive macOS automation suite with:

### Key Commands
- `peekaboo see` - Capture and analyze UI elements, returns element IDs
- `peekaboo see --annotate` - Generate annotated screenshots with interaction markers
- `peekaboo click` - Click elements by ID, query, or coordinates
- `peekaboo type` - Type text
- `peekaboo hotkey` - Send keyboard shortcuts

### How It Differs from AppleScript

| Aspect | AppleScript | Peekaboo/AXorcist |
|--------|-------------|-------------------|
| UI queries | Indirect via System Events | Direct AXUIElement API |
| Input simulation | System Events → CGEvents | Direct CGEvents |
| Element finding | Hierarchy paths | Fuzzy scoring algorithm |
| Error handling | Limited | Comprehensive |

### Service Architecture
Located in `Core/PeekabooAutomationKit/Sources/PeekabooAutomationKit/`:
- `Services/UI/ClickService.swift` - Mouse interactions
- `Services/UI/HotkeyService.swift` - Keyboard shortcuts
- `Services/UI/TypeService.swift` - Text input
- `Services/UI/ElementDetectionService.swift` - UI element discovery

## AXorcist Library

AXorcist (https://github.com/steipete/AXorcist) is a Swift wrapper around macOS accessibility APIs.

### Key Files

**Input Simulation** (`Sources/AXorcist/Core/Element+UIAutomation.swift`):
- `Element.clickAt(_:button:clickCount:)` - Click at screen coordinates
- `Element.typeText(_:delay:)` - Type unicode text via CGEvents
- `Element.typeKey(_:modifiers:)` - Press special keys (Return, Tab, etc.)
- `Element.performHotkey(keys:holdDuration:)` - Keyboard shortcuts

**Low-Level Driver** (`Sources/AXorcist/Core/InputDriver.swift`):
- Thin wrapper delegating to Element methods
- `InputDriver.click(at:button:count:)`
- `InputDriver.hotkey(keys:holdDuration:)`
- `InputDriver.type(_:delayPerCharacter:)`

### CGEvent-Based Keyboard Input

The key insight is how AXorcist sends keyboard input (from `Element+UIAutomation.swift`):

```swift
// Hotkey with modifiers (e.g., Cmd+Shift+G)
public static func performHotkey(keys: [String], holdDuration: TimeInterval = 0.1) throws {
    var modifiers: CGEventFlags = []
    var mainKey: SpecialKey?

    for key in keys {
        switch key.lowercased() {
        case "cmd", "command": modifiers.insert(.maskCommand)
        case "shift": modifiers.insert(.maskShift)
        case "option", "opt", "alt": modifiers.insert(.maskAlternate)
        case "ctrl", "control": modifiers.insert(.maskControl)
        default:
            mainKey = SpecialKey(rawValue: key.lowercased())
        }
    }

    try typeKey(mainKey!, modifiers: modifiers)
}

// Single key with modifiers
public static func typeKey(_ key: SpecialKey, modifiers: CGEventFlags = []) throws {
    guard let keyCode = key.keyCode else { throw ... }

    let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
    keyDown.flags = modifiers

    let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)!
    keyUp.flags = modifiers

    keyDown.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.001)
    keyUp.post(tap: .cghidEventTap)
}
```

### Key Codes Reference

From `SpecialKey` enum in `Element+UIAutomation.swift`:
```
escape: 53    tab: 48       space: 49     delete: 51
return: 36    up: 126       down: 125     left: 123
right: 124    p: 35         g: 5          s: 1
```

### Element Finding

AXorcist provides fuzzy element matching (`ClickService.swift` lines 202-248):
- Scores matches by: identifier (400pts) → label (350pts) → title (300pts) → value (200pts)
- Falls back through multiple attribute types
- Deterministic tie-breaking by Y position

This is more robust than AppleScript's exact path matching.

## Potential Migration Path

If AppleScript becomes unreliable, we could:

### Option 1: Extract Keyboard Input Only (~100 lines)
Copy from `Element+UIAutomation.swift`:
- `performHotkey()`, `typeKey()`, `typeText()`
- `SpecialKey` enum with key codes
- Keep AppleScript for element finding

### Option 2: Add AXorcist as Dependency
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/steipete/AXorcist", from: "1.0.0"),
]
```
Use full accessibility APIs for element finding and interaction.

### Option 3: Use Peekaboo for Development Only
Keep AppleScript in production, use `peekaboo see --json` to debug UI hierarchy when things break.

## Using Peekaboo for Debugging

When the AppleScript breaks (e.g., after macOS update):

```bash
# Capture UI state
peekaboo see --app "Safari" --json > /tmp/safari-ui.json

# Find specific elements
cat /tmp/safari-ui.json | jq '.data.ui_elements[] | select(.label | contains("PDF"))'

# Get annotated screenshot
peekaboo see --app "Safari" --annotate --path /tmp/safari-debug.png
```

A Claude Code skill file exists at `~/.claude/skills/peekaboo-gui-debugging/SKILL.md` with more details.

## Why We're Keeping AppleScript For Now

1. **It works** - Current implementation is functional
2. **Simplicity** - AppleScript is ~80 lines, CGEvent approach would be more
3. **No dependencies** - Self-contained binary
4. **Debugging available** - Peekaboo can help when things break

## When to Revisit

- macOS 27 breaks the current UI hierarchy
- We need to support more browsers (Firefox, Arc, etc.)
- AppleScript reliability becomes a recurring problem
- We want to add features requiring precise element targeting

## Relevant Source Locations

### Peekaboo
- Click service: `Core/PeekabooAutomationKit/Sources/.../Services/UI/ClickService.swift`
- Hotkey service: `Core/PeekabooAutomationKit/Sources/.../Services/UI/HotkeyService.swift`
- Element detection: `Core/PeekabooAutomationKit/Sources/.../Services/UI/ElementDetectionService.swift`

### AXorcist
- UI automation: `Sources/AXorcist/Core/Element+UIAutomation.swift`
- Input driver: `Sources/AXorcist/Core/InputDriver.swift`
- Element core: `Sources/AXorcist/Core/Element.swift`
- App wrapper: `Sources/AXorcist/Core/AXApp.swift`
