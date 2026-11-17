// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 huamidev
//
// App-level Always-On Clock.
//
// This is NOT a native system Always-On Display. iPad Air (M3) has a fixed-60 Hz
// LCD with no low-refresh hardware, so iOS cannot render a true system AOD. This
// view is a software alternative: while GestaltX is foremost and this screen is
// open, it keeps the display awake (disables the idle timer) and shows a dimmed,
// slowly drifting clock to reduce static burn-in risk.
//
// It changes nothing on the device, writes no MobileGestalt keys, and stops the
// moment the view closes or the app is backgrounded.
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AlwaysOnClockView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// Dim the system brightness while the clock is shown, restoring it on exit.
    @AppStorage("GestaltX.aodClock.dim.v1") private var dimsDisplay = true
    @AppStorage("GestaltX.aodClock.seconds.v1") private var showsSeconds = false
    @AppStorage("GestaltX.aodClock.dimLevel.v1") private var dimLevel = 0.25

    @State private var previousBrightness: CGFloat?
    @State private var showsControls = true

    private var timeFormat: Date.FormatStyle {
        showsSeconds
            ? .dateTime.hour().minute().second()
            : .dateTime.hour().minute()
    }

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.periodic(from: .now, by: showsSeconds ? 1 : 10)) { context in
                let now = context.date
                ZStack {
                    Color.black.ignoresSafeArea()

                    clock(now: now)
                        // Drift the clock on a slow cycle to avoid a static image.
                        .offset(burnInOffset(for: now, in: proxy.size))
                        .animation(.easeInOut(duration: 2), value: burnInStep(for: now))

                    if showsControls { controlsOverlay }
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation { showsControls.toggle() }
        }
        .onAppear { startKeepAwake() }
        .onDisappear { stopKeepAwake() }
        .onChange(of: scenePhase) { _, phase in
            // The idle timer and brightness only make sense while active. iOS also
            // resets isIdleTimerDisabled on backgrounding; re-assert on return.
            switch phase {
            case .active: startKeepAwake()
            case .background, .inactive: stopKeepAwake()
            @unknown default: break
            }
        }
    }

    // MARK: - Clock

    private func clock(now: Date) -> some View {
        VStack(spacing: 10) {
            Text(now, format: timeFormat)
                .font(.system(size: 92, weight: .thin, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            Text(now, format: .dateTime.weekday(.wide).month().day())
                .font(.system(size: 22, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 24)
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button {
                    stopKeepAwake()
                    dismiss()
                } label: {
                    Label(L("Close"), systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .accessibilityLabel(L("Close"))
                Spacer()
            }
            .padding(20)

            Spacer()

            VStack(spacing: 14) {
                Toggle(L("Show Seconds"), isOn: $showsSeconds)
                Toggle(L("Dim Display"), isOn: $dimsDisplay)
                    .onChange(of: dimsDisplay) { _, dim in applyBrightness(dim: dim) }
                if dimsDisplay {
                    HStack {
                        Image(systemName: "sun.min").foregroundStyle(.secondary)
                        Slider(value: $dimLevel, in: 0.05...0.6)
                            .onChange(of: dimLevel) { _, _ in applyBrightness(dim: true) }
                        Image(systemName: "sun.max").foregroundStyle(.secondary)
                    }
                }
                Text(L("Not a native Always-On Display. Keeps the screen awake only while this view is open and GestaltX is in the foreground."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .tint(.white)
            .foregroundStyle(.white.opacity(0.75))
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: 420)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .transition(.opacity)
    }

    // MARK: - Burn-in mitigation

    /// A step index that advances every ~60 seconds, used to drive the drift.
    private func burnInStep(for date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate / 60)
    }

    /// A small, slowly changing offset so the clock never sits at one pixel set.
    /// All math is done in Double and handed to the Double CGSize initializer to
    /// avoid Double/CGFloat mixing.
    private func burnInOffset(for date: Date, in size: CGSize) -> CGSize {
        let step = Double(burnInStep(for: date) % 4)
        let angle = step / 4 * 2 * Double.pi
        let radiusX = Double(min(size.width, 420)) * 0.08
        let radiusY = Double(size.height) * 0.06
        return CGSize(width: cos(angle) * radiusX, height: sin(angle) * radiusY)
    }

    // MARK: - Keep-awake / brightness

    private func startKeepAwake() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
        applyBrightness(dim: dimsDisplay)
    }

    private func stopKeepAwake() {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = false
        if let previousBrightness {
            UIScreen.main.brightness = previousBrightness
        }
        previousBrightness = nil
        #endif
    }

    private func applyBrightness(dim: Bool) {
        #if canImport(UIKit)
        if dim {
            if previousBrightness == nil { previousBrightness = UIScreen.main.brightness }
            UIScreen.main.brightness = CGFloat(dimLevel)
        } else if let previousBrightness {
            UIScreen.main.brightness = previousBrightness
            self.previousBrightness = nil
        }
        #endif
    }
}
