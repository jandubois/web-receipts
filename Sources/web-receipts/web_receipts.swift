import Foundation
import AppKit

@main
struct WebReceipts {
    static let version = "0.1.0"

    static func main() {
        let args = CommandLine.arguments.dropFirst()

        if args.contains("--version") || args.contains("-v") {
            print("web-receipts \(version)")
            return
        }

        if args.contains("--help") || args.contains("-h") {
            printHelp()
            return
        }

        do {
            try run()
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    static func printHelp() {
        print("""
            web-receipts - Save browser tabs as PDF receipts

            USAGE:
                web-receipts [OPTIONS]

            OPTIONS:
                -h, --help      Show this help message
                -v, --version   Show version number

            DESCRIPTION:
                Saves the current tab from the frontmost browser (Safari or Chrome)
                as a PDF to ~/Documents/Web Receipts/

                The filename is derived from the tab title. Duplicate filenames
                are handled by appending .2, .3, etc.

            SETUP:
                Requires a "Save to Web Receipts" PDF workflow in the system.
                Bind to a hotkey using Automator, Shortcuts, Alfred, or similar.
            """)
    }

    static func run() throws {
        guard let browser = detectFrontmostBrowser() else {
            throw WebReceiptsError.noBrowserFound
        }

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
            delay 0.3

            -- Open Print dialog
            tell application "System Events"
                tell process "Safari"
                    keystroke "p" using {command down}
                end tell
            end tell
            delay 1

            -- Click PDF menu and select "Save to Web Receipts"
            tell application "System Events"
                tell process "Safari"
                    tell splitter group 1 of sheet 1 of front window
                        tell group 2
                            click menu button 1
                            delay 0.3
                            click menu item "Save to Web Receipts" of menu 1 of menu button 1
                        end tell
                    end tell
                end tell
            end tell
            delay 0.5
        """

        guard runAppleScript(script) != nil else {
            throw WebReceiptsError.appleScriptError("Failed to export Safari PDF")
        }
    }

    static func exportChromePDF() throws {
        // Chrome uses Cmd+Option+P to open the system print dialog
        let script = """
            tell application "Google Chrome" to activate
            delay 0.3

            -- Open system Print dialog (Cmd+Option+P)
            tell application "System Events"
                tell process "Google Chrome"
                    keystroke "p" using {command down, option down}
                end tell
            end tell
            delay 1.5

            -- Click PDF menu and select "Save to Web Receipts"
            tell application "System Events"
                tell process "Google Chrome"
                    tell group 2 of splitter group 1 of window "Print"
                        click menu button 1
                        delay 0.3
                        click menu item "Save to Web Receipts" of menu 1 of menu button 1
                    end tell
                end tell
            end tell
            delay 0.5
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
}
