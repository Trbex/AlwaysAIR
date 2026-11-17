// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 huamidev
//
// Honest, device-aware compatibility classification for the iPad Air M3 view.
//
// For a given physical device, this says whether a MobileGestalt capability can
// have a real effect — distinguishing a flag the hardware already satisfies, a
// flag whose effect is build-dependent, and a flag the hardware cannot honor at
// all (for example a true Always-On Display on an LCD panel).
//
// This file is intentionally free of SwiftUI. It returns a status plus plain
// strings; the view decides how to present them. Classification is derived from
// verifiable panel/silicon facts in `DeviceModel.DisplayProfile`, never from an
// assumption that writing a flag changes the hardware.
import Foundation

enum CompatibilityStatus: Equatable {
    /// The capability works on this hardware.
    case supported
    /// The hardware already provides this natively; the flag is usually unnecessary.
    case native
    /// The flag can be written, but the effect depends on the OS build, panel, or Apple services.
    case experimental
    /// The hardware cannot honor this; writing the flag will not produce the real feature.
    case unsupportedHardware
    /// The capability does not apply to this device class.
    case notApplicable

    /// Short badge label (localization key).
    var label: String {
        switch self {
        case .supported: "Supported"
        case .native: "Native"
        case .experimental: "Experimental"
        case .unsupportedHardware: "Not supported by hardware"
        case .notApplicable: "Not applicable"
        }
    }

    /// SF Symbol for the badge.
    var symbol: String {
        switch self {
        case .supported: "checkmark.seal"
        case .native: "checkmark.seal.fill"
        case .experimental: "exclamationmark.triangle"
        case .unsupportedHardware: "xmark.octagon"
        case .notApplicable: "minus.circle"
        }
    }

    /// Severity drives the badge color in the view (0 good … 3 blocked).
    enum Severity { case good, info, warn, blocked, neutral }
    var severity: Severity {
        switch self {
        case .supported: .good
        case .native: .info
        case .experimental: .warn
        case .unsupportedHardware: .blocked
        case .notApplicable: .neutral
        }
    }
}

struct CapabilityCompatibility {
    let status: CompatibilityStatus
    /// One-line, device-specific explanation (localization key or literal).
    let note: String
}

enum IPadAirCompatibility {
    /// Classify a capability (by its `Capability.id`) for a device.
    static func status(for capabilityID: String, on device: DeviceModel) -> CapabilityCompatibility {
        let panel = device.display

        switch capabilityID {

        // MARK: Display — Always-On family (rides on native AOD hardware)
        case "aod":
            return panel.supportsNativeAlwaysOn
                ? .init(status: .experimental,
                        note: "The panel may support a low-power Always-On mode. Effect depends on the OS build.")
                : .init(status: .unsupportedHardware,
                        note: "This device uses an LCD without a low-refresh panel, so a true system Always-On Display cannot render. The flag may add a Settings entry but will not produce a working AOD. See the in-app Always-On Clock for an app-level alternative.")
        case "aodVibrancy", "aodHighLuminance", "aodFlipbook", "aodFlipbookCount":
            return panel.supportsNativeAlwaysOn
                ? .init(status: .experimental, note: "Always-On rendering option. Effect depends on the OS build.")
                : .init(status: .unsupportedHardware,
                        note: "Depends on native Always-On Display hardware, which this LCD device does not have.")

        // MARK: Display — software/rendering flags (hardware-agnostic)
        case "liquidGlass":
            return .init(status: .supported,
                         note: "Low-power Liquid Glass rendering is a software capability and applies on iPadOS 26+.")
        case "parallax":
            return .init(status: .supported, note: "Disables motion-based wallpaper parallax. Software-only.")

        // MARK: Display — advertise-only flags that still need matching hardware
        case "hdrPhotoDisplay":
            return .init(status: .experimental,
                         note: "Advertises HDR photo rendering. This Liquid Retina LCD has a limited HDR range, so results differ from an HDR/OLED panel.")
        case "pwm":
            return .init(status: .unsupportedHardware,
                         note: "PWM dimming is an OLED-panel behavior. This device uses an LCD, so the flag has no backing hardware.")
        case "displayPort":
            return .init(status: .experimental,
                         note: "Advertises DisplayPort output. The USB-C port supports external display, but behavior depends on the adapter and OS.")

        // MARK: iPad features
        case "stageManager":
            return .init(status: .native,
                         note: "Stage Manager is natively supported on M-series iPad Air. The flag is normally unnecessary on this device.")
        case "pencil":
            return .init(status: .native,
                         note: "Apple Pencil Pro and Apple Pencil (USB-C) are natively supported on iPad Air (M3).")
        case "ipadApps":
            return .init(status: .notApplicable,
                         note: "This preset enables iPad app compatibility types on iPhone. It does not apply to an iPad.")

        // MARK: Apple Intelligence
        case "ai":
            return panel.appleIntelligenceNative
                ? .init(status: .native,
                        note: "iPad Air (M3) is built for Apple Intelligence; the hardware already advertises the generative-models capability. Region availability is the usual lever — see Region Code.")
                : .init(status: .experimental,
                        note: "Sets the generative-models capability. Availability still depends on region and Apple services.")
        case "siriAIMode":
            return .init(status: .experimental,
                         note: "Sets SiriMode to 2 without hardware spoofing. Resource downloads and availability are not guaranteed.")
        case "siriOnDevice":
            return .init(status: .experimental,
                         note: "Changes the device-specific on-device Siri capability. Keep the current value unless you intend to experiment; restore the original to recover.")
        case "audioIntelligence", "personalTranslator", "photosCleanUp",
             "handwritingSynthesis", "alwaysListeningSiri":
            return .init(status: .experimental,
                         note: "iOS 27 capability flag. Effect depends on the OS build, region, and Apple services.")

        default:
            return .init(status: .experimental,
                         note: "Effect depends on the device and OS build.")
        }
    }

    /// The native Always-On Display conclusion for this device, used by the view's
    /// dedicated AOD panel. Returns a headline status and explanation.
    static func nativeAlwaysOn(on device: DeviceModel) -> CapabilityCompatibility {
        if device.display.supportsNativeAlwaysOn {
            return .init(status: .experimental,
                         note: "This device's panel may support a low-power Always-On Display. Any capability flag remains experimental and build-dependent.")
        }
        return .init(status: .unsupportedHardware,
                     note: "iPad Air (M3) uses a fixed-60 Hz LED-backlit IPS LCD with no low-refresh (LTPO) hardware. A native system Always-On Display is not possible on this panel. Toggling AOD capability flags will not enable a functional system AOD.")
    }
}
