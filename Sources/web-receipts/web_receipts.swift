import Foundation
import AppKit

@main
struct WebReceipts {
    static let destinationFolder = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Web Receipts")

    static func main() {
        do {
            try run()
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    static func run() throws {
        // Ensure destination folder exists
        try FileManager.default.createDirectory(
            at: destinationFolder,
            withIntermediateDirectories: true
        )

        // Detect frontmost browser
        guard let browser = detectFrontmostBrowser() else {
            throw WebReceiptsError.noBrowserFound
        }

        // Export PDF (browser provides filename from tab title)
        try exportPDF(browser: browser)

        print("Saved to Web Receipts")
    }

    enum Browser {
        case safari
        case chrome
    }

    enum WebReceiptsError: LocalizedError {
        case noBrowserFound
        case appleScriptError(String)

        var errorDescription: String? {
            switch self {
            case .noBrowserFound:
                return "No supported browser (Safari or Chrome) is frontmost"
            case .appleScriptError(let message):
                return "AppleScript error: \(message)"
            }
        }
    }

    // MARK: - Browser Detection

    static func detectFrontmostBrowser() -> Browser? {
        let script = """
            tell application "System Events"
                set frontApp to name of first application process whose frontmost is true
            end tell
            return frontApp
        """

        guard let result = runAppleScript(script) else { return nil }

        switch result.lowercased() {
        case "safari":
            return .safari
        case "google chrome":
            return .chrome
        default:
            return nil
        }
    }

    // MARK: - PDF Export

    static func exportPDF(browser: Browser) throws {
        switch browser {
        case .safari:
            try exportSafariPDF()
        case .chrome:
            try exportChromePDF()
        }
    }

    static func exportSafariPDF() throws {
        let script = """
            tell application "Safari" to activate
            delay 0.5

            -- Open Print dialog with Cmd+P
            tell application "System Events"
                tell process "Safari"
                    keystroke "p" using {command down}
                end tell
            end tell
            delay 1

            -- Click PDF menu button and select "Save as PDF"
            tell application "System Events"
                tell process "Safari"
                    tell splitter group 1 of sheet 1 of front window
                        tell group 2
                            click menu button 1
                            delay 0.3
                            click menu item "Save as PDF…" of menu 1 of menu button 1
                        end tell
                    end tell
                end tell
            end tell
            delay 0.5

            -- Navigate to folder with Cmd+Shift+G
            tell application "System Events"
                keystroke "g" using {command down, shift down}
            end tell
            delay 0.5

            -- Type path and go
            tell application "System Events"
                keystroke "\(escapeForAppleScript(destinationFolder.path))"
                delay 0.3
                keystroke return
            end tell
            delay 1

            -- Press Return to Save
            tell application "System Events"
                keystroke return
            end tell
            delay 1
        """

        guard runAppleScript(script) != nil else {
            throw WebReceiptsError.appleScriptError("Failed to export Safari PDF")
        }
    }

    static func exportChromePDF() throws {
        let script = """
            tell application "Google Chrome" to activate
            delay 1.5

            tell application "System Events"
                tell process "Google Chrome"
                    set frontmost to true
                    delay 0.5
                    -- Use key code for Cmd+P (key code 35 = P)
                    key code 35 using {command down}
                end tell
            end tell
            delay 3

            -- Press Enter to open Save dialog (assumes "Save as PDF" is selected)
            tell application "System Events"
                key code 36
            end tell
            delay 1

            -- Navigate to folder with Cmd+Shift+G
            tell application "System Events"
                tell process "Google Chrome"
                    tell sheet 1 of front window
                        keystroke "g" using {command down, shift down}
                    end tell
                end tell
            end tell
            delay 0.5

            -- Type path and go
            tell application "System Events"
                keystroke "\(escapeForAppleScript(destinationFolder.path))"
                delay 0.3
                keystroke return
            end tell
            delay 1

            -- Press Return to Save (Save button is default)
            tell application "System Events"
                keystroke return
            end tell
            delay 2
        """

        guard runAppleScript(script) != nil else {
            throw WebReceiptsError.appleScriptError("Failed to export Chrome PDF")
        }
    }

    // MARK: - AppleScript Helpers

    static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&error)

        if let error = error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            fputs("AppleScript error: \(message)\n", stderr)
            return nil
        }

        return result?.stringValue ?? ""
    }

    static func escapeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
