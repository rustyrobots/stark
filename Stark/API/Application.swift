import AppKit
import JavaScriptCore

private let starkVisibilityOptionsKey = "visible"

@objc
protocol ApplicationJSExport: JSExport {
    static func find(_ name: String) -> Application?
    static func launch(_ name: String)

    static func all() -> [Application]
    static func focused() -> Application?

    func windows() -> [Window]
    func windows(_ options: [String: AnyObject]) -> [Window]

    var name: String { get }
    var bundleId: String { get }
    var processId: pid_t { get }

    func activate() -> Bool
    func focus() -> Bool

    func show() -> Bool
    func hide() -> Bool

    var isActive: Bool { get }
    var isHidden: Bool { get }
    var isTerminated: Bool { get }
}

open class Application: NSObject, ApplicationJSExport {
    private var element: AXUIElement
    private var app: NSRunningApplication

    open static func find(_ name: String) -> Application? {
        let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name })

        guard app != nil else {
            return nil
        }

        return Application(pid: app!.processIdentifier)
    }

    open static func launch(_ name: String) {
        NSWorkspace.shared.launchApplication(name)
    }

    open static func all() -> [Application] {
        return NSWorkspace.shared.runningApplications.map { Application(pid: $0.processIdentifier) }
    }

    open static func focused() -> Application? {
        if let app = NSWorkspace.shared.frontmostApplication {
            return Application(pid: app.processIdentifier)
        }

        return nil
    }

    init(pid: pid_t) {
        element = AXUIElementCreateApplication(pid)
        app = NSRunningApplication(processIdentifier: pid)!
    }

    init(app: NSRunningApplication) {
        element = AXUIElementCreateApplication(app.processIdentifier)
        self.app = app
    }

    open func windows() -> [Window] {
        var values: CFArray?
        let result = AXUIElementCopyAttributeValues(element, kAXWindowsAttribute as CFString, 0, 100, &values)

        if result != .success {
            return []
        }

        let elements = values! as [AnyObject]

        // swiftlint:disable:next force_cast
        return elements.map { Window(element: $0 as! AXUIElement) }
    }

    open func windows(_ options: [String: AnyObject]) -> [Window] {
        let visible = options[starkVisibilityOptionsKey] as? Bool ?? false

        if visible {
            return windows().filter { !$0.app.isHidden && $0.isStandard && !$0.isMinimized }
        }

        return windows()
    }

    open var name: String { return app.localizedName ?? "" }

    open var bundleId: String { return app.bundleIdentifier ?? "" }

    open var processId: pid_t { return app.processIdentifier }

    open func activate() -> Bool {
        return app.activate(options: .activateAllWindows)
    }

    open func focus() -> Bool {
        return app.activate(options: .activateIgnoringOtherApps)
    }

    open func show() -> Bool {
        return app.unhide()
    }

    open func hide() -> Bool {
        return app.hide()
    }

    open var isActive: Bool {
        return app.isActive
    }

    open var isHidden: Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXHiddenAttribute as CFString, &value)

        if result != .success {
            return false
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return false
    }

    open var isTerminated: Bool {
        return app.isTerminated
    }
}
