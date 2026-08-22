# 📁 Expense Tracker Project Context

This document provides a high-level overview of the **Expense Tracker** Flutter codebase, its state, integration, and setup instructions.

---

## 🌟 Project Overview
The Expense Tracker is a Flutter mobile application designed for personal finance tracking. It supports:
- **Authentication**: Email/Password signup, login, password resetting (request link / 6-digit OTP code verification), and secure updates powered by Supabase Auth.
- **Transactions**: Full CRUD tracking of expenses and income, supporting payment methods (UPI or Cash), customizable date/time, category details, and payment method filtering.
- **Split Expenses**:
  - User-wise grouped Friends list with overall balance banner ("Overall, you are owed...", "You are all settled up!").
  - Dedicated Friend Detail Page (`UserSplitDetailPage`) showing shared expense timeline, net friend balance, and unified Settle Up confirmation modal.
  - Settle Up functionality for both lenders and debtors, automatically recording settlement transactions.
  - Hide / Unhide friend option with `SharedPreferences` persistence and low-profile expand/collapse toggle at the bottom of the split list.
  - Excludes hidden friends from the `AddSplitPage` partner selection dropdown.
  - Two-section `AddSplitPage` form layout ("Transaction Details" and "Split Details") with strict form validation.
  - Automatic integration with personal Transactions and Analytics (out-of-pocket shares logged as transactions, settlements logged as income/expense).
- **Categories**: Dynamic category management, including custom colors/types and drag-and-drop custom list reordering.
- **Analytics & Insights**: Interactive charts, dashboards, and detailed date-range filtering automatically synchronized with split expenses and personal transactions.
- **Aesthetics & Haptics**: Sleek, customized dark and light modes using the local Inter font, rounded press highlights (`Clip.antiAlias`), and conditional haptic feedbacks.

---

## 🚀 Environment Setup & Running the App

### 1. Supabase Credentials
The application relies on compile-time configuration binding via `--dart-define` to inject the Supabase credentials. 
Ensure you pass the following keys during the build or run phase:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Example Run command:
```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### 2. Dependencies
To update or get dependencies:
```bash
flutter pub get
```

---

## 📂 Core Architecture Map

```
lib/
├── app/                  # MaterialApp configuration & Supabase client initialization
├── models/               # Domain models for categories, transactions, profiles, and split expenses
├── services/             # Data / Auth Service layer communicating with Supabase
├── viewmodels/           # Provider-based state management (ChangeNotifiers: Auth, Category, Theme, Transaction, Split)
├── views/                # Views & Screens (AuthGate, Home, Analytics, Add Transaction, Split [SplitPage, UserSplitDetailPage, AddSplitPage], Settings)
├── widgets/              # Reusable UI widgets (e.g. Dropdowns, Cards)
└── utils/                # Date formatting, Exceptions, Haptic utilities
```

---

## 🔌 Current Integration Details
- **Backend Database**: Supabase (PostgREST API).
- **State Management**: `Provider` package.
- **Local Persistence**: `SharedPreferences` (for settings, tab preferences, and hidden friend IDs).
- **Local Caching**: 30-second TTL cache implemented inside `DatabaseService` to optimize performance and prevent API rate-limits.
- **Fonts**: Local **Inter** font family to prevent flash of unstyled texts.
