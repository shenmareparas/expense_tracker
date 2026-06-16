# 🌌 Gemini & AI Agent Guide for Expense Tracker

Welcome! This document outlines the architecture, patterns, guidelines, and conventions for the **Expense Tracker** Flutter codebase. AI assistants (such as Gemini/Antigravity) should read and follow these standards strictly when proposing modifications or additions.

---

## 🏗️ Project Architecture & Tech Stack

This project is built using a clean, modern **MVVM (Model-View-ViewModel) + Service** architecture in Flutter, backed by **Supabase** and powered by the **Provider** package for state management.

```
lib/
├── app/                      # Application bootstrap, routing, and configurations
│   ├── app.dart              # Main MaterialApp & MultiProvider configuration
│   └── supabase_config.dart  # Supabase client and initialization logic (compile-time definitions)
├── models/                   # Domain data models (data serialization/deserialization)
│   ├── category.dart         # CategoryModel defining structure and copyWith / serialization methods
│   └── transaction.dart      # TransactionModel defining structure and copyWith / serialization methods
├── services/                 # Core business services interfacing with remote APIs/DB
│   ├── auth_service.dart     # Authentication layer with Supabase Auth & back-off retry logic
│   └── database_service.dart # Database operations with Supabase PostgREST, Caching, and Deduplication
├── viewmodels/               # ViewModels implementing ChangeNotifier for state control
│   ├── auth_viewmodel.dart   # Auth state (loading, error, session management)
│   ├── category_viewmodel.dart # Category CRUD & ordering states
│   ├── theme_viewmodel.dart  # Custom dynamic light & dark theme states, haptic preferences, default analytics tab, and custom tab ordering
│   └── transaction_viewmodel.dart # Transaction feed (non-paginated full loads), optimistic updates, multi-select category filters, and analytics snapshots
├── views/                    # UI Layer (Screens & Page-specific layouts)
│   ├── analytics/            # Analytical dashboards and interactive charts
│   │   └── analytics_page.dart # Interactive insights, charts, and date filter drill-downs
│   ├── auth/                 # Login, signup, and authentication gates
│   │   ├── auth_gate.dart    # Controls auth routing flow (authenticated vs unauthenticated)
│   │   └── login_page.dart   # Interactive authentication screens with micro-animations
│   ├── home/                 # Primary feed and navigation skeleton
│   │   ├── home_page.dart    # Bottom nav layout hosting list, analytics & settings with scroll-to-top tapping
│   │   └── widgets/          # Home-specific layouts
│   │       ├── filter_bottom_sheet.dart # Slide-out category and type filters
│   │       └── transaction_list.dart    # Smooth, scrollable, filtered transaction feed
│   ├── settings/             # User profile and styling settings
│   │   ├── settings_page.dart # Settings screen (theme switch, category management, logout)
│   │   └── manage_categories_page.dart # List & reorderable categories view
│   └── transaction/          # Add/edit transactions & filter interfaces
│       └── add_transaction_page.dart # Comprehensive transaction creation & modification form
├── widgets/                  # Reusable UI components & Design tokens
│   └── app_dropdown.dart     # Reusable animated and styled dropdowns
└── utils/                    # Helper utilities
    ├── date_formatter.dart   # Date utility functions (formatting dates & times)
    ├── exceptions.dart       # Typed exception hierarchy (AppException, NetworkException, etc.)
    └── haptics.dart          # Conditional haptic feedback utility (vibrations, impacts, clicks)

```

---

## 💾 Caching & Concurrency Strategy (`DatabaseService`)

The project uses a custom, dynamic in-memory caching mechanism in the `DatabaseService` to ensure smooth tab-switching, avoid redundant Supabase REST API overhead, and keep data sync performant.

> [!IMPORTANT]
> - **TTL Configuration**: Caches remain valid for `30 seconds` (`_cacheTtl`).
> - **Compound Cache Key**: The transaction cache builds a unique string key based on selected query filters (`type`, `categories` list, `startDate`, `endDate`). Changing any filter bypasses the stale cache and triggers a fresh remote load.
> - **Invalidation**: All mutation operations (add, edit, delete, reorder) must explicitly invalidate the relevant cache to guarantee immediate data updates in the UI.
> - **Request Deduplication**: A concurrency guard using `_ongoingTransactionFetch` (via the `Completer` pattern) prevents concurrent callers from spawning duplicate identical network requests for full transaction loads.

---

## ⚠️ Exception Handling & Reliability

To prevent leaking raw database and HTTP network errors directly to the UI, the app enforces a typed exception structure:

- **Exception Hierarchy (`lib/utils/exceptions.dart`)**:
  - `AppException` (Base exception)
  - `UnauthenticatedException` (Thrown when user session is missing or invalid)
  - `DataException` (PostgREST or general database issues)
  - `AppAuthException` (Authentication credentials/session failure)
  - `NetworkException` (Transient SocketExceptions/connectivity failures)
- **Service Error Mapping**: `DatabaseService` wraps operations inside a `_execute` helper, utilizing `_mapError` to map exceptions. `AuthService` maps errors using `_throwMappedError`.
- **Auth Retries**: The `AuthService` automatically retries operations up to `3` times (`_maxAttempts`) using exponential back-off delays when detecting network-level connectivity failures.

---

## 🛡️ Database Schema & PostgREST Operations

All data columns map strictly between remote database fields and Flutter immutable domain models. To ensure data privacy, the Service layer incorporates **defense-in-depth security** by including `user_id` checks on all operations modifying or deleting data.

### 1. `transactions` Table

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | UUID (Primary Key) | Auto-generated transaction identifier |
| `user_id` | UUID (Foreign Key) | Reference to Supabase Auth User ID (Always validated in queries) |
| `amount` | Numeric | Decimal transaction value |
| `type` | Text | Type identifier: `'expense'` or `'income'` |
| `category` | Text | Associated category name |
| `description` | Text (Optional) | Optional memo or note |
| `transaction_date`| Timestamptz | The customized date/time when transaction occurred |
| `created_at` | Timestamptz | Server-side record creation timestamp |

### 2. `categories` Table

| Field | Type | Description |
| :--- | :--- | :--- |
| `id` | UUID (Primary Key) | Auto-generated category identifier |
| `user_id` | UUID (Foreign Key) | Reference to Supabase Auth User ID (Always validated in queries) |
| `name` | Text | The display label of the category |
| `type` | Text | Type identifier: `'expense'` or `'income'` |
| `order_index` | Integer | Order ranking for reorderable list views |
| `created_at` | Timestamptz | Server-side record creation timestamp |

> [!TIP]
> - **Batch Categories Insertion**: Use `addCategories(List<Map<String, dynamic>>)` to insert multiple categories in a single database round-trip.
> - **Batch Category Reordering**: Use `reorderCategories(List<CategoryModel>)` which upserts order rankings using the minimal payload (`id` and `order_index`) to prevent side-effects on creation timestamps.

---

## 🎨 UI & UX Principles

1. **Material 3 Design**: Utilize Material 3 widgets, design patterns, and standards.
2. **Dynamic Theming**: Support dark & light modes seamlessly. Use theme configurations defined in `lib/app/app.dart` via `ThemeViewModel`.
3. **Curated Color Palettes**:
   - Primary light-mode seed: Indigo (`#4F46E5`)
   - Primary dark-mode seed: Lavender-Indigo (`#818CF8`)
   - Dark mode uses rich, custom charcoal/black styling (`#000000` base with `#0A0A0A` surface colors) instead of default grayish tones.
4. **Rich Aesthetics**:
   - Rounded corners (`BorderRadius.circular(20)` or higher for modern visual appeal).
   - High-contrast, premium text scales using the **Inter** Google Font family (packaged locally inside `google_fonts/` to prevent runtime fetching and styling delays).
   - Clean, smooth page transitions and micro-animations.
5. **Scroll-to-Top Gesture**: Double-tapping the active navigation item or the AppBar title smoothly scrolls scrollable lists back to the top.
6. **Tactile Haptic Feedback**: Use physical click and vibration sensations to reinforce UI feedback. Interactions must check user preferences (`ThemeViewModel.hapticEnabled`) before executing haptic events.

---

## 🛠️ Code Conventions & Best Practices

### 1. State Management (Provider) & Optimistic Updates
- Always expose business logic and UI states through **ChangeNotifier** in `viewmodels/`.
- Use `Consumer<T>` or `context.watch<T>()` in the UI to react to changes.
- Use `context.read<T>()` inside callbacks (e.g., `onPressed`) to trigger actions without rebuilding the widget tree needlessly.
- **Optimistic UI Updates**: `TransactionViewModel` updates lists immediately when a transaction is added, updated, or deleted. It recomputes aggregates and only invalidates the remote cache (or executes background sync) without blocking the user on heavy full-refresh network calls.
- **Full Dataset Loading (Non-paginated)**: To ensure accurate computation of aggregates and analytics, transaction loading is non-paginated.
- **Multi-select Category Filters**: Filtering supports selecting multiple categories simultaneously (an empty list selects all categories). The filter state is managed inside `TransactionViewModel`.

### 2. Services & Supabase Integration
- Centralize all API/DB communication in `services/`. Views and ViewModels should **never** access Supabase or any REST clients directly.
- Ensure all database calls handle exceptions gracefully using the typed `AppException` system.
- Leverage compile-time configuration binding via `--dart-define` for `SUPABASE_URL` and `SUPABASE_ANON_KEY` in `SupabaseConfig`.

### 3. Models & Data Serialization
- Implement strict types and clean model classes with `fromJson()` and `toJson()` constructors.
- Always define immutable fields (`final`) inside your domain model objects and include a standard `copyWith()` method for state modification.

### 4. File Structure & Imports
- Use relative imports (e.g., `import '../../models/transaction.dart'`) for internal packages within the project, ensuring clear, modular dependencies.
- Ensure clear, expressive comments, proper docstrings (`///`), and follow all rules defined in `analysis_options.yaml`.

### 5. Conditional Haptic Feedback (`AppHaptics`)
- Avoid calling standard `HapticFeedback` directly from `package:flutter/services.dart`. Use `AppHaptics` in `lib/utils/haptics.dart` instead.
- Use `AppHaptics.selectionClick(context)` for general click inputs, dropdown modifications, date/time pickers, and page toggles.
- Use `AppHaptics.lightImpact(context)` or `AppHaptics.mediumImpact(context)` when saving, submitting forms, or performing non-destructive state changes.
- Use `AppHaptics.vibrate(context)` for critical confirmation states (e.g., deletions, logging out).


---

## 🚀 Step-by-Step Workflow for Coding

When implementing new features or editing existing ones:

1. **Analyze Dependencies**: Check if additional packages are needed in `pubspec.yaml`.
2. **Implement/Extend Models**: Ensure data schemas are correctly represented.
3. **Build Services**: Write the backend API interactions first. Wrap database/network calls with proper typed exceptions.
4. **Create ViewModels**: Glue the services and properties into observable states. Handle optimistic list modifications for instant feedback.
5. **Develop Views & Widgets**: Design stunning responsive interfaces mapped to the ViewModel states. Ensure scrollable lists have ScrollControllers attached for scroll-to-top actions.
6. **Verify & Clean up**: Test locally and run analyzer/linter tasks to guarantee premium quality.

---

*Let's build something beautiful, fluid, and robust!*
