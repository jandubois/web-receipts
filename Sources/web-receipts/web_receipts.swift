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

        // Get tab title and generate unique filename
        let title = try getTabTitle(browser: browser)
        let filename = generateUniqueFilename(base: sanitizeFilename(title))

        // Export PDF
        try exportPDF(browser: browser, filename: filename)

        print("Saved: \(filename)")
    }

    enum Browser {
        case safari
        case chrome
    }

    enum WebReceiptsError: LocalizedError {
        case noBrowserFound
        case appleScriptError(String)
        case noTitle

        var errorDescription: String? {
            switch self {
            case .noBrowserFound:
                return "No supported browser (Safari or Chrome) is frontmost"
            case .appleScriptError(let message):
                return "AppleScript error: \(message)"
            case .noTitle:
                return "Could not get tab title"
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

    // MARK: - Tab Title

    static func getTabTitle(browser: Browser) throws -> String {
        let script: String
        switch browser {
        case .safari:
            script = """
                tell application "Safari"
                    return name of current tab of front window
                end tell
            """
        case .chrome:
            script = """
                tell application "Google Chrome"
                    return title of active tab of front window
                end tell
            """
        }

        guard let title = runAppleScript(script), !title.isEmpty else {
            throw WebReceiptsError.noTitle
        }
        return title
    }

    // MARK: - Filename Handling

    static func sanitizeFilename(_ filename: String) -> String {
        // Characters not allowed in macOS filenames
        let invalidCharacters = CharacterSet(charactersIn: ":/\\")
        var sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "-")

        // Trim whitespace and limit length
        sanitized = sanitized.trimmingCharacters(in: .whitespaces)
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }

        return sanitized.isEmpty ? "Untitled" : sanitized
    }

    static func generateUniqueFilename(base: String) -> String {
        let pdfName = "\(base).pdf"
        let targetPath = destinationFolder.appendingPathComponent(pdfName)

        if !FileManager.default.fileExists(atPath: targetPath.path) {
            return base  // Return without .pdf extension
        }

        // File exists, find unique name with suffix
        var counter = 2
        while true {
            let newName = "\(base).\(counter)"
            let newPath = destinationFolder.appendingPathComponent("\(newName).pdf")
            if !FileManager.default.fileExists(atPath: newPath.path) {
                return newName
            }
            counter += 1
        }
    }

    // MARK: - PDF Export

    static func exportPDF(browser: Browser, filename: String) throws {
        switch browser {
        case .safari:
            try exportSafariPDF(filename: filename)
        case .chrome:
            try exportChromePDF(filename: filename)
        }
    }

    static func exportSafariPDF(filename: String) throws {
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

            -- Set filename (Tahoe: elements are in splitter group 1 of the save sheet)
            tell application "System Events"
                tell process "Safari"
                    tell splitter group 1 of sheet 1 of sheet 1 of front window
                        click text field "Save As:"
                        delay 0.2
                        keystroke "a" using {command down}
                        delay 0.1
                        keystroke "\(escapeForAppleScript(filename))"
                    end tell
                end tell
            end tell
            delay 0.3

            -- Navigate to folder with Cmd+Shift+G
            tell application "System Events"
                keystroke "g" using {command down, shift down}
            end tell
            delay 0.5

            -- Click on Go To Folder text field before typing
            tell application "System Events"
                tell process "Safari"
                    tell sheet 1 of sheet 1 of sheet 1 of front window
                        click text field 1
                        delay 0.2
                        keystroke "a" using {command down}
                        delay 0.1
                        keystroke "\(escapeForAppleScript(destinationFolder.path))"
                        delay 0.3
                        keystroke return
                    end tell
                end tell
            end tell
            delay 0.5

            -- Click Save button
            tell application "System Events"
                tell process "Safari"
                    tell splitter group 1 of sheet 1 of sheet 1 of front window
                        click button "Save"
                    end tell
                end tell
            end tell
            delay 1
        """

        guard runAppleScript(script) != nil else {
            throw WebReceiptsError.appleScriptError("Failed to export Safari PDF")
        }
    }

    static func exportChromePDF(filename: String) throws {
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

            -- Set filename (Tahoe: elements are in splitter group 1, dialog is on window "Print")
            -- Chrome doesn't auto-add .pdf extension, so include it
            tell application "System Events"
                tell process "Google Chrome"
                    tell splitter group 1 of sheet 1 of window "Print"
                        click text field "Save As:"
                        delay 0.2
                        keystroke "a" using {command down}
                        delay 0.1
                        keystroke "\(escapeForAppleScript(filename)).pdf"
                    end tell
                end tell
            end tell
            delay 0.3

            -- Navigate to folder with Cmd+Shift+G
            tell application "System Events"
                tell process "Google Chrome"
                    keystroke "g" using {command down, shift down}
                end tell
            end tell
            delay 0.5

            -- Click on Go To Folder text field before typing
            tell application "System Events"
                tell process "Google Chrome"
                    tell sheet 1 of sheet 1 of window "Print"
                        click text field 1
                        delay 0.2
                        keystroke "a" using {command down}
                        delay 0.1
                        keystroke "\(escapeForAppleScript(destinationFolder.path))"
                        delay 0.3
                        keystroke return
                    end tell
                end tell
            end tell
            delay 0.5

            -- Click Save button (Tahoe: button is in splitter group 1)
            tell application "System Events"
                tell process "Google Chrome"
                    tell splitter group 1 of sheet 1 of window "Print"
                        click button "Save"
                    end tell
                end tell
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
