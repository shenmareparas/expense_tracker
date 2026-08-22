# 📁 Expense Tracker Project Context

This document provides a high-level overview of the **Expense Tracker** Flutter codebase, its state, integration, and setup instructions.

---

## 🌟 Project Overview
The Expense Tracker is a Flutter mobile application designed for personal finance tracking. It supports:
- **Authentication**: Email/Password signup, login, password resetting (request link / 6-digit OTP code verification), and secure updates powered by Supabase Auth.
- **Transactions**: Full CRUD tracking of expenses and income, supporting payment methods (UPI or Cash), customizable date/time, category details, and payment method filtering.
- **Split Expenses**: Share expenses with registered app users. Supports payer toggling ("You Paid" / "They Paid"), debt calculation, and settlement status updates.
- **Categories**: Dynamic category management, including custom colors/types and drag-and-drop custom list reordering.
- **Analytics & Insights**: Beautiful interactive charts, dashboards, and detailed date-range filtering.
- **Aesthetics & Haptics**: Sleek, customized dark and light modes using the local Inter font and conditional haptic feedbacks.

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
├── views/                # Views & Screens (AuthGate, Home, Analytics, Add Transaction, Split, Settings)
├── widgets/              # Reusable UI widgets (e.g. Dropdowns, Cards)
└── utils/                # Date formatting, Exceptions, Haptic utilities
```

---

## 🔌 Current Integration Details
- **Backend Database**: Supabase (PostgREST API).
- **State Management**: `Provider` package.
- **Local Caching**: 30-second TTL cache implemented inside `DatabaseService` to optimize performance and prevent API rate-limits.
- **Fonts**: Local **Inter** font family to prevent flash of unstyled texts.
