# 💸 Expense Tracker

A modern, highly-polished, and feature-rich **Expense Tracker** application built with Flutter, backed by **Supabase** backend, and managed using the **Provider** state management pattern.

---

## 🚀 Key Features

- **🔐 Secure Authentication**: Integrated with Supabase Auth (Sign In, Sign Up, and Auth Persistence) with built-in retry logic and exponential back-off for transient network issues.
- **📊 Interactive Analytics & Insights**: Drill-down charts powered by `fl_chart` to view expenses and incomes by category, filterable by date ranges.
- **📁 Dynamic Categories Management**: Create, view, edit, and delete custom categories. Features a fluid drag-and-drop reordering interface, single-request batch creation, and database-level user ownership checks.
- **💸 Transaction Ledger**: Log income and expenses with customizable dates, categories, and descriptions. Filter by category, transaction type, or date range.
- **💾 Optimistic UI & Smart Caching**: Custom in-memory caching layer with TTL validation, concurrent request deduplication, and optimistic state updates in ViewModels to minimize network overhead and ensure instant screen transitions.
- **🎨 Rich Material 3 Aesthetics**: Tailored dynamic dark & light themes, custom Inter typography (packaged locally to avoid network delays), glassmorphism styling, premium animations, and tap-to-scroll-to-top gestures.

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
├── app/                      # Application bootstrap, routing, and configurations
│   ├── app.dart              # Main MaterialApp & MultiProvider configuration
│   └── supabase_config.dart  # Supabase client and initialization logic
├── models/                   # Domain data models (data serialization/deserialization)
│   ├── category.dart         # CategoryModel defining structure and copyWith / serialization methods
│   └── transaction.dart      # TransactionModel defining structure and copyWith / serialization methods
├── services/                 # Core business services interfacing with remote APIs/DB
│   ├── auth_service.dart     # Authentication layer with Supabase Auth & retry policies
│   └── database_service.dart # Database operations with Supabase PostgREST, Caching, and Deduplication
├── viewmodels/               # ViewModels implementing ChangeNotifier for state control
│   ├── auth_viewmodel.dart   # Auth state (loading, error, session management)
│   ├── category_viewmodel.dart # Category CRUD & ordering states
│   ├── theme_viewmodel.dart  # Custom dynamic light & dark theme states
│   └── transaction_viewmodel.dart # Transaction feed, optimistic updates, filters, and analytics snapshots
├── views/                    # UI Layer (Screens & Page-specific layouts)
│   ├── analytics/            # Analytical dashboards and interactive charts
│   ├── auth/                 # Login, signup, and authentication gates
│   ├── home/                 # Primary feed and navigation skeleton (scroll-to-top)
│   ├── settings/             # User profile and styling settings
│   └── transaction/          # Add/edit transactions & filter interfaces
├── widgets/                  # Reusable UI components & Design tokens
└── utils/                    # Helper utilities (formatting, exceptions, helpers)
```

---

## 💾 Caching & Sync Strategy

The `DatabaseService` uses an **in-memory cache** combined with query safeguards to prevent unnecessary PostgREST calls and ensure fluid navigation:
- **TTL (Time to Live)**: Cache is valid for `30 seconds`.
- **Compound Cache Key**: The cache uses a composite key generated from active filters (`type`, `category`, `startDate`, `endDate`).
- **Cache Invalidation**: Any database mutation (insert, update, delete, reordering) invalidates the cache immediately to force a sync.
- **Request Deduplication**: A concurrency guard prevents concurrent identical network requests.
- **Optimistic UI**: Transactions are inserted, updated, and deleted locally first, recalculating stats immediately, avoiding blocking spinners.

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
- `transaction_date` (Timestamptz) - Date when transaction occurred
- `created_at` (Timestamptz) - Server-side creation timestamp

### 2. `categories`
- `id` (UUID, Primary Key) - Auto-generated
- `user_id` (UUID, Foreign Key) - References Supabase Auth User
- `name` (Text) - Display label of the category
- `type` (Text) - `'expense'` or `'income'`
- `order_index` (Integer) - Order ranking for reorderable list views
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
