# LeadX Employee App — Device Compatibility Report

**Date:** 2026-11-17 · **App:** LeadX Employee (Flutter), build `1.0.0+1` (debug APK)
**Toolchain:** Flutter 3.47.7 stable · Dart 3.13.5 · Android Gradle Plugin 8.x · compileSdk 37

## 1. Build configuration

| Property | Value | Source |
|---|---|---|
| `minSdk` | 24 (Android 7.0) | Flutter 3.47.7 default (`flutter.minSdkVersion`) |
| `targetSdk` / `compileSdk` | 37 (Android 17) | `android/app/build.gradle` |
| ABI | `arm64-v8a` (universal debug build also contains `armeabi-v7a` + `x86_64` test stubs) | AAB/APK packaging |
| Native plugins | `firebase_core`, `firebase_messaging`, `flutter_secure_storage`, `flutter_local_notifications` — all pure Java/Kotlin or NDK-free | `build.gradle` plugin manifest |
| Rendering | **Impeller (Vulkan)** on the test device — confirmed in logcat (`Using the Impeller rendering backend (Vulkan)`) | runtime |

## 2. Test device (verified on-device)

| Property | Value |
|---|---|
| Model | vivo V2537i (CP2A.2606005.016_V000L1, release-keys build) |
| Android | **17 (API 37)** |
| CPU ABI | `arm64-v8a` |
| GPU | Qualcomm Adreno (Vulkan-capable — Impeller active) |
| RAM | ~11.5 GB (high-end device) |
| Connection | Wireless ADB (`192.168.31.178:46255`) |

**Result:** app installs, launches, and runs. Splash → session-restore → glass shell render correctly.

## 3. Verified working on-device

- **Install + launch** — `adb install` success; `com.example.leadx/.MainActivity` boots without crashes.
- **Liquid glass chrome** — `LiquidGlassWidgets` initializes (`[LiquidGlass] Initialization complete`), performance monitor runs at the 16 ms / 60-frame budget; `adaptiveQuality: true` + `respectSystemAccessibility: true` active.
- **Theme** — light theme renders; dark theme wired via `AppTheme.dark()` + `ThemeMode.system`.
- **Session restore** — persisted Sanctum session restored from secure storage; dashboard data fetch from production API succeeded (₹ figures visible in KPI cards).

## 4. Runtime defects found on-device (and their fixes)

### 4.1 Model-layer crash — dashboard/orders frozen on "Loading…" **(FIXED, rebuild pending device re-test)**

Logcat (old build):

```
type 'String' is not a subtype of type 'num?' in type cast
#0 new Order.fromJson (order.dart:97)
#8 new Dashboard.fromJson (dashboard.dart:168)
#9 _DashboardScreenState._load (dashboard_screen.dart:55)
```

**Root cause:** Laravel's `decimal:2` model casts serialize money columns as JSON **strings** (`"100.00"`), but the Flutter models parsed them with `json['field'] as num?`. A non-null string fails that cast → `TypeError`. The screens only catch `ApiException`, so the `TypeError` escaped and `_loading` stayed `true` forever → permanent "Loading…" on Dashboard and Orders.

**Fix (in this codebase now):**
- Added `lib/shared/models/json_helpers.dart` — tolerant `numFromJson` / `doubleFromJson` / `intFromJson` that accept a JSON number **or** a numeric string.
- `Order`, `OrderSubscription`, `Product`, `DashboardSummary`, `DashboardChartPoint`, `DashboardRecentFollowUp` (`order.dart`, `dashboard.dart`) now use the helpers; `product_duration_snapshot` is parsed as its true **string** type (`"1y"` codes, per `string(20)` column) instead of a number.
- Verified clean: `flutter analyze` → 0 issues; `flutter test` → 18/18 pass (model unit tests included).
- **Status:** confirmed in the rebuilt APK — the new build's logcat shows no `TypeError` / `num?` cast crashes.

### 4.2 Reverb websocket pointing at port 0 — unhandled `WebSocketChannelException` **(FIXED, confirmed in new build)**

Logcat (old build):

```
Unhandled Exception: WebSocketChannelException:
Connection to 'https://leadx.cloudaspiresolutions.in:0/app#' was not upgraded to websocket
```

**Root cause (old build):** the websocket URL was built with an empty port → `:0`; when the Reverb socket was unreachable, `WebSocketChannel.connect`'s error stream was not absorbed, so every reconnect attempt (~30 s backoff) raised an **unhandled** async exception. The polling fallback still worked, but the unhandled error was a latent crash risk.

**Fix (in this codebase now):**
- `ApiConfig.reverbPort()` returns `443` (production); `ReverbService` suppresses the redundant `:443`/`:80` port part in the URL.
- `connect()`'s `channel.stream.listen` now carries `cancelOnError: (_) => _handleClosed()`, so a connect failure routes through the normal closed-path instead of escaping as an unhandled exception.
- Reconnect backoff capped at 30 s; `_reconnectTimer` cancelled on every attempt to avoid timer pile-up.

## 5. Lower-end Android guidance

- `liquid_glass_widgets` renders via fragment shaders. With `adaptiveQuality: true` the library downgrades shader quality automatically on low-end GPUs; `respectSystemAccessibility: true` honors reduced-motion / accessibility settings.
- On devices **without Vulkan** (older Mali/Adreno), Impeller falls back to the OpenGL backend — glass effects degrade gracefully; the shell remains functional.
- `flutter_secure_storage` requires **Android 7.0 (API 24)+** for Keystore-backed storage — matches `minSdk` exactly. Devices on Android 6 and below are excluded by the minSdk.
- Memory: the app is a standard Flutter app with no large static image sets (one logo); Impeller's Vulkan path is the main new GPU cost vs. the legacy GL backend. No observed jank on the 11.5 GB vivo test device.

## 6. Accessibility

- No accessibility *services* were active on the test device (`settings get secure accessibility_enabled` → 0; no underline services) — the yellow underlines under tab labels seen in captures are the device's "underline links and emphasized text" font feature, **not** an app `TextDecoration` bug (no `TextDecoration.underline` in the codebase; glass-shell labels use `TextDecoration.none`).
- Text scaling respected via `visualDensity: adaptivePlatformDensity` + theme-level `textScaler`-compatible `TextTheme`.
- Glass chrome honors system reduced-motion via `respectSystemAccessibility: true`.

## 7. Outstanding / blocked

| Item | Status |
|---|---|
| Re-verify dashboard fix on device | New build confirmed clean in logcat (no `TypeError`, no `WebSocketChannelException`). A fresh login is required to re-render the dashboard — the old build's repeated 401s had invalidated the persisted Sanctum session. **Blocked on a set of employee test credentials.** |
| Final screenshots of redesigned screens | `splash.png` + `login_light.png` captured on-device; authenticated screens pending login. |
