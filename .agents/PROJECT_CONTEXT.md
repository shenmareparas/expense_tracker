# 📁 Expense Tracker Project Context

This document provides a high-level overview of the **Expense Tracker** Flutter codebase, its state, integration, and setup instructions.

---

## 🌟 Project Overview

The Expense Tracker is a Flutter mobile application designed for personal finance tracking. It supports:

- **Authentication**: Email/Password signup, login, password resetting (request link / 6-digit OTP code verification), and secure updates powered by Supabase Auth. Auth state persistence is handled via stream subscription in `AuthViewModel`.
- **Transactions**: Full CRUD tracking of expenses and income, supporting payment methods (UPI or Cash), customizable date/time, category details, search (by amount or description), multi-filter support (type, categories, payment method, date range), and inline math evaluation in the amount field (with interactive operator toolbar and live preview).
- **Split Expenses**:
  - User-wise grouped Friends list with overall balance banner ("Overall, you are owed...", "You are all settled up!").
  - Dedicated Friend Detail Page (`UserSplitDetailPage`) showing shared expense timeline, net friend balance, and unified Settle Up confirmation modal.
  - Settle Up functionality for both lenders and debtors, automatically recording settlement transactions in personal ledger.
  - Hide / Unhide friend option with `SharedPreferences` persistence and low-profile expand/collapse toggle at the bottom of the split list.
  - Excludes hidden friends from the `AddSplitPage` partner selection.
  - Six split modes: `equally`, `youOweFull`, `partnerOwesFull`, `exactAmounts`, `percentages`, `shares`.
  - Two-section `AddSplitPage` form layout ("Transaction Details" and "Split Details") with strict form validation and inline math evaluation in the amount field.
  - Automatic integration with personal Transactions and Analytics (out-of-pocket shares logged as transactions, settlements logged as income/expense).
- **Categories**: Dynamic category management including custom names/types and drag-and-drop reordering. Protects built-in "Other" category from rename/delete/reorder.
- **Analytics & Insights**: Interactive FL Chart dashboards (pie breakdown + daily trend bar chart), date-range filtering (`7days`, `30days`, `month`, `year`, `custom`), category filtering, and per-tab income/expense/net selection. Automatically synchronized with split expenses and personal transactions.
- **Settings**: Theme (system/light/dark), haptic feedback toggle, default analytics tab, custom analytics tab order, manage categories, and clear cache. All persisted via `SharedPreferences`.
- **Aesthetics & Haptics**: Sleek, customized dark and light modes using the local Inter font, rounded press highlights (`Clip.antiAlias`), and conditional haptic feedback via `AppHaptics`.

---

## 🚀 Environment Setup & Running the App

### 1. Supabase Credentials

The application resolves Supabase credentials at **compile time** via `--dart-define`. Development fallback defaults are baked into `supabase_config.dart` for convenience but should be overridden for production.

Pass these keys during the run/build phase:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Or use a file:
```bash
flutter run --dart-define-from-file=.env.json
```

### 2. Dependencies
```bash
flutter pub get
```

---

## 📂 Core Architecture Map

```
lib/
├── app/
│   ├── app.dart              # MyApp: MultiProvider setup + MaterialApp theming (light + dark)
│   └── supabase_config.dart  # SupabaseConfig singleton (compile-time credentials, client accessor)
├── models/                   # Immutable domain models — no Flutter imports, no logic
│   ├── category.dart         # CategoryModel: CRUD fields, sortWithOtherLast static helper
│   ├── profile.dart          # ProfileModel: id, email, name, displayName getter
│   ├── split_expense.dart    # SplitExpenseModel: includes embedded payer/borrower display helpers
│   └── transaction.dart      # TransactionModel: full financial record with copyWith
├── services/                 # Singleton data/auth services — only layer touching Supabase SDK
│   ├── auth_service.dart     # AuthService: sign in/up/out, OTP, retry with exponential back-off
│   └── database_service.dart # DatabaseService: TTL cache, Completer dedup, all PostgREST ops
├── viewmodels/               # ChangeNotifier state machines — all business logic lives here
│   ├── auth_viewmodel.dart   # Auth state, loading/error flags, recovery mode detection
│   ├── category_viewmodel.dart  # Category CRUD, drag reorder, seeding, computed name lists
│   ├── split_viewmodel.dart  # Feed, net balances, settle up, hidden friends; currentUserDisplayName/currentUserEmail via AuthService, profile list
│   ├── theme_viewmodel.dart  # Theme mode, haptics, analytics tab preferences (SharedPreferences)
│   └── transaction_viewmodel.dart  # Transaction feed, filters, search, analytics snapshot, optimistic ops
├── views/                    # UI screens — consume ViewModels only, no direct SDK access
│   ├── analytics/
│   │   └── analytics_page.dart   # FL Chart pie + trend bar, memoized per-category aggregations
│   ├── auth/
│   │   ├── auth_gate.dart         # Routes to LoginPage / HomePage / UpdatePasswordPage
│   │   ├── forgot_password_page.dart  # Two-step OTP recovery flow
│   │   ├── login_page.dart        # Login + signup form
│   │   └── update_password_page.dart  # Post-recovery password update
│   ├── home/
│   │   ├── home_page.dart         # Bottom nav shell, AnimatedSwitcher tab transitions
│   │   └── widgets/
│   │       ├── filter_bottom_sheet.dart  # Filter modal (type, categories, payment, dates)
│   │       └── transaction_list.dart     # Paginated transaction list with scroll-load-more
│   ├── settings/
│   │   ├── manage_categories_page.dart  # Add/edit/delete/reorder categories
│   │   └── settings_page.dart           # All app settings with Consumer bindings
│   ├── split/
│   │   ├── add_split_page.dart    # 6 split modes, Who Paid selector, live previews; user identity via SplitViewModel
│   │   ├── split_page.dart        # Friends overview with balance indicators
│   │   └── user_split_detail_page.dart  # Per-friend expense timeline + Settle Up
│   └── transaction/
│       └── add_transaction_page.dart  # Add/edit transaction form with math input & operations bar
├── widgets/
│   ├── app_dropdown.dart          # AppDropdown<T> and AppDropdownButton<T> styled wrappers
│   └── math_operations_bar.dart   # Interactive math toolbar (+, −, ×, ÷, C) + live calculation preview pill
└── utils/
    ├── date_formatter.dart   # DateFormatter: relative dates (Today/Yesterday) + time
    ├── exceptions.dart       # Typed exception hierarchy: AppException → Data/Auth/Network/Unauth
    ├── haptics.dart          # AppHaptics: conditional haptic helpers via ThemeViewModel
    └── math_evaluator.dart   # Pure Dart arithmetic evaluator supporting operators, precedence & formatting
```

---

## 🔌 Integration Details

| Concern | Implementation |
|---|---|
| Backend Database | Supabase (PostgREST API via `supabase_flutter`) |
| Authentication | Supabase Auth (stream-based session detection in `AuthViewModel`) |
| State Management | `Provider` package (`ChangeNotifier` + `Consumer<T>`) |
| Local Persistence | `SharedPreferences` (settings, analytics tab order, hidden friend IDs) |
| In-Memory Caching | 30-second TTL cache in `DatabaseService` with compound filter key |
| Concurrency Guard | `Completer`-based deduplication for concurrent transaction fetches |
| Font Loading | Local Inter font in `google_fonts/` (runtime fetching disabled) |
| Charts | `fl_chart` package (pie charts + bar charts in `AnalyticsPage`) |
| MVVM Compliance | 100% — no View or ViewModel imports `supabase_flutter` directly |

---

## 🔑 Key Architectural Decisions

1. **Singleton services** (`DatabaseService.instance`, `AuthService.instance`) — one shared cache, one shared auth state.
2. **Optimistic UI updates** with rollback in `TransactionViewModel` and `SplitViewModel` — instant perceived performance.
3. **Analytics snapshot pattern** — `TransactionViewModel.loadAnalyticsSnapshot()` loads a separate, date-filtered transaction list without clobbering the main transaction feed.
4. **`SplitViewModel` cross-VM delegation** — `toggleSettled` and `settleUpWithPartner` accept `TransactionViewModel?` to record settlement transactions. Fallback to `DatabaseService` directly if ViewModel is unavailable.
5. **Defense-in-depth security** — all DB mutations include `.eq('user_id', userId)` guards even though Supabase RLS handles server-side enforcement.
