import AppKit
import JavaScriptCore

@objc protocol StarkJSExport: JSExport {
    func log(message: String)
    func reload()
    @objc(bind:::) func bind(key: String, modifiers: [String], handler: JSValue) -> HotKey
}

public class Stark: NSObject, StarkJSExport {
    var config: Config

    init(config: Config) {
        self.config = config
    }

    public func log(message: String) {
        NSLog("%@", message)
    }

    public func reload() {
        config.load()
    }

    @objc(bind:::) public func bind(key: String, modifiers: [String], handler: JSValue) -> HotKey {
        return config.bindKey(key, modifiers: modifiers, handler: handler)
    }
}