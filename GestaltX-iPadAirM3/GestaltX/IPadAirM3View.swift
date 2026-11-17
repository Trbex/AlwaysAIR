// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 huamidev
//
// "iPad Air M3 — Advanced Settings": a device-aware, curated front end over the
// existing capability engine. It reuses GestaltManager's staging, apply, backup,
// and per-key restore paths — it introduces no new write mechanism — and labels
// every option with an honest, hardware-derived compatibility status.
//
// Nothing here spoofs hardware identity. Always-On Display is presented with its
// real conclusion for this LCD panel (not supported in hardware), alongside the
// app-level Always-On Clock alternative.
import SwiftUI

struct IPadAirM3View: View {
    @EnvironmentObject private var model: GestaltManager
    private let device = DeviceModel.current
    @State private var asksRegionRestore = false

    /// Reverts the region keys to their recorded originals through the standard
    /// restore path (backup + verified write), used by "Restore Original Region".
    private static let regionRestore = Capability(
        id: "regionRestore", category: .intelligence, title: "Region", detail: "",
        keys: [GestaltKeys.regionCode, GestaltKeys.regionInfo, GestaltKeys.legacyRegionInfo]
    )

    private let displayIDs = ["aod", "aodVibrancy", "aodHighLuminance", "aodFlipbook",
                              "aodFlipbookCount", "hdrPhotoDisplay", "liquidGlass",
                              "parallax", "pwm", "displayPort"]
    private let ipadIDs = ["stageManager", "pencil", "ipadApps"]
    private let intelligenceIDs = ["ai", "siriAIMode", "siriOnDevice", "audioIntelligence",
                                   "personalTranslator", "photosCleanUp",
                                   "handwritingSynthesis", "alwaysListeningSiri"]

    var body: some View {
        Form {
            deviceHeader
            if !device.isIPadAirM3 { scopeNotice }

            alwaysOnDisplaySection

            if model.hasDocument {
                capabilitySection(L("Display"), symbol: "display", ids: displayIDs)
                iPadFeaturesSection
                intelligenceSection
                if model.changeCount > 0 {
                    Section { NavigationLink(L("Review Changes")) { ChangeReviewView(isSheet: false) } }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        L("No Document Open"),
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(L("Read MobileGestalt in Tools to edit capability flags. The Always-On Clock works without reading the device."))
                    )
                }
            }
        }
        .navigationTitle(L("iPad Air M3"))
        .disabled(model.isBusy)
        .alert(L("Restore Original Region"), isPresented: $asksRegionRestore) {
            Button(L("Cancel"), role: .cancel) {}
            Button(L("Restore"), role: .destructive) {
                Task {
                    await model.restoreCapability(Self.regionRestore)
                    model.regionCodeID = "keep"
                    model.regionID = "keep"
                }
            }
        } message: {
            Text(L("Restore the recorded original region code and info. A backup is created before writing. Restart the device afterward."))
        }
    }

    // MARK: - Device header

    private var deviceHeader: some View {
        Section {
            LabeledContent(L("Model"), value: device.marketingName)
            LabeledContent(L("Identifier"), value: device.identifier)
            LabeledContent(L("Display"), value: device.display.panel)
            LabeledContent(L("Apple Intelligence"),
                           value: L(device.display.appleIntelligenceNative ? "Native" : "Unknown"))
            LabeledContent("iPadOS", value: "\(UIDevice.current.systemVersion) (\(VersionSupport.label))")
        } header: {
            Text(L("Detected Device"))
        } footer: {
            Text(L("Detection reads the kernel hardware identifier only. GestaltX never changes CPU, board, or physical hardware identity."))
        }
    }

    private var scopeNotice: some View {
        Section {
            Label(L("These settings are tuned for iPad Air (M3). Options still apply on this device, but the compatibility notes are written for the M3 Air panel and chip."),
                  systemImage: "info.circle")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - Always-On Display (honest conclusion + app-level alternative)

    private var alwaysOnDisplaySection: some View {
        let verdict = IPadAirCompatibility.nativeAlwaysOn(on: device)
        return Section {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Native Always-On Display"))
                Spacer(minLength: 8)
                CompatBadge(status: verdict.status)
            }
            Text(L(verdict.note)).font(.caption).foregroundStyle(.secondary)
            NavigationLink {
                AlwaysOnClockView()
            } label: {
                Label(L("Open Always-On Clock (app-level)"), systemImage: "clock")
            }
        } header: {
            Text(L("Always-On"))
        } footer: {
            Text(L("The Always-On Clock keeps the screen awake with a dimmed, drifting clock while GestaltX is open. It is a software feature, not a system Always-On Display, and makes no changes to the device."))
        }
    }

    // MARK: - Generic capability section

    private func capabilitySection(_ title: String, symbol: String, ids: [String]) -> some View {
        Section {
            ForEach(capabilities(ids)) { capability in
                CapabilityPresetRow(capability: capability, device: device)
            }
        } header: {
            Label(L(title), systemImage: symbol)
        }
    }

    private var iPadFeaturesSection: some View {
        Section {
            ForEach(capabilities(ipadIDs)) { capability in
                CapabilityPresetRow(capability: capability, device: device)
            }
        } header: {
            Label(L("iPad Features"), systemImage: "ipad.landscape")
        } footer: {
            Text(L("Stage Manager and Apple Pencil are natively supported on iPad Air (M3); these flags are usually unnecessary. External-display behavior is advertised through the DisplayPort flag in the Display section."))
        }
    }

    // MARK: - Apple Intelligence

    private var intelligenceSection: some View {
        Section {
            Picker(L("Region Code"), selection: $model.regionCodeID) {
                ForEach(RegionPreset.all) { Text(L($0.title)).tag($0.id) }
            }
            if model.regionCodeID != "keep" {
                Text(L("A device restart may be required.")).font(.caption).foregroundStyle(.secondary)
            }
            Button(L("Restore Original Region")) { asksRegionRestore = true }
                .disabled(!model.canRestore(Self.regionRestore) && model.regionCodeID == "keep")

            ForEach(capabilities(intelligenceIDs)) { capability in
                CapabilityPresetRow(capability: capability, device: device)
            }
        } header: {
            Label(L("Apple Intelligence"), systemImage: "sparkles")
        } footer: {
            Text(L("iPad Air (M3) is built for Apple Intelligence. Changing the region code is usually the only lever needed where availability is restricted; capability flags are experimental and do not guarantee model downloads."))
        }
    }

    // MARK: - Helpers

    private func capabilities(_ ids: [String]) -> [Capability] {
        ids.compactMap { id in Capability.all.first { $0.id == id } }
    }
}

// MARK: - Capability row with compatibility badge

/// A single capability preset row, mirroring the picker/revert behavior used in
/// CategoryView, plus a device-specific compatibility badge and note.
struct CapabilityPresetRow: View {
    let capability: Capability
    let device: DeviceModel
    @EnvironmentObject private var model: GestaltManager

    private var compat: CapabilityCompatibility {
        IPadAirCompatibility.status(for: capability.id, on: device)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L(capability.title))
                Spacer(minLength: 8)
                CompatBadge(status: compat.status)
            }
            Picker(selection: Binding(
                get: { model.choices[capability.id] ?? .keep },
                set: { model.choices[capability.id] = $0 }
            )) {
                ForEach(capability.availableChoices) { choice in
                    let title = capability.id == "siriOnDevice" && choice == .disable
                        ? "Restore Original" : choice.title
                    Text(L(title)).tag(choice)
                }
            } label: {
                Text(L("Action"))
            }
            .pickerStyle(.menu)

            Text(L(compat.note)).font(.caption).foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                if (model.choices[capability.id] ?? .keep) != .keep {
                    Text(L(capability.effectHint)).font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 8)
                Button(L("Revert")) { Task { await model.restoreCapability(capability) } }
                    .font(.caption).buttonStyle(.borderless)
                    .disabled(!model.canRestore(capability))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Badge

struct CompatBadge: View {
    let status: CompatibilityStatus

    var body: some View {
        Label(L(status.label), systemImage: status.symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }

    private var tint: Color {
        switch status.severity {
        case .good: .green
        case .info: .blue
        case .warn: .orange
        case .blocked: .red
        case .neutral: .gray
        }
    }
}
