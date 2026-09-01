# 🌌 Expense Tracker Workspace Rules & Agent Guidelines

Welcome to the **Expense Tracker** project! This file serves as the workspace-level rules and guidelines for AI agents working on this codebase. These instructions are automatically discovered and loaded.

---

## 🏗️ Project Architecture & Tech Stack

This project is built using a clean, modern **MVVM (Model-View-ViewModel) + Service** architecture in Flutter, backed by **Supabase** and powered by the **Provider** package for state management.

### Key Directory Structure:
- `lib/app/`: Application bootstrap (`MyApp`, `MultiProvider`), routing, and `SupabaseConfig` initialization.
- `lib/models/`: Immutable domain data models with `fromJson`, `toJson`, `copyWith`, `==`, and `hashCode`.
- `lib/services/`: Singleton data/auth services (`AuthService`, `DatabaseService`) that are the **only** layer allowed to import `supabase_flutter` or make network calls.
- `lib/viewmodels/`: ViewModels implementing `ChangeNotifier`. **All business logic lives here.** Consume services; expose state + actions to the UI.
- `lib/views/`: UI Layer (Screens & Page-specific layouts). May only access ViewModels via `Provider`/`Consumer`. **Must never import `supabase_flutter`, `DatabaseService`, or `AuthService` directly.**
- `lib/widgets/`: Reusable, pure-UI components (e.g. `AppDropdown`, `MathOperationsBar`).
- `lib/utils/`: Pure helpers — formatting (`DateFormatter`), math parsing (`MathEvaluator`), typed exceptions (`AppException` hierarchy), haptics (`AppHaptics`).

---

## ⚙️ MVVM Compliance Rules (CRITICAL — enforce on every change)

1. **Views → ViewModels only**: Views read state via `Consumer<T>` or `context.watch<T>()` and trigger actions via `context.read<T>()`. Views must **never** call `DatabaseService`, `AuthService`, or any Supabase SDK directly.
2. **ViewModels → Services only**: ViewModels call `DatabaseService.instance` and `AuthService.instance`. They must not import `supabase_flutter` directly. Auth identity reads (current user id, name, email) must go through `AuthService.instance.currentUser`.
3. **Services → SDK only**: Services encapsulate all PostgREST queries, Auth calls, error mapping, and caching. They return typed domain models or throw typed `AppException` subclasses.
4. **Models are pure Dart**: No Flutter imports, no service calls, no state. Display-only computed getters (e.g., `displayName`) that derive from model fields are acceptable.

> ✅ **Fully enforced as of 2026-08-23**: `split_viewmodel.dart` previously held a direct `SupabaseClient` reference; it now routes all current-user identity reads through `AuthService.instance`. `add_split_page.dart` previously called `Supabase.instance.client.auth.currentUser` directly in two bottom sheet methods; it now uses `SplitViewModel.currentUserDisplayName` instead. No View or ViewModel imports `supabase_flutter` anymore. `database_service.dart` previously fired a raw `SELECT *` on the profiles table inside `getSplitExpenses()` and `updateSplitExpense()` on every call; it now reuses the profiles cache via `getProfiles(forceRefresh: false)`. `transaction_viewmodel.dart` previously called `clearCache()` (nuking all caches) inside `updateTransaction()`; it now relies on the service's internal `_invalidateTransactionCache()` only.

---

## 🤝 Shared Expenses & Integration Architecture

- **Friends Feed**: Main Split screen (`SplitPage`) displays:
  - **Overall Balance Hero Card**: Styled with the app's signature brand gradient (`Color(0xFF1E2038)` to `Color(0xFF0F101C)` in dark mode / primary indigo in light mode, `28px` corner radius), top header with frosted status pill, 500ms rolling number animation (`TweenAnimationBuilder<double>` with `FontFeature.tabularFigures()`), dynamic live visual split balance ratio bar (green vs red proportion segments), and frosted breakdown sub-cards for "You are owed" and "You owe".
  - User-wise grouped Friends list with balance indicators ("owes you ₹X", "you owe ₹Y", "settled up").
- **Custom Friends Support**: Users can add unregistered friends via "Add new person" modal on `SplitPage` and `AddSplitPage`.
  - Custom friends are assigned client-generated UUIDs and persisted locally in `SharedPreferences` (`custom_friends`).
  - Merged seamlessly into `SplitViewModel.profiles` alongside remote Supabase profiles.
  - Can be deleted directly from `UserSplitDetailPage` via the top-right delete action.
  - Foreign key constraints on `split_expenses.borrower_id` and `payer_id` to `auth.users(id)` were dropped on Supabase to allow custom friend UUIDs.
- **Edit Split Expense & Multi-Person Group Resolution**: `AddSplitPage` supports editing existing splits (`widget.splitExpense != null`), automatically resolving all sister splits (`SplitViewModel.getSisterSplits`) for the bill to load all sharing participants, their custom amounts/percentages/shares, and who paid. Saving edits updates the entire split group via `SplitViewModel.updateSplitExpenseGroup` and syncs with the personal transaction.
- **Friend Detail Screen (`UserSplitDetailPage`)**: Dedicated view for shared expenses timeline with a friend, net friend balance summary, custom friend deletion, pull-to-refresh (`forceRefresh: true`), and a unified **Settle Up** confirmation modal.
- **Settle Up Logic**: Both lenders (payers) and debtors (borrowers) can settle up. Settling up resolves all pending split shares between friends:
  - Lender receives money: logs `income` settlement transaction ("Settlement from Friend").
  - Debtor pays back: logs `expense` settlement transaction ("Settlement to Friend").
- **Hide / Unhide Friends**: Hide friends via the top-right `AppBar` action on the friend detail screen.
  - Persisted locally via `SharedPreferences` (`hidden_friend_ids`).
  - Hidden friends are excluded from the `AddSplitPage` partner dropdown list.
  - Accessible on the main Split screen via a discreet, low-profile `"Show hidden friends (N)"` expand/collapse toggle.
- **Multi-Select Friend Picker Sheet**: `AddSplitPage` features an interactive multi-select bottom sheet with search, checkmark indicators, real-time batch toggling, and a sticky "Done (N selected)" action bar, allowing users to select or deselect multiple friends in a single interaction without the sheet closing on each tap.
- **Keyboard-Responsive Modal Bottom Sheet Architecture**: All modal bottom sheets (`_showChooseSplitOptionsSheet`, `_showAddPartnerSheet`, `_showChoosePayerSheet`) follow a strict responsive layout pattern:
  - Root container specifies `constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88)`.
  - Wrapped with `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom))` to automatically shift above the software keyboard.
  - Top headers and bottom action buttons are pinned outside the scrollable body in a `Column(mainAxisSize: MainAxisSize.min)`.
  - All middle scrollable content (including lists and empty search states) is enclosed in `Flexible(child: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, child: Column(...)))` to guarantee zero `RenderFlex` overflow errors regardless of keyboard height or display size.
  - Text fields in Exact Amounts and Percentages rows include `scrollPadding: const EdgeInsets.only(bottom: 80)` and `textInputAction: TextInputAction.next` for visible input clearance.
- **Two-Section Split Form**: `AddSplitPage` divides inputs into **Transaction Details** (Amount, Description, Category, Date & Time) and **Split Details** (Split With, Who Paid, Split Mode). Saving is disabled until all required fields are valid.
- **Six Split Modes**:
  - `equally` (`=`): Member checkboxes with equal fraction calculation.
  - `youOweFull`: Partner paid full bill; user owes entire amount.
  - `partnerOwesFull`: User paid full bill; partner owes entire amount.
  - `exactAmounts` (`1.23`): Persistent numeric text fields per member with real-time remaining/over allocation pill (`₹XX left`).
  - `percentages` (`%`): Persistent percentage text fields per member with computed monetary preview and remaining percentage pill (`XX% left`).
  - `shares` (`===`): Tactile `+` and `−` integer steppers with dynamic ratio fraction calculation.
- **Transactions & Analytics Integration**: Creating a split expense automatically records the user's out-of-pocket share into `transactions` table, instantly updating personal ledger, Home screen feeds, and Analytics category charts.
- **Bidirectional Split & Personal Transaction Sync**:
  - Editing or deleting a split expense from `AddSplitPage` or `UserSplitDetailPage` automatically updates or deletes the corresponding personal transaction.
  - Editing or deleting a split transaction from `AddTransactionPage` or `TransactionListView` automatically updates or deletes the corresponding split expense in `SplitViewModel`.
  - Tapping a split transaction from the personal transactions list automatically navigates to `AddSplitPage` in edit mode for seamless management.
  - Both `AddSplitPage` and `AddTransactionPage` provide a top-bar Delete action with confirmation when editing existing records.
- **Unified Screen AppBar Styling**: Clean solid AppBar backgrounds (matching `ThemeData.appBarTheme` and scaffold background) across `AddTransactionPage`, `AddSplitPage`, and `UserSplitDetailPage` without `extendBodyBehindAppBar` gradients.

---

## 💾 Caching & Concurrency Strategy (`DatabaseService`)

- **Differentiated TTL Configuration**: Each cache type uses a TTL sized to how often it changes:
  - `_transactionCacheTtl = Duration(minutes: 2)` — transactions mutate frequently
  - `_splitCacheTtl = Duration(minutes: 2)` — splits change with settle-ups
  - `_profilesCacheTtl = Duration(minutes: 10)` — profiles rarely change
  - `_categoryCacheTtl = Duration(minutes: 15)` — categories almost never change
- **Compound Cache Key**: The transaction cache builds a unique string key based on selected query filters (`type`, `categories` list, `paymentMethod`, `startDate`, `endDate`). Changing any filter bypasses the stale cache and triggers a fresh remote load.
- **Invalidation**: All mutation operations (add, edit, delete, reorder, settle up) explicitly call `_invalidateTransactionCache()`, `_invalidateCategoryCache()`, or `_invalidateSplitCache()` to guarantee immediate data updates in the UI.
- **Profiles Cache Reuse**: `getSplitExpenses()` and `updateSplitExpense()` call `getProfiles(forceRefresh: false)` to enrich split records, eliminating the hidden second `SELECT *` round-trip that previously fired on every split load.
- **Batch API Calls**: Two new methods reduce N sequential round-trips to a single `inFilter` call:
  - `updateSplitExpenseStatusBatch(ids, status)` — used by `settleUpWithPartner()` to settle all pending splits in one shot.
  - `deleteSplitExpenses(ids)` — used by `updateSplitExpenseGroup()` to delete old split records in one shot.
- **Request Deduplication**: Concurrency guards using `_ongoingTransactionFetch`, `_ongoingSplitFetch`, and `_ongoingProfilesFetch` (via the `Completer` pattern) prevent concurrent callers from spawning duplicate identical network requests.
- **Pull-to-Refresh Force Bypass**: Pulling down to refresh on the home feed, split feed (`SplitPage`), or friend detail page (`UserSplitDetailPage`) passes `forceRefresh: true` to bypass TTL caches and pull fresh data from Supabase.
- **Connectivity Pre-Check on Writes**: All write operations in `DatabaseService` call `_executeMutation()` instead of `_execute()`. `_executeMutation` first calls `ConnectivityChecker.isConnected()` (via `connectivity_plus`) and throws `NetworkException` immediately if no interface is active. Read operations use `_execute()` directly since the in-memory cache usually satisfies them without hitting the network.
- **`clearCache()`**: Called on sign-out via `AuthViewModel.signOut()` to clear transactions, categories, split expenses, and profile caches, preventing cross-user data leakage.
- **SharedPreferences Caching in `SplitViewModel`**: A `_prefs` field is resolved once via `_getPrefs()` (lazy `??=`) and reused across all `SharedPreferences` operations (custom friends, hidden friends), mirroring the pattern already used in `ThemeViewModel`.

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
3. **ViewModel Error Display**: ViewModels expose `String? errorMessage`. Views display this via `ScaffoldMessenger` snackbars or inline error widgets. Never display raw exception objects.

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
- `payment_method`: Text (`'upi'` or `'cash'`, default `'upi'`)
- `transaction_date`: Timestamptz (Customized date/time when transaction occurred)
- `created_at`: Timestamptz (Server-side record creation timestamp)

### 2. `categories` Table
- `id`: UUID (Primary Key)
- `user_id`: UUID (Foreign Key)
- `name`: Text (Display label of the category)
- `type`: Text (`'expense'` or `'income'`)
- `order_index`: Integer (Order ranking for reorderable list views)
- `created_at`: Timestamptz

### 3. `split_expenses` Table
- `id`: UUID (Primary Key)
- `payer_id`: UUID (Foreign Key to `profiles.id`)
- `borrower_id`: UUID (Foreign Key to `profiles.id`)
- `amount`: Numeric (Per-person share amount)
- `total_amount`: Numeric (Total bill amount)
- `description`: Text
- `category`: Text (Default `'General'`)
- `status`: Text (`'pending'` or `'settled'`)
- `expense_date`: Timestamptz
- `created_at`: Timestamptz

### 4. `profiles` Table
- `id`: UUID (Primary Key - maps to Supabase Auth User ID)
- `email`: Text
- `name`: Text (Optional display name)
- `created_at`: Timestamptz

---

## 🎨 UI & UX Principles

1. **Material 3 Design**: Utilize Material 3 widgets and design patterns.
2. **Dynamic Theming**: Support light/dark mode seamlessly via `ThemeViewModel`. Dark mode uses `#000000` scaffold background and `#0A0A0A` surface/card colors. Light mode uses `Color(0xFF4F46E5)` as the seed color; dark mode uses `Color(0xFF818CF8)`.
3. **Typography**: High-contrast text using the **Inter** Google Font family (packaged locally inside `google_fonts/` to prevent runtime fetching and styling delays). `GoogleFonts.config.allowRuntimeFetching = false` is set in `main.dart`.
4. **Scroll-to-Top Gesture**: Tapping the active navigation item or the `AppBar` title smoothly scrolls scrollable lists back to the top (`ScrollController.animateTo(0)`).
5. **Tactile Haptic Feedback**: Use `AppHaptics` in `lib/utils/haptics.dart` rather than calling standard `HapticFeedback` directly. Verify `ThemeViewModel.hapticEnabled` before executing haptic events.
6. **Card Clipping & Rounded Highlights**: Always set `clipBehavior: Clip.antiAlias` on `Card` and matching `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(...))` on `ListTile` so press/hold highlights conform perfectly to card rounded corners.
7. **AnimatedSwitcher Navigation**: `HomePage` uses `AnimatedSwitcher` with a fade + vertical slide transition between tabs.

---

## 🛠️ Code Conventions & Best Practices

1. **State Management & Optimistic Updates**:
   - Always expose business logic and UI states through `ChangeNotifier` in `viewmodels/`.
   - Use `Consumer<T>` or `context.watch<T>()` in the UI to react to changes. Use `context.read<T>()` inside callbacks to trigger actions without rebuilding.
   - Use **Optimistic UI Updates** to update lists immediately when a transaction or split is added, updated, or deleted, recalculating aggregates and syncing in the background.
   - On failure, always **roll back** the optimistic change and set `_errorMessage`.
2. **Imports**: Use relative imports (e.g. `import '../../models/transaction.dart'`) for internal packages within the project.
3. **Lint Rules**: Follow all rules defined in `analysis_options.yaml`.
4. **Singleton Services**: Access `DatabaseService` and `AuthService` via `.instance` — never construct them directly.
5. **Analytics Memoization**: `AnalyticsPage` maintains its own memoized derived state (totals, daily data) to prevent full re-aggregation on chart touch interactions. This is intentional.
6. **`SplitViewModel` cross-VM calls**: `toggleSettled` and `settleUpWithPartner` accept `TransactionViewModel?` to record settlement transactions. Always pass the live `TransactionViewModel` from the build context when calling these.
7. **`SplitViewModel` current user getters**: Use `SplitViewModel.currentUserId`, `SplitViewModel.currentUserDisplayName`, and `SplitViewModel.currentUserEmail` to get the signed-in user's identity in split-related Views. Do not call `AuthService` or `Supabase` SDK from the View layer.
8. **Amount Input & Math Operations**: Always route mathematical evaluations through `MathEvaluator.evaluate` and format calculated results with `MathEvaluator.format`. Attach `MathOperationsBar` to amount fields and maintain `_amountFocusNode` listeners to auto-calculate expressions upon field unfocus and before submission.
9. **Batch DB Operations**: When settling up or editing a split group, always use `DatabaseService.updateSplitExpenseStatusBatch()` and `DatabaseService.deleteSplitExpenses()` respectively. Never loop over individual `updateSplitExpenseStatus()` or `deleteSplitExpense()` calls for bulk operations.
10. **SharedPreferences**: Always cache the `SharedPreferences` instance in a private field (e.g. `_prefs`) resolved lazily via `??=`. Never call `SharedPreferences.getInstance()` on every method invocation — see `ThemeViewModel` and `SplitViewModel` as reference implementations.
11. **Write operations**: Always use `_executeMutation()` in `DatabaseService` for any method that modifies data (INSERT, UPDATE, DELETE). Reserve `_execute()` for read-only operations. This ensures offline users get an immediate `NetworkException` instead of a TCP timeout.

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
