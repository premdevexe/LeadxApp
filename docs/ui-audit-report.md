# LeadX Employee App — UI / Architecture Audit Report

**Date:** 2026-11-17 · **Scope:** `D:\App Projects\Leadx\leadx` (Flutter) + `D:\Projects\Leadx\LeadX` (Laravel, read-only audit)

## 1. Toolchain & SDK compatibility

| Item | Value | Status |
|---|---|---|
| Flutter | 3.47.7 (stable, 2026-10-08) | ✅ |
| Dart SDK | 3.13.5 (`sdk: ^3.13.5`) | ✅ |
| `liquid_glass_widgets` latest | 1.17.4 (requires Flutter ≥ 3.41.0, Dart ≥ 3.5.0) | ✅ compatible — no SDK upgrade needed |
| Android SDK | **not installed** on this machine | ⚠️ APK builds impossible; `flutter analyze` + widget tests only |

## 2. Current app structure (43 Dart files, no router package, no theme package)

- **Navigation:** `AppGate` (splash → login → `HomeShell`). `HomeShell` = Material `Scaffold` + `NavigationBar` (5 tabs: Dashboard, Orders, Follow-ups, Customers, Alerts) + full `Drawer` covering all 13 panels. Detail screens pushed via raw `Navigator.push(MaterialPageRoute)` — no named routes.
- **Auth:** `AuthController` (provider) wraps `ApiClient` (Dio singleton) + Sanctum bearer token in `flutter_secure_storage`; 401 → `invalidate()`. FCM push + Reverb realtime in `AppServices`.
- **Data layer:** `LeadxApi` (one method per endpoint group), typed models under `lib/shared/models/`, all list screens share `PaginatedList` / `LoadingScreen` / `ErrorBanner` / `EmptyState` / `StatusChip` from `lib/shared/widgets/app_widgets.dart`.
- **Theme:** single `MaterialApp` with `ColorScheme.fromSeed(Color(0xFF14532D))` only. **No dark theme, no font loading, no typography scale** — every screen hand-codes `TextStyle` (dozens of `const TextStyle(fontSize: 12, color: Colors.grey)` sites).
- **No central currency service.** See §4.

## 3. Per-screen condition

| # | Screen | File | Notes |
|---|---|---|---|
| 1 | Login | `features/auth/login_screen.dart` | Functional; hardcoded brand green `0xFF14532D` and `Colors.grey` shades (breaks in dark mode); white logo badge container hardcoded. |
| 2 | Dashboard | `features/dashboard/dashboard_screen.dart` | Working; flat Material `Card` grid; currency symbol from dashboard meta only (`meta.currency_symbol`); no greeting, no profile summary, no notification shortcut, no recent-activity merge. |
| 3 | Orders | `features/orders/orders_screen.dart` | ⚠️ **currency bug:** uses `Fmt.money(order.closingValue, symbol: Fmt.defaultSymbol)` → hardcodes `₹`. |
| 4 | Customers | `features/customers/customers_screen.dart` + detail | Currency via `Fmt.money` default symbol → `₹` hardcoded (2 sites). |
| 5 | Payments | `features/payments/payments_screen.dart` + detail | ⚠️ **currency bug:** `p.currency` from backend is a **code** (`INR`/`USD`…, stored `string(3)` default `USD` — see `create_payments_table` migration + `PaymentService`), but the app feeds it straight into `Fmt.money(symbol: p.currency ?? '₹')` → would render `"INR2,500.50"` instead of the configured symbol. |
| 6 | Subscriptions | `features/subscriptions/*` | Price/amount via default-symbol `Fmt.money`; hardcoded red/amber colors in expiring screen (no dark-mode variants). |
| 7 | Follow-ups | `features/follow_ups/*` | Uses Material dialogs for reschedule/complete/cancel. No currency. |
| 8 | Notifications | `features/notifications/notifications_screen.dart` | Live Reverb + 45 s polling fallback. Good. |
| 9 | Calendar | `features/calendar/calendar_screen.dart` | Contains a **dead duplicated error block** (lines 168–187: two identical `if (_error != null && _status == null)` returns). |
| 10 | Profile | `features/profile/profile_screen.dart` | Working; raw `TextField`s, grey text. |
| 11 | Customer issues | `features/customer_issues/customer_issues_screen.dart` | Material bottom sheet create form; grey text; hardcoded chip colors. |
| 12 | Splash | `features/splash/splash_screen.dart` | Lottie + brand; hardcoded `0xFF0F172A` bg + emerald accents. |
| — | Order create sheet | `features/orders/order_create_sheet.dart` | Product price shown **raw** (`${p.name} · ${p.price}` — no symbol, no decimals); min closing price raw too. |
| — | Home shell / drawer | `features/dashboard/home_shell.dart` | Drawer hardcodes `Colors.amber.shade300`/`Colors.red`; logout confirm is a plain `AlertDialog`. |

## 4. Currency audit — the critical finding

**Backend (single source of truth):**
- `Setting::currency()` → key `currency`, **default `USD`** (`app/Models/Setting.php:218`).
- `Setting::currencySymbol()` / `currencySymbolFor(code)` via `Setting::CURRENCIES` = `{INR:₹, USD:$, EUR:€, GBP:£, AED:د.إ}`.
- Admin API: `GET /api/v1/admin/settings` exposes `currency`, `currency_symbol`, `currencies` (admin-gated — employees must not read this endpoint).
- Web panels format everywhere as `symbol + number_format(amount, 2)` (thousands separator `,`, decimal `.`, symbol **before**, 2 decimals) — e.g. `resources/views/employee/reports.blade.php:55`.
- `GET /employee/dashboard` already returns `meta.currency_symbol` but **no** code/formatting rules, and no other endpoint exposes currency to employees at all.
- **No existing employee-facing app-config endpoint exists** → must be added (backend work is additive: 1 new controller + 1 route; no admin/website/team-panel changes).

**Flutter (violations of "never hardcode currency"):**
- `Fmt.defaultSymbol = '₹'` (`lib/shared/format.dart:8`) — the app-wide default. Backend default is `USD`.
- `Fmt.money` hardcodes 2 decimals, `,` thousands, `.` decimal, symbol-before — correct *for now* (mirrors the web panel), but must come from config.
- `Payment.currency` treated as a **symbol** where it is a **code** (payments list + detail screens) — wrong on every currency.
- `Dashboard.currencySymbol` used only on the dashboard; every other screen falls back to `₹`.

**Resolution:** add `GET /api/v1/employee/app-config` (employee-guarded, no extra permission gate — formatting config is not sensitive data; it is already embedded in every dashboard payload). Return `{currency:{code,symbol,decimal_places,symbol_position,thousands_separator,decimal_separator},site_name,formatting:{...defaults...}}`. Flutter adds `AppConfigService` (provider) + `CurrencyFormatter` (the single, central formatter — `Fmt.money` becomes a thin alias so the 30+ existing call sites keep working) with `shared_preferences` cache for offline display.

## 5. Backend test coverage notes

- `tests/Feature/Api/EmployeePanelApiTest.php` covers the 13-page panel API (pattern: `ProvidesApiTokens` concern + `RefreshDatabase` + `PermissionSeeder`). The new `app-config` endpoint gets tests in the same file/fashion.

## 6. Performance / accessibility baseline

- No `BackdropFilter` today; `liquid_glass_widgets` uses fragment shaders (Impeller on Android) — use `GlassQuality.standard` defaults for cards/lists, `premium` only for persistent nav chrome; `adaptiveQuality: true` + `respectSystemAccessibility: true` on `wrap()`.
- No image caching concerns (only one logo asset). Lottie splash is the only heavy animation.
- Text scaling: Material `visualDensity` is set; typography must move to `MaterialApp.textScaler`-compatible `TextTheme` (avoid hard `fontSize` where hierarchy applies).
