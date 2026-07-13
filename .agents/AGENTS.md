# 🌌 Expense Tracker Workspace Rules & Agent Guidelines

Welcome to the **Expense Tracker** project! This file serves as the workspace-level rules and guidelines for AI agents working on this codebase. These instructions are automatically discovered and loaded.

---

## 🏗️ Project Architecture & Tech Stack

This project is built using a clean, modern **MVVM (Model-View-ViewModel) + Service** architecture in Flutter, backed by **Supabase** and powered by the **Provider** package for state management.

### Key Directory Structure:
- `lib/app/`: Application bootstrap, routing, and configurations.
- `lib/models/`: Domain data models (immutable with `fromJson`, `toJson`, and `copyWith`).
- `lib/services/`: Core business services interfacing with remote APIs/DB.
- `lib/viewmodels/`: ViewModels implementing `ChangeNotifier` for state control.
- `lib/views/`: UI Layer (Screens & Page-specific layouts).
- `lib/widgets/`: Reusable UI components & Design tokens.
- `lib/utils/`: Helper utilities (formatting, exception classes, haptic utilities).

---

## 💾 Caching & Concurrency Strategy (`DatabaseService`)

- **TTL Configuration**: Caches remain valid for `30 seconds` (`_cacheTtl`).
- **Compound Cache Key**: The transaction cache builds a unique string key based on selected query filters (`type`, `categories` list, `startDate`, `endDate`). Changing any filter bypasses the stale cache and triggers a fresh remote load.
- **Invalidation**: All mutation operations (add, edit, delete, reorder) must explicitly invalidate the relevant cache to guarantee immediate data updates in the UI.
- **Request Deduplication**: A concurrency guard using `_ongoingTransactionFetch` (via the `Completer` pattern) prevents concurrent callers from spawning duplicate identical network requests for full transaction loads.

---

## ⚠️ Exception Handling & Reliability

To prevent leaking raw database and HTTP network errors directly to the UI, the app enforces a typed exception structure defined in `lib/utils/exceptions.dart`:
- `AppException` (Base exception)
- `UnauthenticatedException` (Thrown when user session is missing or invalid)
- `DataException` (PostgREST or general database issues)
- `AppAuthException` (Authentication credentials/session failure)
- `NetworkException` (Transient SocketExceptions/connectivity failures)

**Rules:**
1. **Service Error Mapping**: `DatabaseService` wraps operations inside a `_execute` helper, utilizing `_mapError` to map exceptions. `AuthService` maps errors using `_throwMappedError` (remapping invalid credential/email messages for sign-in vs invalid verification codes for OTP/recovery flows).
2. **Auth Retries**: The `AuthService` automatically retries operations up to `3` times (`_maxAttempts`) using exponential back-off delays when detecting network-level connectivity failures.

---

## 🛡️ Database Schema & PostgREST Operations

All data columns map strictly between remote database fields and Flutter immutable domain models. To ensure data privacy, the Service layer incorporates **defense-in-depth security** by including `user_id` checks on all operations modifying or deleting data.

### 1. `transactions` Table
- `id`: UUID (Primary Key)
- `user_id`: UUID (Foreign Key) - reference to Supabase Auth User ID. Always validate in queries!
- `amount`: Numeric (Decimal transaction value)
- `type`: Text (`'expense'` or `'income'`)
- `category`: Text (Associated category name)
- `description`: Text (Optional)
- `transaction_date`: Timestamptz (Customized date/time when transaction occurred)
- `created_at`: Timestamptz (Server-side record creation timestamp)

### 2. `categories` Table
- `id`: UUID (Primary Key)
- `user_id`: UUID (Foreign Key)
- `name`: Text (Display label of the category)
- `type`: Text (`'expense'` or `'income'`)
- `order_index`: Integer (Order ranking for reorderable list views)
- `created_at`: Timestamptz

---

## 🎨 UI & UX Principles

1. **Material 3 Design**: Utilize Material 3 widgets and design patterns.
2. **Dynamic Theming**: Support light/dark mode seamlessly via `ThemeViewModel` and custom dark colors (`#000000` base with `#0A0A0A` surface colors).
3. **Typography**: High-contrast text using the **Inter** Google Font family (packaged locally inside `google_fonts/` to prevent runtime fetching and styling delays).
4. **Scroll-to-Top Gesture**: Double-tapping the active navigation item or the AppBar title smoothly scrolls scrollable lists back to the top.
5. **Tactile Haptic Feedback**: Use `AppHaptics` in `lib/utils/haptics.dart` rather than calling standard `HapticFeedback` directly. Verify `ThemeViewModel.hapticEnabled` before executing haptic events.

---

## 🛠️ Code Conventions & Best Practices

1. **State Management & Optimistic Updates**:
   - Always expose business logic and UI states through `ChangeNotifier` in `viewmodels/`.
   - Use `Consumer<T>` or `context.watch<T>()` in the UI to react to changes. Use `context.read<T>()` inside callbacks to trigger actions without rebuilding.
   - Use **Optimistic UI Updates** to update lists immediately when a transaction is added, updated, or deleted, recalculating aggregates and sync in the background.
2. **Imports**: Use relative imports (e.g. `import '../../models/transaction.dart'`) for internal packages within the project.
3. **Lint Rules**: Follow all rules defined in `analysis_options.yaml`.

---

## 🚀 Releasing & Builds

To release a new version of the app on GitHub:
1. Build the release APK:
   ```bash
   flutter build apk
   ```
2. Recreate the release and upload the new APK using the provided script:
   ```bash
   bun scripts/recreate_release.js
   ```
   *Note: The script automatically handles deleting the old release, creating the new release, and uploading the newly generated APK. The git tag `v1.0.0` should be recreated/pushed to match the latest release commit before running.*

