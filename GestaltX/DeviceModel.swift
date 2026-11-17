// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 huamidev
//
// Physical device classification for GestaltX.
//
// This reads the kernel-reported hardware identifier (`hw.machine`, e.g.
// "iPad15,3") through the existing GXCopyPhysicalHardwareIdentity() bridge and
// classifies the device the app is actually running on. It is used only to
// present accurate, device-specific compatibility information in the UI.
//
// It never writes, spoofs, or alters hardware identity. An identifier that is
// not in the known table is reported as `.unknown` rather than guessed, so the
// UI degrades to conservative, honest defaults instead of inventing facts.
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A classified physical device.
struct DeviceModel: Equatable {
    /// Device families GestaltX treats specially. Everything else is `.otherIPad`,
    /// `.otherIPhone`, or `.unknown`.
    enum Family: String, Equatable {
        case iPadAirM3_11
        case iPadAirM3_13
        case iPadAirM2
        case otherIPad
        case otherIPhone
        case unknown
    }

    /// Raw `hw.machine` value, e.g. "iPad15,3". Empty only if detection failed.
    let identifier: String
    let family: Family
    /// Human-readable marketing name for display. Never used for any write.
    let marketingName: String
    /// Static facts about the panel and silicon, used to classify capabilities.
    let display: DisplayProfile

    var isIPadAirM3: Bool { family == .iPadAirM3_11 || family == .iPadAirM3_13 }

    var isIPad: Bool {
        switch family {
        case .iPadAirM3_11, .iPadAirM3_13, .iPadAirM2, .otherIPad: return true
        case .otherIPhone, .unknown: return false
        }
    }

    // MARK: - Panel / silicon facts

    /// Verifiable hardware facts that decide whether a capability flag can have a
    /// real effect. Defaults are deliberately conservative for unknown devices.
    struct DisplayProfile: Equatable {
        /// Panel technology, as published by Apple (e.g. "Liquid Retina (LED-backlit IPS LCD)").
        let panel: String
        /// Whether the panel is OLED. LCD panels cannot do a true low-power AOD.
        let isOLED: Bool
        /// Whether the panel has a variable/low refresh rate (ProMotion/LTPO) needed
        /// for a native 1 Hz Always-On Display. LCD + fixed 60 Hz means `false`.
        let hasLowRefreshRate: Bool
        /// Whether the hardware natively supports a system Always-On Display.
        var supportsNativeAlwaysOn: Bool { isOLED && hasLowRefreshRate }
        /// Whether the chip/device is natively marketed as supporting Apple Intelligence.
        let appleIntelligenceNative: Bool
        /// Whether the device has a Dynamic Island. iPads do not.
        let hasDynamicIsland: Bool

        static let unknown = DisplayProfile(
            panel: "Unknown",
            isOLED: false,
            hasLowRefreshRate: false,
            appleIntelligenceNative: false,
            hasDynamicIsland: false
        )
    }

    // MARK: - Detection

    /// The device this process is running on.
    static let current: DeviceModel = classify(identifier: machineIdentifier())

    /// Resolve the physical hardware identifier. Prefers the sysctl-backed bridge
    /// used elsewhere in the app; falls back to `uname` and, in the Simulator, to
    /// the SIMULATOR_MODEL_IDENTIFIER environment variable.
    static func machineIdentifier() -> String {
        #if targetEnvironment(simulator)
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !simulated.isEmpty {
            return simulated
        }
        #endif
        let physical = GXCopyPhysicalHardwareIdentity()
        if let machine = physical["hw.machine"], !machine.isEmpty {
            return machine
        }
        var info = utsname()
        uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        let identifier = mirror.children.reduce(into: "") { partialResult, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            partialResult.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }

    /// Map a raw identifier to a classified device. Unknown identifiers are
    /// classified by prefix only (iPad vs iPhone) and never assigned panel facts
    /// they were not verified to have.
    static func classify(identifier raw: String) -> DeviceModel {
        let identifier = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let known = knownModels[identifier] {
            return DeviceModel(identifier: identifier, family: known.family,
                               marketingName: known.name, display: known.display)
        }
        // Unknown identifier: classify coarsely, assume nothing about the panel.
        if identifier.hasPrefix("iPad") {
            return DeviceModel(identifier: identifier, family: .otherIPad,
                               marketingName: unknownIPadName(for: identifier),
                               display: .unknown)
        }
        if identifier.hasPrefix("iPhone") {
            return DeviceModel(identifier: identifier, family: .otherIPhone,
                               marketingName: "iPhone", display: .unknown)
        }
        return DeviceModel(identifier: identifier.isEmpty ? "Unknown" : identifier,
                           family: .unknown,
                           marketingName: identifier.isEmpty ? "This device" : identifier,
                           display: .unknown)
    }

    private static func unknownIPadName(for identifier: String) -> String {
        #if canImport(UIKit)
        return UIDevice.current.model // "iPad"
        #else
        return "iPad"
        #endif
    }

    // MARK: - Known device table
    //
    // iPad Air (M3) identifiers and panel facts are cross-checked against Apple's
    // published 2025 iPad Air tech specs and The Apple Wiki. The M3 Air uses a
    // fixed-60 Hz LED-backlit IPS "Liquid Retina" LCD (no OLED, no ProMotion), so
    // it has no native Always-On Display hardware, and the M3 is marketed as
    // "Built for Apple Intelligence".

    private struct KnownModel {
        let family: Family
        let name: String
        let display: DisplayProfile
    }

    private static let iPadAirM3Display = DisplayProfile(
        panel: "Liquid Retina (LED-backlit IPS LCD), 60 Hz",
        isOLED: false,
        hasLowRefreshRate: false,
        appleIntelligenceNative: true,
        hasDynamicIsland: false
    )

    private static let iPadAirM2Display = DisplayProfile(
        panel: "Liquid Retina (LED-backlit IPS LCD), 60 Hz",
        isOLED: false,
        hasLowRefreshRate: false,
        appleIntelligenceNative: true,
        hasDynamicIsland: false
    )

    private static let knownModels: [String: KnownModel] = [
        // iPad Air 11-inch (M3, 2025)
        "iPad15,3": KnownModel(family: .iPadAirM3_11, name: "iPad Air 11-inch (M3)", display: iPadAirM3Display),
        "iPad15,4": KnownModel(family: .iPadAirM3_11, name: "iPad Air 11-inch (M3)", display: iPadAirM3Display),
        // iPad Air 13-inch (M3, 2025)
        "iPad15,5": KnownModel(family: .iPadAirM3_13, name: "iPad Air 13-inch (M3)", display: iPadAirM3Display),
        "iPad15,6": KnownModel(family: .iPadAirM3_13, name: "iPad Air 13-inch (M3)", display: iPadAirM3Display),
        // iPad Air (M2, 2024) — recognized so the view can note the M3-specific scope.
        "iPad14,8": KnownModel(family: .iPadAirM2, name: "iPad Air 11-inch (M2)", display: iPadAirM2Display),
        "iPad14,9": KnownModel(family: .iPadAirM2, name: "iPad Air 11-inch (M2)", display: iPadAirM2Display),
        "iPad14,10": KnownModel(family: .iPadAirM2, name: "iPad Air 13-inch (M2)", display: iPadAirM2Display),
        "iPad14,11": KnownModel(family: .iPadAirM2, name: "iPad Air 13-inch (M2)", display: iPadAirM2Display)
    ]
}
