import AppKit
import Carbon
import Darwin
import Foundation
import IOKit
import OSLog

private func reportedPIDs() -> [pid_t] {
    let root = IORegistryGetRootEntry(kIOMainPortDefault)
    guard root != IO_OBJECT_NULL else { return [] }
    defer { IOObjectRelease(root) }
    guard let sessions = IORegistryEntryCreateCFProperty(
        root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0
    )?.takeRetainedValue() as? [[String: Any]] else { return [] }
    let pids = sessions.compactMap { session -> pid_t? in
        guard let number = session["kCGSSessionSecureInputPID"] as? NSNumber,
              CFGetTypeID(number) == CFNumberGetTypeID(),
              let pid = pid_t(exactly: number.doubleValue), pid > 0 else { return nil }
        return pid
    }
    return Set(pids).sorted()
}

@MainActor
private func processName(for pid: pid_t) -> String {
    if let name = NSRunningApplication(processIdentifier: pid)?.localizedName,
       !name.isEmpty {
        return name
    }
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
    let pathLength = buffer.withUnsafeMutableBufferPointer {
        proc_pidpath(pid, $0.baseAddress, UInt32($0.count))
    }
    if pathLength > 0 {
        let path = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        return URL(fileURLWithPath: path).lastPathComponent
    }
    let nameLength = buffer.withUnsafeMutableBufferPointer {
        proc_name(pid, $0.baseAddress, UInt32($0.count))
    }
    if nameLength > 0 {
        return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }
    return "process name unavailable"
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preview = CommandLine.arguments.contains("--preview")
    private let logger = Logger(subsystem: "com.luckman212.secureinputsentry", category: "status")
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var detailsItem: NSMenuItem?
    private var lastEnabled: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = makeStatusItem()
        refresh()

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func refresh() {
        guard let item = statusItem else { return }
        let enabled = IsSecureEventInputEnabled()
        if enabled != lastEnabled {
            logger.notice("Secure Input enabled: \(enabled, privacy: .public)")
            lastEnabled = enabled
        }

        guard enabled || preview else {
            if item.isVisible { item.isVisible = false }
            return
        }

        let title = enabled ? "Secure Input is enabled" : "Secure Input is off"
        let details: String
        if enabled {
            let holders = reportedPIDs().map { "\(processName(for: $0)) (PID \($0))" }
            details = holders.isEmpty
                ? "Holder PID unavailable"
                : "Locked by: \(holders.joined(separator: ", "))"
        } else {
            details = "Preview mode keeps this icon visible"
        }

        let tooltip = "\(title)\n\(details)"
        if item.button?.toolTip != tooltip {
            item.button?.toolTip = tooltip
            item.button?.setAccessibilityLabel(tooltip)
            detailsItem?.title = details
        }
        if !item.isVisible { item.isVisible = true }
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let icon = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Secure Input") {
            icon.isTemplate = true
            item.button?.image = icon
        } else {
            item.button?.title = "🔒"
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        let details = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        details.isEnabled = false
        menu.addItem(details)
        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit Secure Input Sentry",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)
        item.menu = menu
        detailsItem = details
        return item
    }
}

@main
private struct SecureInputApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
