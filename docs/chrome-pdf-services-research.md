# Chrome PDF Services Research

**Date:** January 2026
**macOS Version:** Tahoe (26)
**Chrome Version:** Current as of January 2026

## Summary

macOS PDF Services workflows (custom entries in the Print dialog's PDF menu) work correctly in Safari but fail silently in Google Chrome. This document captures research findings for future reference.

## The Problem

When using the system print dialog in Chrome (accessed via Cmd+Option+P), the PDF menu shows custom workflows like "Save to Web Receipts". However, clicking these menu items:
- Does not produce any file
- Does not show any error message
- The menu item click succeeds (AppleScript returns success)
- Safari works perfectly with the same workflow

## Root Cause Analysis

### Chrome's Print Architecture

Chrome implements its own printing stack rather than using native macOS APIs directly. Even when accessing the "system print dialog" via Cmd+Option+P, Chrome's implementation differs from native apps:

1. **Custom Print Preview**: Chrome's default print dialog (Cmd+P) is entirely custom HTML/JS
2. **System Dialog Wrapper**: The "system dialog" (Cmd+Option+P) appears native but Chrome still handles the PDF generation and workflow callbacks differently
3. **Sandboxing**: Chrome's security sandbox may interfere with executing external workflows

### Evidence from Research

1. **Electron Issues**: Chromium-based Electron apps have documented issues with PDF menu options causing crashes or silent failures
   - https://github.com/electron/electron/issues/25397
   - https://github.com/electron/electron/issues/24458

2. **Mac Forums Reports**: Users report "Print Failed" errors specific to Chrome/Brave while Safari works
   - https://www.mac-forums.com/threads/chrome-fails-to-print-to-anything.379964/

3. **MacScripter Discussion**: Chrome lacks native AppleScript PDF export support
   - https://www.macscripter.net/t/print-to-pdf-from-chrome/75563

4. **Chromium Bug Tracker**: Multiple printing-related bugs on macOS, though no specific PDF Services bug was found
   - https://bugs.chromium.org/

### Why Safari Works

Safari uses native macOS Cocoa printing APIs (NSPrintOperation, NSPrintPanel) which properly integrate with:
- PDF Services folder aliases (`~/Library/PDF Services/`)
- Automator print workflows
- Shell script PDF services

Chrome reimplements much of this stack, breaking the callback mechanism that macOS uses to execute PDF workflows.

## Attempted Solutions

### 1. Direct PDF Menu Click (Failed)
```applescript
click menu item "Save to Web Receipts" of menu 1 of menu button 1
```
- Menu item clicks successfully
- No file is produced
- No error is returned

### 2. Chrome Headless Mode (Not Practical)
```bash
chrome --print-to-pdf=output.pdf <url>
```
- Would require re-fetching the URL
- Profile locking issues if Chrome is already running
- Loses page state (forms, scroll position, dynamic content)
- Some sites detect and block headless mode

### 3. Manual Save Dialog (Current Solution)
Use Chrome's built-in "Save as PDF" destination and manually navigate to the target folder using:
- Cmd+Shift+G to open "Go to Folder" sheet
- Type the destination path
- Click Save

This works reliably but requires more AppleScript automation.

## Current Implementation

- **Safari**: Uses "Save to Web Receipts" PDF workflow (simple, one menu click)
- **Chrome**: Uses manual approach with Save as PDF + folder navigation

## Future Investigation Ideas

1. **Check Chrome Flags**: `chrome://flags` may have printing-related experiments
2. **Chrome Enterprise Policies**: There may be policies that affect print behavior
3. **File a Chromium Bug**: Report this as a bug at https://crbug.com with specific repro steps
4. **Test Firefox**: Firefox reportedly uses native macOS print dialog and may support PDF Services
5. **Monitor macOS Updates**: Apple may change PDF Services behavior in future releases
6. **Monitor Chrome Updates**: Google may fix this in a future Chrome release

## Relevant Links

- macOS PDF Services: https://macmost.com/expanding-your-save-as-pdf-options.html
- Creating PDF Services: https://jms1.net/osx-pdf-services.shtml
- Chrome System Print Dialog: https://best-mac-tips.com/2017/06/30/force-google-chrome-to-use-mac-os-x-system-print-dialogue/
- Automator Print Plugins: https://www.macosxautomation.com/automator/print/index.html

## Test Environment

- macOS Tahoe 26.2
- Google Chrome (current)
- Safari (current)
- PDF workflow: Folder alias in `~/Library/PDF Services/` pointing to `~/Documents/Web Receipts/`

## Conclusion

This appears to be a limitation in how Chrome/Chromium implements macOS printing. The workaround of using Chrome's built-in "Save as PDF" with manual folder navigation is reliable, though less elegant than Safari's one-click solution.

Re-test when:
- macOS 27 is released
- Major Chrome version updates occur
- Someone reports this working in Chromium bug tracker
