//
//  Space.swift
//  Stark
//
//  Created by Tom Bell on 23/02/2018.
//  Copyright © 2018 Rusty Robots. All rights reserved.
//

import AppKit
import JavaScriptCore

private let starkVisibilityOptionsKey = "visible"

private let CGSScreenIDKey = "Display Identifier"
private let CGSSpaceIDKey = "ManagedSpaceID"
private let CGSSpacesKey = "Spaces"

@objc
protocol SpaceJSExport: JSExport {
    static func active() -> Space
    static func all() -> [Space]

    static func currentSpace(for screen: NSScreen) -> Space
    static func spaces(for window: Window) -> [Space]
}

public class Space: NSObject, SpaceJSExport {
    /// Static Functions

    public static func active() -> Space {
        return Space(identifier: CGSGetActiveSpace(CGSMainConnectionID()))
    }

    public static func all() -> [Space] {
        var spaces = [Space]()

        let displaySpacesInfo = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()).takeRetainedValue() as NSArray

        displaySpacesInfo.forEach {
            guard let spacesInfo = $0 as? [String: AnyObject] else {
                return
            }

            guard let identifiers = spacesInfo[CGSSpacesKey] as? [[String: AnyObject]] else {
                return
            }

            identifiers.forEach {
                guard let identifier = $0[CGSSpaceIDKey] as? CGSSpaceID else {
                    return
                }

                spaces.append(Space(identifier: identifier))
            }
        }

        return spaces
    }

    public static func currentSpace(for screen: NSScreen) -> Space {
        let identifier = CGSManagedDisplayGetCurrentSpace(CGSMainConnectionID(), screen.identifier as CFString)
        return Space(identifier: identifier)
    }

    public static func spaces(for window: Window) -> [Space] {
        let identifiers = CGSCopySpacesForWindows(CGSMainConnectionID(),
                                                  kCGSAllSpacesMask,
                                                  [window.identifier] as CFArray).takeRetainedValue() as NSArray

        return all().filter { identifiers.contains($0.identifier) }
    }

    /// Initializers

    init(identifier: CGSSpaceID) {
        self.identifier = identifier
    }

    override public func isEqual(_ object: Any?) -> Bool {
        if let space = object as? Space {
            return identifier == space.identifier
        }

        return false
    }

    /// Instance Variables

    private var identifier: CGSSpaceID

    /// Instance Functions

    public var isNormal: Bool {
        return CGSSpaceGetType(CGSMainConnectionID(), identifier) == kCGSSpaceUser
    }

    public var isFullscreen: Bool {
        return CGSSpaceGetType(CGSMainConnectionID(), identifier) == kCGSSpaceFullScreen
    }

    public func screens() -> [NSScreen] {
        if !NSScreen.screensHaveSeparateSpaces {
            return NSScreen.screens
        }

        let displaySpacesInfo = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()).takeRetainedValue() as NSArray

        var screen: NSScreen?

        displaySpacesInfo.forEach {
            guard let spacesInfo = $0 as? [String: AnyObject] else {
                return
            }

            guard let screenIdentifier = spacesInfo[CGSScreenIDKey] as? String else {
                return
            }

            guard let identifiers = spacesInfo[CGSSpacesKey] as? [[String: AnyObject]] else {
                return
            }

            identifiers.forEach {
                guard let identifier = $0[CGSSpaceIDKey] as? CGSSpaceID else {
                    return
                }

                if identifier == self.identifier {
                    screen = NSScreen.screen(for: screenIdentifier)
                }
            }
        }

        if let screen = screen {
            return [screen]

        }

        return []
    }
    public func windows() -> [Window] {
        return Window.all().filter { $0.spaces().contains(self) }
    }

    public func windows(_ options: [String: AnyObject]) -> [Window] {
        let visible = options[starkVisibilityOptionsKey] as? Bool ?? false

        if visible {
            return windows().filter { !$0.app.isHidden && $0.isStandard && !$0.isMinimized }
        }

        return windows()
    }
}