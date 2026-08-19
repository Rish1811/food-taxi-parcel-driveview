# Flutter Project Architecture Guidelines

This project follows **Clean Layered Architecture** with strict separation of responsibilities.

The application is divided into the following layers:

```
lib/
├── data/
├── domain/
├── ui/
├── di/
├── platform/
├── core/
└── main.dart
```

---

# Architecture Principles

## Dependency Flow

Dependencies must always flow in one direction.

```
UI
 ↓
Domain
 ↓
Data
 ↓
Platform / External APIs
```

### Rules

- ✅ UI can depend on Domain.
- ✅ Data can depend on Domain.
- ✅ Platform can be used by Data.
- ❌ Domain must never depend on UI.
- ❌ Domain must never import Flutter.
- ❌ Data must never depend on UI.

Always depend on abstractions, never concrete implementations.

---

# Data Layer

The **Data** layer is responsible for fetching, storing, and transforming data.

It contains the implementation of repository interfaces defined in the Domain layer.

Typical structure:

```
data/
├── remote/
│   ├── api_client.dart
│   ├── auth_api.dart
│   └── ...
│
├── local/
│   ├── database.dart
│   ├── preferences.dart
│   └── ...
│
├── datasource/
├── repository/
├── dto/
├── mapper/
└── ...
```

## Responsibilities

- API calls
- Local database
- SharedPreferences
- Secure Storage
- JSON serialization
- DTO mapping
- Repository implementation
- Caching
- Network handling

Example:

```dart
abstract class AuthRepository {
  Future<User> login(String email, String password);
}
```

```dart
class AuthRepositoryImpl implements AuthRepository {
  // your logic here
}
```

### Data Layer SHOULD

- Fetch remote data
- Fetch local data
- Cache responses
- Convert DTO ↔ Domain Models

### Data Layer MUST NOT

- Contain business logic
- Perform business validation
- Know about UI
- Import Flutter widgets
- Show dialogs/snackbars

---

# Domain Layer

The **Domain** layer contains all business logic.

It is the heart of the application.

This layer should know **nothing** about:

- Flutter
- HTTP
- Firebase
- SQLite
- SharedPreferences
- Riverpod
- API implementation

Typical structure:

```
domain/
├── repository/
├── service/
├── usecase/
├── model/
├── validator/
├── exception/
└── ...
```

## Contains

- Repository interfaces
- Business services
- Use cases
- Validators
- Business models
- Business exceptions

Example:

```dart
abstract class OrderRepository {
  Future<List<Order>> getOrders();
}
```

Business service:

```dart
class OrderService {

  final OrderRepository repository;

  OrderService(this.repository);

  Future<List<Order>> activeOrders() async {
    final orders = await repository.getOrders();

    return orders.where((e) => !e.completed).toList();
  }
}
```

### Business logic belongs here

Examples:

- Order validation
- Discount calculation
- Authentication rules
- Data merging
- Sorting
- Filtering
- Permission checking
- Price calculation

### Domain MUST NOT

- Import Flutter
- Use BuildContext
- Use Riverpod
- Parse JSON
- Call APIs directly
- Show UI

---

# UI Layer

The UI layer is responsible only for presentation.

Typical structure:

```
ui/
├── branding/
├── common/
├── widgets/
├── navigation/
│
└── screens/
    ├── home/
    │   ├── home_screen.dart
    │   ├── home_provider.dart
    │   ├── home_state.dart
    │   └── widgets/
    │
    ├── login/
    └── profile/
```

## Responsibilities

- Screens
- Widgets
- Navigation
- Riverpod Providers
- UI State
- Animations
- User interaction

### Screen SHOULD

- Display UI
- Observe provider state
- Send user actions

### Screen MUST NOT

- Call APIs
- Parse JSON
- Contain business logic
- Read databases

---

# State Management

Riverpod is used for dependency injection and presentation state.

Each screen should have:

```
home_screen.dart
home_provider.dart
home_state.dart
```

Provider responsibilities:

- Call Domain services
- Manage screen state
- Handle loading/error states
- Expose immutable state

Providers should **never** contain complex business logic.

---

# Dependency Injection (DI)

The DI layer wires the application together.

Typical structure:

```
di/
├── api_provider.dart
├── repository_provider.dart
├── service_provider.dart
└── app_provider.dart
```

Responsibilities:

- Create repositories
- Create services
- Register providers
- Configure API clients
- Configure database
- Configure SharedPreferences

Dependency chain:

```
API
   ↓

RepositoryImpl
   ↓

Service
   ↓

Provider
   ↓

Screen
```

---

# Platform Layer

Contains platform-specific implementations.

Examples:

```
platform/
├── camera/
├── notification/
├── permission/
├── download/
├── filesystem/
├── pigeon/
└── ...
```

Responsibilities:

- Method Channels
- Pigeon
- Camera
- Notifications
- Downloads
- Permissions
- Native SDK wrappers

Business logic should never exist here.

---

# Core Layer

Contains reusable utilities used across the application.

Typical structure:

```
core/
├── constants/
├── config/
├── logger/
├── errors/
├── network/
├── extensions/
├── utils/
└── theme/
```

Contains:

- Constants
- App configuration
- Logger
- Utilities
- Shared extensions
- Error classes
- Network helpers

Core should remain generic and reusable.

---

# Repository Rules

Repositories abstract data sources.

Flow:

```
UI

↓

Service

↓

Repository Interface

↓

Repository Implementation

↓

API / Database
```

Repositories should not perform business calculations.

---

# Model Flow

Never expose API models directly to UI.

```
JSON

↓

DTO

↓

Mapper

↓

Domain Model

↓

UI State
```

Each layer owns its own models.

---

# Error Handling

Prefer typed errors over generic exceptions.

Examples:

```
NetworkException

AuthenticationException

ValidationException

PermissionException

UnknownException
```

UI converts errors into user-friendly messages.

---

# Testing

Every layer should be independently testable.

Domain:

- Unit tests
- Business logic tests

Data:

- Repository tests
- Mapper tests
- API tests

UI:

- Widget tests
- Provider tests

Platform:

- Mock native integrations

---

# Naming Conventions

Good:

```
AuthRepository

AuthRepositoryImpl

AuthService

HomeProvider

HomeState

UserDto

UserMapper

UserModel
```

Avoid:

```
Helper

Utils

Manager

Common

Base

Temp

Data
```

unless they are truly generic.

---

# AI Agent Instructions

When generating code for this project, always follow these rules.

## Architecture

- Respect layer boundaries.
- Never violate dependency flow.
- Domain must stay framework independent.
- Data implements Domain interfaces.
- UI depends on Domain only.

## Business Logic

- Place all business rules inside the Domain layer.
- Never place business logic inside UI.
- Never place business logic inside repositories.

## UI

- Screens should only render UI.
- Providers should only manage presentation state.
- Providers should call Domain services.

## Data

- Convert JSON into DTOs.
- Convert DTOs into Domain Models.
- Never expose DTOs to UI.

## Code Quality

- Prefer composition over inheritance.
- Keep classes small and focused.
- Follow Single Responsibility Principle.
- Write immutable models.
- Use dependency injection.
- Avoid duplicate code.
- Write readable and maintainable code.
- Keep functions short and focused.

## General Rules

- Follow existing folder structure.
- Follow existing naming conventions.
- Don't introduce a new architecture.
- Don't bypass services.
- Don't access APIs directly from UI.
- Don't access databases directly from UI.
- Don't import Flutter into Domain.
- Keep every feature modular and testable.

When adding a new feature, always place new files in the correct layer instead of creating arbitrary folders.