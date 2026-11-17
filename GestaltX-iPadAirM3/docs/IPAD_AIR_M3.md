# GestaltX — iPad Air M3 Edition

Device-targeted additions for the **iPad Air 11-inch (M3, 2025)** running
**iPadOS 27.x**, built on top of the existing GestaltX capability engine.

This document describes what was added, what works on this hardware, what is
experimental, and what the hardware cannot do regardless of any flag. It does
not claim any capability the device does not physically support, and it does not
claim a build or on-device test that was not actually run (see
[Testing](#testing-report)).

---

## 1. Target device — verified facts

| Property | iPad Air 11-inch (M3) |
| --- | --- |
| Model identifiers | `iPad15,3` (Wi-Fi), `iPad15,4` (Cellular) |
| 13-inch siblings | `iPad15,5` (Wi-Fi), `iPad15,6` (Cellular) |
| SoC | Apple M3, 16-core Neural Engine |
| Display | Liquid Retina — **LED-backlit IPS LCD**, 2360×1640, **60 Hz fixed** |
| OLED / ProMotion / LTPO | **No** |
| Apple Intelligence | **Native** ("Built for Apple Intelligence") |
| Architecture | ARM64 |

These facts drive every compatibility label in the app. They are cross-checked
against Apple's published 2025 iPad Air tech specs and The Apple Wiki.

The most important consequence: **the M3 Air has no low-refresh (LTPO) OLED
panel, so a native system Always-On Display is not physically possible on this
device.** Toggling AOD capability flags does not change that.

---

## 2. What was added

All new code lives in the auto-synchronized `GestaltX/` group, so it compiles
into the existing app target with no project-file surgery.

### New files
| File | Purpose |
| --- | --- |
| `GestaltX/DeviceModel.swift` | Classifies the physical device from `hw.machine` (read-only). Maps `iPad15,3`–`iPad15,6` to a family and a verified display/silicon profile. Unknown identifiers degrade to conservative defaults — never guessed. |
| `GestaltX/IPadAirCompatibility.swift` | Turns device facts into an honest per-capability status: Supported / Native / Experimental / Not supported by hardware / Not applicable, each with a one-line reason. |
| `GestaltX/IPadAirM3View.swift` | The **iPad Air M3 — Advanced Settings** screen. Curates Display, iPad Features, and Apple Intelligence options with compatibility badges. Reuses the existing staging / apply / backup / per-key restore paths — it adds no new write mechanism. |
| `GestaltX/AlwaysOnClockView.swift` | An **app-level** Always-On Clock (keep-awake + dimmed, drifting clock). Explicitly **not** a system AOD; changes nothing on the device. |

### Changed files
| File | Change |
| --- | --- |
| `GestaltX/ContentView.swift` | Adaptive root navigation: a native **`NavigationSplitView` sidebar on iPad** (regular width) and the original `TabView` on iPhone (compact). Added the iPad Air M3 entry to Tools and as a sidebar item. All existing sheet/alert/share-import plumbing is unchanged. |
| `.github/scripts/build-ipa.sh` | Added hard validation after signing: arm64 slice present, `UIDeviceFamily` includes iPad (2), and the package is a device (not Simulator) build. |
| `.github/workflows/ipad-air-m3-build.yml` | New portable workflow on GitHub-hosted `macos-15` (the existing `build.yml` needs a private `xcode-27` runner). |

---

## 3. Implemented features (iPad Air M3 — Advanced Settings)

### Display
| Option | Status on M3 Air | Notes |
| --- | --- | --- |
| Always-On Display (capability) | **Not supported by hardware** | LCD, no LTPO. Flag may add a Settings entry; no functional system AOD. |
| AOD Vibrancy / High-Luminance / Flipbook / Flipbook Count | **Not supported by hardware** | All depend on native AOD hardware the panel lacks. |
| HDR Photo Display | **Experimental** | LCD has a limited HDR range vs an HDR/OLED panel. |
| Liquid Glass low-power rendering | **Supported** | Software capability, iPadOS 26+. |
| Disable Wallpaper Parallax | **Supported** | Software-only. |
| PWM | **Not supported by hardware** | PWM dimming is an OLED behavior. |
| DisplayPort output | **Experimental** | USB-C supports external display; behavior depends on adapter/OS. |

### iPad Features
| Option | Status | Notes |
| --- | --- | --- |
| Stage Manager | **Native** | Already supported on M-series iPad Air; flag normally unnecessary. |
| Apple Pencil | **Native** | Apple Pencil Pro / USB-C natively supported. |
| iPad App Compatibility | **Not applicable** | That preset targets iPhone; shown for transparency. |
| External display | **Experimental** | Advertised via the DisplayPort flag (Display section). |

### Apple Intelligence
| Option | Status | Notes |
| --- | --- | --- |
| Region Code (+ **Restore Original Region**) | **Supported** | The real lever where AI availability is region-restricted. Restore reverts region keys via the standard backup+verified-write path. |
| Apple Intelligence Capability | **Native** | M3 already advertises the generative-models capability. |
| Siri AI Mode | **Experimental** | Sets `SiriMode` to 2 without hardware spoofing. No download guarantee. |
| On-Device Siri | **Experimental** | Device-specific capability; restore original to recover. |
| Audio Intelligence / Personal Translator / Photos Clean Up / Handwriting Synthesis / Always-Listening Hey Siri | **Experimental** | iOS 27 flags; depend on OS build, region, Apple services. |

### Always-On Clock (app-level)
- Keeps the display awake only **while the view is open and GestaltX is in the
  foreground** (`isIdleTimerDisabled`).
- Dimmed, slowly drifting clock to reduce static burn-in; optional brightness
  floor; restores brightness and the idle timer on exit/background.
- Writes no MobileGestalt keys and makes no device changes.

---

## 4. Always-On Display — the honest conclusion

The iPad Air M3 uses a **fixed-60 Hz LED-backlit IPS LCD**. A native iOS
Always-On Display requires an OLED panel capable of a very low (≈1 Hz) refresh
rate (LTPO), which this device does not have. Therefore:

- **Native system AOD cannot be enabled** on this hardware by any MobileGestalt
  flag. The app shows this as **"Not supported by hardware."**
- The capability flag may still toggle a Settings entry, but the panel cannot
  render a true low-power AOD, so it will not function as one.
- The **Always-On Clock** is offered as a clearly-labeled app-level alternative.
  It is a screensaver-style keep-awake, not a system feature.

---

## 5. Safety & recovery (unchanged guarantees, reused)

The iPad Air M3 view uses the same safety flow as the rest of GestaltX:

- An automatic backup before each device write; the write is read back and
  verified.
- Before/after review of every staged change (Review Changes).
- Per-option **Revert** restores recorded original values and types.
- **Restore Original Region** reverts region keys through the verified path.
- **No hardware spoofing**: CPU, board, and product identity are never changed
  by this view. Device detection is read-only (`hw.machine`).
- Face ID / Touch ID, Apple services, and unrelated settings are untouched.

---

## 6. Build & install

### Build the IPA (GitHub Actions, hosted runner)
1. Push this branch to your fork.
2. Actions → **Build IPA (iPad Air M3, hosted runner)** → **Run workflow**.
3. Download the `GestaltX-iPadAirM3-<version>` artifact (an ad-hoc, unsigned-for-
   distribution IPA with the App Group entitlements embedded for re-signing).

The build **fails** rather than producing an invalid artifact if the app is not
an arm64, iPad-capable device build.

### Install with SideStore
1. Install SideStore and complete its pairing/anisette setup on the iPad.
2. AirDrop or copy the `.ipa` to the iPad (Files).
3. SideStore → **+** → select the IPA → let it re-sign with your account.
4. SideStore re-signs using the embedded App Group entitlement; keep the share
   extension when prompted.
5. Trust the developer profile if iPadOS asks, then launch GestaltX.
6. In GestaltX: **Tools → Read MobileGestalt** (requires iPadOS 27.x), then open
   **iPad Air M3 — Advanced Settings** (Tools, or the iPad sidebar).

AltStore and Sideloadly follow the same re-signing model.

> Signing needs a certificate/profile with at least one usable **App Group**.
> The IPA carries the app's and the share extension's entitlements so the
> re-signing tool can register a common group.

---

## 7. Testing report

**Build environment used for this change:** Linux (no macOS/Xcode). Therefore:

- ❌ **Not done here:** `xcodebuild` compilation, Simulator run, device install,
  on-device MobileGestalt read/write, Face ID/region round-trips. None of these
  were performed, and none are claimed as passing.
- ✅ **Done here (static):**
  - New Swift files written against the project's existing APIs and idioms
    (`GestaltManager` staging/restore, `Capability`, `L()`, `RegionPreset`,
    `GestaltKeys`).
  - Verified the Xcode project uses a file-system-synchronized group, so new
    `GestaltX/*.swift` files are included in the target automatically.
  - `bash -n` syntax check on the modified `build-ipa.sh`.
  - YAML validation of both workflows.
  - Device facts (identifiers, panel, AI support) verified against public specs.

**How to get real pass/fail:** run the hosted-runner workflow (section 6). A
green run is the actual compile gate and produces the validated IPA. On-device
behavior must then be confirmed on a physical iPad Air M3; capability effects
depend on the exact iPadOS 27.x build.

---

## 8. Known limitations

- Native AOD and PWM are hardware-blocked on this LCD and are labeled as such.
- Experimental Apple Intelligence flags do not guarantee model downloads or
  feature availability; region and Apple services still govern that.
- Compatibility labels are tuned for the M3 Air; on other devices the view shows
  a scope notice and the options still function.
- This edition does not add hardware spoofing or any security bypass, by design.
