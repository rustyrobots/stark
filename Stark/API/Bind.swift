import Carbon
import JavaScriptCore

@objc
protocol BindJSExport: JSExport {
    init(key: String, modifiers: [String], callback: JSValue)

    var key: String { get }
    var modifiers: [String] { get }
    var isEnabled: Bool { get }

    func enable() -> Bool
    func disable() -> Bool
}

private var bindIdentifierSequence: UInt = 0

private let starkHotKeyIdentifier = "starkHotKeyIdentifier"
private let starkHotKeyKeyDownNotification = "starkHotKeyKeyDownNotification"

public class Bind: Handler, BindJSExport, HashableJSExport {
    /// Static Variables

    // swiftlint:disable:next variable_name
    private static var __once: () = {
        let callback: EventHandlerUPP = { (_, event, _) -> OSStatus in
            autoreleasepool {
                var identifier = EventHotKeyID()

                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )

                if status != noErr {
                    return
                }

                NotificationCenter.default.post(name: Notification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil, userInfo: [starkHotKeyIdentifier: UInt(identifier.id)])
            }

            return noErr
        }

        var keyDown = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &keyDown, nil, nil)
    }()

    /// Static Functions

    public static func hashForKey(_ key: String, modifiers: [String]) -> Int {
        return String(format: "%@[%@]", key, modifiers.joined(separator: "|")).hashValue
    }

    /// Instance Variables

    private var identifier: UInt

    private var keyCode: UInt32

    private var modifierFlags: UInt32

    private var eventHotKeyRef: EventHotKeyRef?

    private var enabled = false

    public override var hashValue: Int { return Bind.hashForKey(key, modifiers: modifiers) }

    public var key: String = ""

    public var modifiers: [String] = []

    public var isEnabled: Bool { return enabled }

    /// Instance Functions

    public required init(key: String, modifiers: [String], callback: JSValue) {
        _ = Bind.__once

        self.key = key
        self.modifiers = modifiers

        self.keyCode = UInt32(KeyCodeHelper.keyCode(for: key))
        self.modifierFlags = UInt32(KeyCodeHelper.modifierFlags(for: modifiers))

        bindIdentifierSequence += 1
        self.identifier = bindIdentifierSequence

        super.init()

        manageCallback(callback)

        NotificationCenter.default.addObserver(self, selector: #selector(Bind.keyDown(notification:)), name: NSNotification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil)

        _ = enable()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: starkHotKeyKeyDownNotification), object: nil)

        _ = disable()
    }

    public func enable() -> Bool {
        if enabled {
            return true
        }

        let eventHotKeyID = EventHotKeyID(signature: UTGetOSTypeFromString("STRK" as CFString), id: UInt32(identifier))

        let status = RegisterEventHotKey(keyCode, modifierFlags, eventHotKeyID, GetEventDispatcherTarget(), 0, &eventHotKeyRef)

        if status != noErr {
            return false
        }

        enabled = true

        return true
    }

    public func disable() -> Bool {
        if !enabled {
            return true
        }

        let status = UnregisterEventHotKey(eventHotKeyRef)

        if status != noErr {
            return false
        }

        eventHotKeyRef = nil
        enabled = false

        return true
    }

    @objc
    func keyDown(notification: Notification) {
        if let userDict = notification.userInfo {
            if identifier == userDict[starkHotKeyIdentifier] as? UInt {
                call()
            }
        }
    }
}
