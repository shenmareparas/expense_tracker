# <img src="screenshots/ic_launcher-playstore.png" width="48" height="48" align="center"> Expense Tracker

A modern, highly-polished, and feature-rich **Expense Tracker** application built with Flutter, backed by a **Supabase** backend, and state-managed with **Provider** following a strict **MVVM + Service** architecture.

---

## 🚀 Key Features

- **🔐 Secure Authentication**: Integrated with Supabase Auth (Sign In, Sign Up, Password Reset, in-app OTP recovery verification, and Auth Persistence) with built-in retry logic and exponential back-off for transient network issues.
- **📊 Interactive Analytics & Insights**: Drill-down charts powered by `fl_chart` to view expenses, incomes, and net balances (with support for positive/negative values, rounded bar indicators, custom tooltips, and haptic feedback) filterable by date ranges, automatically synchronized with split expenses and personal transactions.
- **🤝 Shared Split Expenses**:
  - **Overall Balance Hero Card**: Styled with the app's signature brand gradient (`#1E2038` → `#0F101C` in dark mode, primary indigo in light mode), top status pill, rolling amount counter animation (`TweenAnimationBuilder`), live visual split balance ratio bar (green vs red proportion segments), and frosted breakdown sub-cards for "You are owed" and "You owe".
  - **Friends List Feed**: User-wise grouped friends list with balance indicators (`owes you ₹X`, `you owe ₹Y`, `settled up`).
  - **Interactive Multi-Select Friend Picker**: Fast bottom sheet with search, checkmark indicators, real-time batch toggling, and sticky action bar to select multiple friends at once.
  - **Add & Manage Custom Friends**: Add friends not yet on the platform directly from the Split screen or `AddSplitPage` sheet. Custom friends are persisted locally, can be deleted anytime, and seamlessly participate in all split modes.
  - **Multi-Person Group Edit & Deletion**: Full editing and deletion support for split groups, automatically resolving sister splits, participant shares, percentages, and payer assignments.
  - **Friend Detail Screen (`UserSplitDetailPage`)**: Dedicated shared bill timeline with friend summary card, per-person share breakdowns, pull-to-refresh, and unified Settle Up confirmation modal. Supports deleting custom friends.
  - **Settle Up Payments**: Support Settle Up for both lenders and debtors, logging income settlement transactions when receiving money and expense settlement transactions when paying back.
  - **Hide / Unhide Friends**: Hide friends from the main list via the top-right `AppBar` action on the friend screen. Persisted via `SharedPreferences`, automatically excluded from the Add Split partner picker, and accessible via a low-profile expand/collapse toggle.
  - **Six Fully-Functional Split Modes**:
    - **Split Equally (`=`)**: Toggle member inclusion with live per-person recalculation.
    - **You Owe Partner Full**: Full bill amount assigned as debt to the partner.
    - **Partner Owes You Full**: Full bill amount assigned as receivable.
    - **Split by Exact Amounts (`1.23`)**: Individual numerical amount inputs with live balance remaining/over allocation pill indicator (`₹XX.XX left`).
    - **Split by Percentages (`%`)**: Individual percentage inputs with computed monetary values (`₹XX.XX`) and live percentage balance pill (`XX% left`).
    - **Split by Shares (`===`)**: Stepper buttons (`+` / `−`) with real-time ratio calculation.
  - **Two-Section Form**: `AddSplitPage` features card sections for "Transaction Details" and "Split Details" with strict validation before saving.
  - **Bidirectional Transaction & Analytics Sync**: Out-of-pocket split shares and settlements automatically log to personal transactions, updating home feeds and analytics charts in real time. Tapping a split transaction from the personal feed opens the full Split editor.
- **📁 Dynamic Categories Management**: Create, view, edit, and delete custom categories. Features a fluid drag-and-drop reordering interface, single-request batch creation, and database-level user ownership checks.
- **💸 Transaction Ledger & Math Inputs**: Log income and expenses with customizable dates, categories, payment methods (UPI or Cash), and descriptions. **Search** transactions by amount or description. **Filter** by multiple categories (multi-select), payment method, transaction type, or date range. **Inline Math Operations**: Enter mathematical calculations (`+`, `−`, `×`, `÷`) directly into amount fields with an interactive operations toolbar (`MathOperationsBar`), live computation preview badge, and automatic evaluation upon exiting the field or saving.
- **💾 Optimistic UI & Smart Caching**: Custom in-memory caching layer with TTL validation, compound filter keys, concurrent request deduplication via `Completer`, and optimistic state updates with rollback in ViewModels to minimize network overhead and ensure instant screen transitions.
- **📈 Analytics Snapshot**: A dedicated `loadAnalyticsSnapshot()` mechanism in `TransactionViewModel` fetches a separate date-filtered dataset for analytics without clobbering the main transaction feed or filters.
- **⚙️ Customizable Settings & Preferences**: Personalize the experience by configuring theme (system/light/dark), haptic feedback, default analytics tab, analytics tab order, and hidden friends — all saved persistently via `SharedPreferences`.
- **🎨 Rich Material 3 Aesthetics**: Tailored dynamic dark & light themes (`#000000` scaffold / `#0A0A0A` surface for dark mode), custom Inter typography (packaged locally to avoid network delays), rounded press highlights (`Clip.antiAlias`), conditional haptic feedback, `AnimatedSwitcher` tab transitions, and tap-to-scroll-to-top gestures.

---

## 📸 Screenshots

| Light Mode | Dark Mode |
|:---:|:---:|
| <img src="screenshots/1a.webp" width="300"> | <img src="screenshots/1b.webp" width="300"> |
| <img src="screenshots/2a.webp" width="300"> | <img src="screenshots/2b.webp" width="300"> |
| <img src="screenshots/3a.webp" width="300"> | <img src="screenshots/3b.webp" width="300"> |
| <img src="screenshots/4a.webp" width="300"> | <img src="screenshots/4b.webp" width="300"> |
| <img src="screenshots/5a.webp" width="300"> | <img src="screenshots/5b.webp" width="300"> |
| <img src="screenshots/6a.webp" width="300"> | <img src="screenshots/6b.webp" width="300"> |
| <img src="screenshots/7a.webp" width="300"> | <img src="screenshots/7b.webp" width="300"> |

---

## 🛠️ Technology Stack & Dependencies

- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.11.0`)
- **Backend & Database**: [Supabase](https://supabase.com) (`supabase_flutter: ^2.12.0`)
- **State Management**: [Provider](https://pub.dev/packages/provider) (`provider: ^6.1.5+1`)
- **Data Visualization**: [FL Chart](https://pub.dev/packages/fl_chart) (`fl_chart: ^1.1.1`)
- **Fonts & Styling**: [Google Fonts](https://pub.dev/packages/google_fonts) (`google_fonts: ^8.0.2` with Inter font loaded locally)
- **Formatting & Localization**: [Intl](https://pub.dev/packages/intl) (`intl: ^0.20.2`)
- **Persistence**: [Shared Preferences](https://pub.dev/packages/shared_preferences) (`shared_preferences: ^2.5.4`)

---

## 🏗️ Architecture (MVVM + Service)

The project adheres strictly to the **Model-View-ViewModel (MVVM)** pattern combined with a **Service Layer**:

```
lib/
├── app/
│   ├── app.dart              # MyApp: MultiProvider + MaterialApp light/dark theme
│   └── supabase_config.dart  # Compile-time credential injection + SupabaseClient accessor
├── models/                   # Pure Dart — no Flutter imports, no business logic
│   ├── category.dart         # CategoryModel (sortWithOtherLast static helper)
│   ├── profile.dart          # ProfileModel (displayName getter)
│   ├── split_expense.dart    # SplitExpenseModel (displayPayer/displayBorrower helpers)
│   └── transaction.dart      # TransactionModel (full CRUD fields + copyWith)
├── services/                 # ONLY layer that imports supabase_flutter
│   ├── auth_service.dart     # Singleton: Supabase Auth + retry/back-off + error mapping
│   └── database_service.dart # Singleton: PostgREST ops, 30s TTL cache, Completer dedup
├── viewmodels/               # ALL business logic lives here — ChangeNotifier state machines
│   ├── auth_viewmodel.dart   # Loading/error flags, recovery mode, session stream
│   ├── category_viewmodel.dart  # CRUD, drag reorder with rollback, seeding, name lists
│   ├── split_viewmodel.dart  # Feed, net balances, settle up, hidden friends; user identity via AuthService
│   ├── theme_viewmodel.dart  # Theme mode, haptics, analytics tab preferences
│   └── transaction_viewmodel.dart  # Feed, filters, search, analytics snapshot, optimistic ops
├── views/                    # UI ONLY — consume ViewModels via Provider/Consumer
│   ├── analytics/
│   │   └── analytics_page.dart   # FL Chart pie + bar, memoized aggregations
│   ├── auth/
│   │   ├── auth_gate.dart         # Routes to LoginPage/HomePage/UpdatePasswordPage
│   │   ├── forgot_password_page.dart
│   │   ├── login_page.dart
│   │   └── update_password_page.dart
│   ├── home/
│   │   ├── home_page.dart         # Bottom nav, AnimatedSwitcher tab transitions
│   │   └── widgets/
│   │       ├── filter_bottom_sheet.dart
│   │       └── transaction_list.dart  # Infinite scroll-load-more pagination
│   ├── settings/
│   │   ├── manage_categories_page.dart
│   │   └── settings_page.dart
│   ├── split/
│   │   ├── add_split_page.dart    # 6 split modes, Who Paid selector, live previews; user identity via SplitViewModel
│   │   ├── split_page.dart
│   │   └── user_split_detail_page.dart
│   └── transaction/
│       └── add_transaction_page.dart  # Add/edit transaction form with math input & operations bar
├── widgets/
│   ├── app_dropdown.dart          # AppDropdown<T> and AppDropdownButton<T>
│   └── math_operations_bar.dart   # Interactive math toolbar (+, −, ×, ÷, C) + live calculation preview pill
└── utils/
    ├── date_formatter.dart   # Relative date labels (Today/Yesterday)
    ├── exceptions.dart       # AppException hierarchy (Data/Auth/Network/Unauthenticated)
    ├── haptics.dart          # AppHaptics: conditional haptic helpers
    └── math_evaluator.dart   # Pure Dart arithmetic evaluator supporting operators, precedence & formatting
```

---

## 💾 Caching & Sync Strategy

The `DatabaseService` uses an **in-memory cache** combined with query safeguards to prevent unnecessary PostgREST calls and ensure fluid navigation:
- **Differentiated TTLs**: Each data type gets a TTL sized to how often it actually changes:
  - `transactions` & `split_expenses` — **2 minutes** (mutated frequently)
  - `profiles` — **10 minutes** (rarely changes)
  - `categories` — **15 minutes** (almost never changes)
- **Compound Cache Key**: The transaction cache uses a composite key generated from active filters (`type`, `categories` list, `paymentMethod`, `startDate`, `endDate`).
- **Cache Invalidation**: Any database mutation (insert, update, delete, reordering, settle up) invalidates the respective cache immediately to force a fresh sync.
- **Request Deduplication**: Concurrency guards (`Completer` pattern) prevent duplicate identical in-flight network requests for transactions, splits, and profiles.
- **Profiles Cache Reuse**: `getSplitExpenses()` and `updateSplitExpense()` call `getProfiles(forceRefresh: false)` to enrich split records with display names, eliminating a hidden second round-trip on every split load.
- **Batch API Calls**: `settleUpWithPartner()` uses `updateSplitExpenseStatusBatch()` (single `inFilter` update) instead of N sequential calls. `updateSplitExpenseGroup()` uses `deleteSplitExpenses()` (single `inFilter` delete) instead of N sequential calls.
- **Pull-to-Refresh Bypass**: Pulling down to refresh on home, split, or friend detail feeds passes `forceRefresh: true` to bypass the TTL cache and pull fresh data directly from Supabase.
- **Optimistic UI**: Transactions and split expense statuses are updated locally first, recalculating stats immediately and avoiding blocking spinners.
- **Sign-Out Purge**: `clearCache()` clears all caches on sign-out to prevent cross-account leakage.
- **Connectivity Pre-Check**: All write operations call `_executeMutation()` which runs a `ConnectivityChecker.isConnected()` guard before touching the network. If the device is offline, a `NetworkException` is thrown immediately instead of waiting for a ~30 s TCP timeout. The existing `SocketException → NetworkException` mapping in `_mapError` remains as an authoritative fallback for false positives.
- **SharedPreferences Caching**: `SplitViewModel` caches the `SharedPreferences` instance in a `_prefs` field (resolved once via `_getPrefs()`) rather than calling `getInstance()` on every custom-friend or hidden-friend operation.

---

## ⚠️ Robust Exception Handling

All services catch raw network and database exceptions, mapping them to safe typed `AppException` subclasses (`lib/utils/exceptions.dart`):
- `UnauthenticatedException`
- `DataException`
- `AppAuthException`
- `NetworkException`

ViewModels catch these exceptions and display user-friendly error bars without exposing raw DB stack traces.

---

## 📊 Database Schema

### 1. `transactions`
- `id` (UUID, Primary Key) - Auto-generated
- `user_id` (UUID, Foreign Key) - References Supabase Auth User
- `amount` (Numeric) - Decimal transaction value
- `type` (Text) - `'expense'` or `'income'`
- `category` (Text) - Associated category name
- `description` (Text, Optional) - Optional memo/note
- `payment_method` (Text) - `'upi'` or `'cash'` (default `'upi'`)
- `transaction_date` (Timestamptz) - Date when transaction occurred
- `created_at` (Timestamptz) - Server-side creation timestamp

### 2. `categories`
- `id` (UUID, Primary Key) - Auto-generated
- `user_id` (UUID, Foreign Key) - References Supabase Auth User
- `name` (Text) - Display label of the category
- `type` (Text) - `'expense'` or `'income'`
- `order_index` (Integer) - Order ranking for reorderable list views
- `created_at` (Timestamptz) - Server-side creation timestamp

### 3. `split_expenses`
- `id` (UUID, Primary Key) - Auto-generated
- `payer_id` (UUID) - References payer (Supabase Auth user ID or custom friend UUID)
- `borrower_id` (UUID) - References borrower (Supabase Auth user ID or custom friend UUID)
- `amount` (Numeric) - Per-person debt share
- `total_amount` (Numeric) - Total bill amount
- `description` (Text) - Description/memo for the split expense
- `category` (Text) - Associated category (default `'General'`)
- `status` (Text) - `'pending'` or `'settled'`
- `expense_date` (Timestamptz) - Date when the split expense occurred
- `created_at` (Timestamptz) - Server-side creation timestamp

### 4. `profiles`
- `id` (UUID, Primary Key) - Maps to Supabase Auth User ID
- `email` (Text) - User email address
- `name` (Text, Optional) - User display name
- `created_at` (Timestamptz) - Server-side creation timestamp

---

## 🏁 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version `>= 3.11.0`)
- Android Studio / VS Code with Flutter extensions
- A physical device or emulator

### Installation & Run

1. **Clone the repository**:
   ```bash
   git clone <repository_url>
   cd expense_tracker
   ```

2. **Get dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify the environment configuration**:
   The app resolves Supabase credentials at compile-time via `--dart-define` parameters. For convenience, it falls back to development defaults. You can specify yours when running or building:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=your-anon-key
   ```
   Or place them in a `.env.json` and run:
   ```bash
   flutter run --dart-define-from-file=.env.json
   ```

4. **Run the app**:
   ```bash
   flutter run
   ```
