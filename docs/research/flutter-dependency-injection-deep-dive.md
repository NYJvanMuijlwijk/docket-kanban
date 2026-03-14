# Flutter Dependency Injection Deep Dive

*A comprehensive guide for solo developers and freelancers*
*Last updated: March 2026*

---

## Table of Contents

1. [What is Dependency Injection in Flutter?](#1-what-is-dependency-injection-in-flutter)
2. [Built-in / Framework-Level DI](#2-built-in--framework-level-di)
3. [BLoC's Approach to DI](#3-blocs-approach-to-di)
4. [Riverpod's Approach to DI](#4-riverpods-approach-to-di)
5. [get_it -- The Service Locator Alternative](#5-get_it--the-service-locator-alternative)
6. [Other DI Solutions](#6-other-di-solutions)
7. [Head-to-Head Comparison](#7-head-to-head-comparison)
8. [Common Patterns Across All Approaches](#8-common-patterns-across-all-approaches)
9. [Recommendations for Solo Dev / Freelance](#9-recommendations-for-solo-dev--freelance)
10. [Code Examples](#10-code-examples)

---

## 1. What is Dependency Injection in Flutter?

### The Core Principle

Dependency Injection (DI) is a design pattern where an object receives its dependencies from external sources rather than creating them itself. Instead of a class calling `ApiClient()` internally, the `ApiClient` is passed in -- "injected" -- from outside.

The three core benefits:

- **Testability**: Swap real implementations for mocks/fakes without changing the class under test.
- **Loose coupling**: Classes depend on abstractions (interfaces), not concrete implementations.
- **Configurability**: Swap implementations based on environment (dev/staging/prod) without code changes.

### How Flutter's Widget Tree Naturally Relates to DI

Flutter's widget tree is itself a form of dependency injection infrastructure. When a parent widget creates a child and passes data down through constructor parameters, that is constructor injection. Flutter extends this concept through `InheritedWidget`, which allows any descendant widget to "look up" a value provided by an ancestor -- effectively making the widget tree a hierarchical DI container.

This is different from most server-side frameworks where DI containers are standalone objects. In Flutter, the widget tree *is* the container for most DI approaches.

### Service Locator vs True DI vs Provider-Based DI

These three patterns are often conflated but have meaningful differences:

**True Dependency Injection (Constructor Injection)**
```dart
class AuthBloc {
  final AuthRepository authRepo;
  AuthBloc(this.authRepo); // dependency is injected via constructor
}
```
The class declares what it needs; the caller provides it. The class has no knowledge of where dependencies come from. This is the purest form of DI.

**Service Locator Pattern**
```dart
class AuthBloc {
  final authRepo = GetIt.I<AuthRepository>(); // class reaches out and grabs it
}
```
The class actively retrieves its own dependencies from a global registry. The class knows about the locator. This is technically an anti-pattern in strict DI terminology, but it is pragmatic and widely used. `get_it` is the canonical Flutter service locator.

**Provider-Based DI (Widget-Tree DI)**
```dart
// Provided high in tree
BlocProvider(create: (ctx) => AuthBloc(ctx.read<AuthRepository>()))

// Consumed lower in tree
final bloc = context.read<AuthBloc>();
```
Dependencies are scoped to sections of the widget tree. Widgets access them via `BuildContext`. This is what BLoC (`BlocProvider`/`RepositoryProvider`), Provider, and (partially) Riverpod use. It is a hybrid: the framework does the injection, but resolution happens through the widget tree rather than constructor parameters alone.

**Key distinction**: Service locators make dependencies available *globally*. Widget-tree DI makes them available *within a subtree*. True constructor injection makes them available *only to the class that declares the parameter*. Each trades off convenience for explicitness.

---

## 2. Built-in / Framework-Level DI

### InheritedWidget as Flutter's Native DI Mechanism

`InheritedWidget` is Flutter's built-in mechanism for propagating data down the widget tree efficiently. It is the foundation on which Provider, BLoC's providers, and even parts of Riverpod are built.

```dart
class AppConfig extends InheritedWidget {
  final String apiBaseUrl;
  final bool isDebug;

  const AppConfig({
    required this.apiBaseUrl,
    required this.isDebug,
    required super.child,
    super.key,
  });

  static AppConfig of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppConfig>()!;
  }

  @override
  bool updateShouldNotify(AppConfig oldWidget) {
    return apiBaseUrl != oldWidget.apiBaseUrl || isDebug != oldWidget.isDebug;
  }
}
```

This works, but requires significant boilerplate for each new dependency you want to provide.

### How Provider Builds on InheritedWidget

The `provider` package (by Remi Rousselet, who also created Riverpod) wraps `InheritedWidget` with a much cleaner API:

```dart
// Providing
Provider<AuthRepository>(
  create: (_) => AuthRepository(httpClient: HttpClient()),
  child: MyApp(),
)

// Consuming
final repo = context.read<AuthRepository>();
// or reactively:
final repo = context.watch<AuthRepository>();
```

Provider adds automatic disposal, lazy creation, `MultiProvider` for reducing nesting, and `ChangeNotifierProvider` / `StreamProvider` for reactive state. Google's Flutter team officially recommends Provider for dependency injection in many of their guides.

### Limitations of Widget-Tree-Based DI

Despite being Flutter-idiomatic, widget-tree DI has real constraints:

1. **Requires BuildContext**: You cannot access provided dependencies in places that lack a `BuildContext` -- service classes, utility functions, isolates, or platform channel handlers. This is the single biggest limitation.

2. **One provider per type**: Both `InheritedWidget` and `Provider` resolve by type. If you need two instances of the same type (e.g., two different `HttpClient` configurations), you need workarounds like wrapper types or named extensions.

3. **Runtime resolution**: If you forget to provide a dependency, you get a runtime error (`ProviderNotFoundException`), not a compile-time error. In a large widget tree, this can be hard to trace.

4. **Scoping rigidity**: Dependencies are scoped to the widget subtree where they are provided. If your widget tree structure changes (e.g., navigation refactoring), your DI scoping may break unexpectedly.

5. **Initialization ordering**: Complex dependency graphs with async initialization (e.g., database connections, SharedPreferences) require careful ordering of providers, often leading to `FutureProvider` chains or manual initialization in `main()`.

6. **Testing ceremony**: While testable, you need to wrap widgets in the appropriate providers in every test, which adds setup boilerplate.

---

## 3. BLoC's Approach to DI

The `flutter_bloc` package provides its own DI widgets that are purpose-built for the BLoC pattern but follow the same widget-tree DI model as Provider.

### How BlocProvider Works

`BlocProvider` is a widget that creates a BLoC/Cubit instance and makes it available to its descendants:

```dart
BlocProvider(
  create: (context) => AuthBloc(
    authRepository: context.read<AuthRepository>(),
  ),
  child: LoginPage(),
)
```

Key behaviors:

- **Lazy instantiation**: By default, the `create` callback is not called until the first time the BLoC is looked up via `context.read<AuthBloc>()` or `BlocBuilder`. You can override this with `lazy: false`.
- **Automatic disposal**: When the `BlocProvider` is removed from the widget tree, it automatically calls `close()` on the BLoC, cleaning up streams.
- **Subtree scoping**: The BLoC is only accessible to widgets within the `BlocProvider`'s subtree.

### MultiBlocProvider

Reduces nesting when providing multiple BLoCs at the same level:

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (ctx) => AuthBloc(ctx.read<AuthRepository>())),
    BlocProvider(create: (ctx) => ThemeBloc()),
    BlocProvider(create: (ctx) => SettingsBloc(ctx.read<SettingsRepository>())),
  ],
  child: MyApp(),
)
```

This is purely syntactic sugar -- the behavior is identical to nesting `BlocProvider` widgets.

### RepositoryProvider for Non-BLoC Dependencies

`RepositoryProvider` is the BLoC ecosystem's answer for injecting non-BLoC dependencies (repositories, services, API clients):

```dart
MultiRepositoryProvider(
  providers: [
    RepositoryProvider(create: (_) => HttpClient()),
    RepositoryProvider(
      create: (ctx) => AuthRepository(httpClient: ctx.read<HttpClient>()),
    ),
    RepositoryProvider(
      create: (ctx) => UserRepository(httpClient: ctx.read<HttpClient>()),
    ),
  ],
  child: MultiBlocProvider(
    providers: [
      BlocProvider(create: (ctx) => AuthBloc(ctx.read<AuthRepository>())),
    ],
    child: MyApp(),
  ),
)
```

`RepositoryProvider` supports a `dispose` callback for cleanup:

```dart
RepositoryProvider(
  create: (_) => DatabaseService(),
  dispose: (db) => db.close(),
  child: MyApp(),
)
```

The convention is clear: `RepositoryProvider` for data-layer dependencies, `BlocProvider` for BLoCs/Cubits.

### BlocProvider.value for Existing Instances

When you already have a BLoC instance and want to provide it to a new subtree (common with navigation), use `BlocProvider.value`:

```dart
// When navigating to a new route but keeping the same BLoC
Navigator.push(context, MaterialPageRoute(
  builder: (_) => BlocProvider.value(
    value: context.read<AuthBloc>(), // existing instance
    child: ProfilePage(),
  ),
));
```

Important: `BlocProvider.value` does **not** manage the BLoC's lifecycle. It will not call `close()` when disposed. The original `BlocProvider` that created the BLoC is responsible for disposal.

### How BLoC Handles Scoping

BLoC supports three common scoping patterns:

**App-level (global) scope**: BLoCs provided above `MaterialApp` -- available everywhere.
```dart
BlocProvider(
  create: (_) => AuthBloc(authRepo),
  child: MaterialApp(home: HomePage()),
)
```

**Feature-level scope**: BLoCs provided at a feature's root widget -- available to all screens within that feature.
```dart
// In your router or feature shell
BlocProvider(
  create: (ctx) => CartBloc(ctx.read<CartRepository>()),
  child: CartFeatureShell(), // contains cart list, cart detail, checkout
)
```

**Page-level scope**: BLoCs provided for a single screen -- created and disposed with that screen.
```dart
class OrderPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => OrderBloc(ctx.read<OrderRepository>()),
      child: OrderView(),
    );
  }
}
```

### Nested/Hierarchical DI with BLoC

BLoC's widget-tree DI naturally supports nesting. A child `BlocProvider` can shadow a parent's provider of the same type:

```dart
BlocProvider(
  create: (_) => ThemeBloc(defaultTheme),
  child: Column(children: [
    // Uses parent ThemeBloc
    ThemeDisplay(),
    // This subtree gets a different ThemeBloc
    BlocProvider(
      create: (_) => ThemeBloc(customTheme),
      child: CustomSection(),
    ),
  ]),
)
```

Child BLoCs can also depend on parent-provided BLoCs or repositories, creating a natural dependency hierarchy that mirrors the UI structure.

### Testing with BLoC DI

Testing BLoC with DI is straightforward -- wrap your widget in the required providers with mock implementations:

```dart
testWidgets('LoginPage shows error on failure', (tester) async {
  final mockAuthBloc = MockAuthBloc();
  when(() => mockAuthBloc.state).thenReturn(AuthError('Invalid credentials'));

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: mockAuthBloc,
        child: LoginPage(),
      ),
    ),
  );

  expect(find.text('Invalid credentials'), findsOneWidget);
});
```

The `bloc_test` package provides `MockBloc` and `MockCubit` classes that work with `mocktail` or `mockito`.

### Limitations and Pain Points

1. **No compile-time safety**: Forgetting a `RepositoryProvider` higher in the tree causes a runtime crash, not a build error.
2. **Navigation complications**: Pushing a new route creates a new widget subtree. BLoCs from the previous route are not automatically available. You must use `BlocProvider.value` or provide BLoCs above the navigator.
3. **Boilerplate accumulates**: For large apps, the `MultiBlocProvider`/`MultiRepositoryProvider` setup in `main()` or app shell becomes very long.
4. **No built-in async initialization**: If a repository requires async setup (e.g., opening a database), you must handle that before providing it, typically with a splash screen or `FutureBuilder`.
5. **Circular dependencies are silent**: If BLoC A depends on BLoC B and vice versa, there is no tooling to detect this at build time.
6. **Context requirement**: The standard pattern requires `BuildContext` to access dependencies, which means BLoCs that need to create other BLoCs must receive them via constructor injection rather than looking them up.

---

## 4. Riverpod's Approach to DI

Riverpod (created by Remi Rousselet, the author of Provider) was designed from the ground up to solve Provider's limitations. As of Riverpod 3.0 (released September 2025), it is a mature, production-ready DI and state management solution.

### How Riverpod Providers Work

Unlike BLoC/Provider, Riverpod providers are declared as **global top-level variables**. Despite being "global," they are lazily instantiated and their lifecycle is managed by a `ProviderContainer`:

```dart
// Declared globally -- but NOT instantiated globally
final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(baseUrl: 'https://api.example.com');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  return AuthRepository(httpClient: httpClient);
});
```

Key characteristics:
- **Compile-time resolution**: Provider dependencies are declared explicitly via `ref.watch`/`ref.read`. If you mistype a provider name, you get a compile error.
- **No BuildContext needed**: Providers can depend on other providers without any widget tree context.
- **Automatic dependency tracking**: Riverpod knows the dependency graph and will rebuild downstream providers when upstream ones change.

### ProviderScope and Overrides

Every Riverpod app is wrapped in a `ProviderScope` at the root:

```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

You can override any provider in a `ProviderScope`, which is the foundation of Riverpod's testability and environment configuration:

```dart
ProviderScope(
  overrides: [
    httpClientProvider.overrideWithValue(MockHttpClient()),
    authRepositoryProvider.overrideWith((ref) => FakeAuthRepository()),
  ],
  child: MyApp(),
)
```

### Auto-Dispose and Lifecycle Management

Riverpod 3.0 unified the API so that all providers support auto-dispose by default (previously, you needed separate `AutoDispose` variants). When no widget or provider is listening to a provider, it is automatically disposed after a configurable delay.

You can control lifecycle explicitly:

```dart
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // Called when provider is first read
    // Called again if provider is invalidated
    ref.onDispose(() {
      // Cleanup when provider is disposed
    });
    return AuthState.initial();
  }
}
```

Riverpod 3.0 also introduced **pause/resume**: when a widget goes off-screen, its provider listeners are automatically paused, reducing unnecessary computation.

### ref.watch, ref.read, ref.listen Patterns

These three methods are how you interact with providers:

**`ref.watch(provider)`** -- Reactive subscription. Use in `build` methods and provider bodies. Rebuilds when the watched provider changes.
```dart
// In a widget
Widget build(BuildContext context, WidgetRef ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.when(
    authenticated: (user) => HomePage(user: user),
    unauthenticated: () => LoginPage(),
  );
}

// In a provider
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  // Re-fetches when auth state changes
  return ref.watch(userRepositoryProvider).getProfile(authState.userId);
});
```

**`ref.read(provider)`** -- One-time read without subscription. Use in event handlers, callbacks, and `onPressed`.
```dart
ElevatedButton(
  onPressed: () {
    ref.read(authNotifierProvider.notifier).logout();
  },
  child: Text('Logout'),
)
```

**`ref.listen(provider, callback)`** -- Listen for changes and execute a side effect (e.g., show a snackbar, navigate). Does not trigger rebuilds.
```dart
ref.listen(authNotifierProvider, (previous, next) {
  if (next is AuthError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next.message)),
    );
  }
});
```

### Provider Dependencies

Providers can depend on other providers naturally through `ref.watch`:

```dart
final httpClientProvider = Provider<HttpClient>((ref) => HttpClient());

final authRepoProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(httpClient: ref.watch(httpClientProvider));
});

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.watch(authRepoProvider);
    // Use repo...
    return AuthState.initial();
  }
}
```

Riverpod automatically tracks these dependencies and will:
- Rebuild `authRepoProvider` if `httpClientProvider` changes.
- Rebuild `authNotifierProvider` if `authRepoProvider` changes.

### Family Providers for Parameterized DI

Family providers let you create provider "instances" parameterized by a value:

```dart
// Without code generation
final userProvider = FutureProvider.family<User, String>((ref, userId) async {
  return ref.watch(userRepositoryProvider).getUser(userId);
});

// Usage
final user = ref.watch(userProvider('user-123'));
final otherUser = ref.watch(userProvider('user-456'));
// These are independent provider instances

// With riverpod_generator
@riverpod
Future<User> user(Ref ref, {required String userId}) async {
  return ref.watch(userRepositoryProvider).getUser(userId);
}
```

Each unique parameter value creates a separate provider instance with independent state and lifecycle.

### Scoped Providers (ProviderScope Overrides for Subtrees)

You can nest `ProviderScope` to override providers for specific subtrees:

```dart
// Root provides production auth
ProviderScope(
  child: MaterialApp(
    home: Column(children: [
      // This section uses the root auth provider
      AuthStatusWidget(),

      // This section gets a different auth implementation
      ProviderScope(
        overrides: [
          authRepoProvider.overrideWith((ref) => SandboxAuthRepository()),
        ],
        child: SandboxSection(),
      ),
    ]),
  ),
)
```

This is useful for theming subtrees, feature flags, or providing different configurations to different parts of the app.

### Testing with Riverpod DI

Riverpod's testing story is one of its strongest features. You can use `ProviderContainer` for unit tests and `ProviderScope` overrides for widget tests:

**Unit testing (no widgets)**:
```dart
test('AuthNotifier logs in successfully', () async {
  final container = ProviderContainer(
    overrides: [
      authRepoProvider.overrideWithValue(FakeAuthRepository()),
    ],
  );
  addTearDown(container.dispose);

  final notifier = container.read(authNotifierProvider.notifier);
  await notifier.login('user@test.com', 'password');

  expect(container.read(authNotifierProvider), isA<Authenticated>());
});
```

**Widget testing**:
```dart
testWidgets('LoginPage shows welcome on success', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepoProvider.overrideWithValue(FakeAuthRepository()),
      ],
      child: MaterialApp(home: LoginPage()),
    ),
  );

  // No need to wrap in multiple providers -- Riverpod resolves the graph
});
```

### Code Generation with riverpod_generator

The `riverpod_generator` package (paired with `riverpod_annotation`) reduces boilerplate significantly. Instead of manually declaring provider types:

```dart
// Without code generation
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() { ... }
}

// With code generation
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() { ... }
}
// authNotifierProvider is generated automatically

// Simple providers become even simpler
@riverpod
HttpClient httpClient(Ref ref) => HttpClient();
// httpClientProvider is generated automatically
```

The generator automatically:
- Chooses the correct provider type (Provider, FutureProvider, NotifierProvider, etc.).
- Handles auto-dispose configuration.
- Generates family providers when parameters are present.
- Creates properly typed override methods for testing.

### Limitations and Pain Points

1. **Global declarations feel wrong**: Declaring providers as top-level variables is philosophically uncomfortable for developers from DI-heavy backgrounds (Angular, Spring). Despite being safe in practice, it looks like global mutable state.

2. **Learning curve for ref patterns**: Knowing when to use `ref.watch` vs `ref.read` vs `ref.listen` requires understanding Riverpod's reactive model. Misusing `ref.read` where `ref.watch` is needed (or vice versa) causes subtle bugs.

3. **Code generation dependency**: The recommended path uses `build_runner`, which adds build complexity and can slow down development iteration in large projects.

4. **Debugging can be opaque**: When providers rebuild unexpectedly, tracing the cause through the dependency graph is harder than with explicit event-driven architectures like BLoC.

5. **Migration churn**: The API has changed significantly between major versions (1.0 to 2.0 to 3.0). Codebases that adopted early have had to migrate multiple times. Riverpod 3.0 deprecated `StateProvider`, `StateNotifierProvider`, and `ChangeNotifierProvider`.

6. **Scoped overrides can be surprising**: Nested `ProviderScope` overrides do not always behave intuitively, especially when providers depend on other providers that are not overridden in the same scope.

---

## 5. get_it -- The Service Locator Alternative

`get_it` is a simple, fast service locator for Dart and Flutter. It stores dependencies in a `Map` (no reflection), making it lightweight and performant.

### How get_it Works

```dart
final getIt = GetIt.instance; // or GetIt.I for short

// Registration (typically in a setup function called from main)
void setupDependencies() {
  getIt.registerSingleton<HttpClient>(HttpClient(baseUrl: 'https://api.example.com'));
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(httpClient: getIt<HttpClient>()),
  );
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );
}

// Usage -- anywhere, no context needed
final authBloc = getIt<AuthBloc>();
final repo = GetIt.I<AuthRepository>();
```

The central value proposition: **no BuildContext required**. You can access dependencies from anywhere -- services, BLoCs, utility classes, isolate setup code, platform channels.

### Registration Types

**`registerSingleton<T>(instance)`**: Registers an already-created instance. Same instance returned every time. Created immediately.

**`registerLazySingleton<T>(() => instance)`**: Like singleton, but the factory is not called until the first `getIt<T>()` call. Useful for expensive objects.

**`registerFactory<T>(() => instance)`**: Creates a new instance every time `getIt<T>()` is called. Useful for BLoCs, Cubits, or any object that should not be shared.

**`registerFactoryAsync<T>(() async => instance)`**: Like factory, but the creation function is async. Must be retrieved with `getIt.getAsync<T>()`.

**`registerSingletonAsync<T>(() async => instance)`**: Async singleton creation. Supports `dependsOn` parameter to declare initialization order.

```dart
// Async initialization with dependency ordering
getIt.registerSingletonAsync<Database>(
  () async => Database.open('app.db'),
);
getIt.registerSingletonAsync<UserRepository>(
  () async => UserRepository(db: getIt<Database>()),
  dependsOn: [Database], // waits for Database to be ready
);

// Wait for all async singletons to complete
await getIt.allReady();
```

### Scopes in get_it

get_it supports a scope stack, allowing you to push and pop scopes with different registrations:

```dart
// Push a new scope (e.g., when user logs in)
getIt.pushNewScope(
  scopeName: 'authenticated',
  init: (scope) {
    scope.registerSingleton<UserSession>(UserSession(token: token));
    scope.registerLazySingleton<UserRepository>(
      () => UserRepository(session: getIt<UserSession>()),
    );
  },
);

// Pop scope (e.g., when user logs out)
getIt.popScope(); // UserSession and UserRepository are disposed

// Or pop to a named scope
getIt.popScopesTill('authenticated');

// Drop a specific scope without popping above it
getIt.dropScope('authenticated');
```

When resolving a dependency, get_it searches from the topmost scope downward, returning the first match. This allows scopes to shadow registrations from parent scopes.

### injectable Package for Code-Gen Registration

The `injectable` package (inspired by Angular DI and Dagger/Hilt) generates get_it registration code from annotations:

```dart
// Annotate your classes
@singleton
class HttpClient {
  HttpClient(@Named('baseUrl') this.baseUrl);
  final String baseUrl;
}

@lazySingleton
class AuthRepository {
  AuthRepository(this.httpClient);
  final HttpClient httpClient;
}

@injectable
class AuthBloc {
  AuthBloc(this.authRepository);
  final AuthRepository authRepository;
}

// In your setup file
@InjectableInit()
void configureDependencies() => getIt.init();
```

injectable also supports:
- **`@Environment('dev')` / `@Environment('prod')`**: Register different implementations per environment.
- **`@module`**: Register third-party classes you cannot annotate.
- **`@preResolve`**: For async singletons that should be resolved before app start.
- **`@Order(n)`**: Control initialization order.

### get_it + BLoC Combination

This is one of the most common patterns in production Flutter apps. get_it handles dependency registration (repositories, services, API clients), while BLoC's `BlocProvider` handles providing BLoCs to the widget tree:

```dart
// setup.dart
void setupDependencies() {
  getIt.registerLazySingleton<HttpClient>(() => HttpClient());
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(httpClient: getIt<HttpClient>()),
  );
  // Register the BLoC as a factory (new instance each time)
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );
}

// In the widget tree
BlocProvider(
  create: (_) => getIt<AuthBloc>(),
  child: LoginPage(),
)
```

This combination is popular because:
- Repositories and services live outside the widget tree (managed by get_it).
- BLoCs are still scoped to the widget tree (managed by `BlocProvider`).
- You avoid deep `MultiRepositoryProvider` nesting.
- get_it handles async initialization (databases, shared preferences) cleanly.

### get_it + Riverpod Combination

This combination is generally **not recommended**. As the Riverpod documentation itself states, Riverpod providers are "a complete replacement for patterns like Service Locators, Dependency Injection, [and] InheritedWidgets."

If you are using Riverpod, its provider system already handles:
- Lazy instantiation (equivalent to `registerLazySingleton`)
- Factory creation (just create a new instance in the provider body)
- Scoping (via `ProviderScope` overrides)
- Async initialization (`FutureProvider` / `AsyncNotifier`)

Adding get_it on top creates two parallel DI systems that are unaware of each other, making dependency graphs harder to reason about and test. The one edge case where it might make sense is if you have a large amount of existing get_it infrastructure and are gradually migrating to Riverpod.

### get_it vs Riverpod DI -- When Would You Choose get_it?

Choose **get_it** when:
- You want DI completely independent of the widget tree.
- You are using BLoC (or another state management solution) and want a dedicated DI solution.
- You need to access dependencies in non-widget code (background services, isolates, platform channels).
- You prefer a simple, zero-magic API with no code generation required (though injectable adds it optionally).
- You want the fastest possible resolution (it is a Map lookup).

Choose **Riverpod** when:
- You want DI and state management in one unified system.
- You value compile-time safety and automatic dependency tracking.
- You want reactive dependency chains (provider A rebuilds when provider B changes).
- You need auto-dispose and lifecycle management.
- You are starting a new project and can commit to the Riverpod ecosystem.

### Pros and Cons for Solo Dev

**Pros of get_it**:
- Dead simple API -- learn in 15 minutes.
- No BuildContext gymnastics.
- Works with any state management solution.
- No code generation needed (injectable is optional).
- Extremely fast and lightweight.

**Cons of get_it**:
- No compile-time safety -- typos in type registration are runtime errors.
- Service locator pattern makes dependencies implicit (harder to see what a class depends on by looking at its call site).
- No reactive dependency tracking.
- Manual lifecycle management (you must remember to dispose).
- Can become a "god object" if not structured carefully.

---

## 6. Other DI Solutions

### injectable

**What it is**: A code generation companion for get_it. Not a standalone DI solution -- it generates the `getIt.registerXxx()` calls from annotations.

**Key features**:
- Annotation-based: `@singleton`, `@lazySingleton`, `@injectable`, `@module`.
- Environment support: Different registrations for dev/prod/test.
- Automatic dependency resolution: Inspects constructor parameters and wires them up.
- Supports async singletons with `@preResolve`.

**Best for**: Teams or projects already using get_it that want to reduce manual registration boilerplate. Inspired by Dagger/Hilt from the Android ecosystem.

**Trade-offs**: Adds `build_runner` dependency. The generated code can be hard to debug. Annotations add visual noise to domain classes.

### kiwi

**What it is**: A simple compile-time dependency injection container for Dart and Flutter, paired with `kiwi_generator`.

```dart
part 'injector.g.dart';

abstract class Injector {
  @Register.singleton(HttpClient)
  @Register.factory(AuthRepository)
  @Register.factory(AuthBloc)
  void configure();
}
```

**Key features**:
- Uses code generation (no reflection).
- Internally just a `Map`, similar to get_it.
- Supports singleton and factory registrations.
- Very lightweight.

**Best for**: Developers who want something even simpler than get_it with basic code-gen support.

**Trade-offs**: Much smaller community than get_it. Less actively maintained. Fewer features (no scopes, no async initialization). Limited documentation.

### auto_injector

**What it is**: A lightweight automatic dependency injector for Dart, created by the Flutterando community.

**Key features**:
- Auto-resolution of constructor dependencies.
- Supports singleton, lazySingleton, and factory.
- No code generation required.
- Simple API similar to get_it.

**Best for**: Developers who want automatic constructor resolution without code generation.

**Trade-offs**: Smaller community. Fewer advanced features compared to get_it or Riverpod.

### Other Notable Packages

- **`watch_it`**: A companion to get_it that adds reactive watching of get_it-registered objects from the widget tree. Bridges the gap between get_it's global access and Provider's reactive updates.
- **`flutter_getit`**: A Flutter-specific wrapper around get_it that adds widget-tree integration with `FlutterGetItWidget`.
- **`scope`**: A lightweight scoping solution for dependency injection with explicit scope management.
- **`inject.dart`**: Google's compile-time DI framework for Dart. Uses code generation. Largely dormant/experimental.

### Brief Comparison

| Package | Code Gen | Scopes | Async | Community Size | Active Maintenance |
|---------|----------|--------|-------|----------------|-------------------|
| get_it | No (optional with injectable) | Yes | Yes | Very large | Very active |
| injectable | Yes (for get_it) | Via get_it | Yes | Large | Active |
| kiwi | Yes | No | No | Small | Low activity |
| auto_injector | No | Limited | Limited | Small | Moderate |
| watch_it | No | Via get_it | Via get_it | Growing | Active |

---

## 7. Head-to-Head Comparison

### BLoC DI vs Riverpod DI vs get_it

| Dimension | BLoC DI | Riverpod DI | get_it |
|-----------|---------|-------------|--------|
| **Ease of setup** | Medium -- need to understand BlocProvider/RepositoryProvider hierarchy | Medium -- need ProviderScope and provider declarations | Easy -- call register methods in a setup function |
| **Boilerplate** | High -- MultiRepositoryProvider + MultiBlocProvider nesting | Low-Medium with code gen, Medium without | Low -- just registration calls |
| **Scoping flexibility** | Widget-tree scoped; feature/page/app levels | Widget-tree scoped + ProviderScope overrides for subtrees | Global + push/pop scope stack |
| **Testability** | Good -- provide mock BLoCs via BlocProvider.value | Excellent -- ProviderContainer/ProviderScope overrides | Good -- reset and re-register in setUp |
| **Compile-time safety** | None -- runtime ProviderNotFoundException | Good -- provider references are typed variables | None -- runtime errors for missing registrations |
| **Learning curve** | Medium -- DI concepts are straightforward but BLoC itself is complex | Steeper -- ref.watch/read/listen, provider types, code gen | Low -- very simple API |
| **Async dependency handling** | Manual -- must init before providing, or use FutureBuilder | Built-in -- FutureProvider, AsyncNotifier | Built-in -- registerSingletonAsync, allReady() |
| **Circular dependency detection** | None | Detected at runtime (throws) | None built-in |
| **IDE support & refactoring** | Good -- standard widget refactoring | Good with code gen (generated types help); without code gen, refactoring provider declarations is manual | Good -- standard Dart refactoring |
| **Integration with routing** | Pain point -- BlocProvider.value needed across routes, or provide above Navigator | Smooth -- providers are global declarations, no route boundary issues | Smooth -- global access, no route concerns |
| **Community adoption** | Very large (BLoC is the most-used state mgmt) | Large and growing rapidly (Riverpod is #2) | Large (most popular pure DI package) |

### Summary by Scenario

- **"I just need to wire up some services"**: get_it
- **"I want DI and state management unified"**: Riverpod
- **"I want strict separation of concerns and event-driven architecture"**: BLoC (+ get_it or RepositoryProvider for non-BLoC deps)
- **"I want maximum testability with minimum setup"**: Riverpod
- **"I want the simplest possible approach"**: get_it
- **"I need to access deps outside the widget tree"**: get_it (or Riverpod with ProviderContainer in non-widget code)

---

## 8. Common Patterns Across All Approaches

Regardless of which DI package you choose, these patterns and architectural principles apply universally.

### Repository Pattern

The repository pattern abstracts data sources behind a clean interface. Every DI approach benefits from it:

```dart
// Abstract interface
abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<void> logout();
  Stream<User?> get authStateChanges;
}

// Concrete implementation
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirestoreService _firestore;

  FirebaseAuthRepository(this._auth, this._firestore);

  @override
  Future<User> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email, password: password,
    );
    return _firestore.getUser(credential.user!.uid);
  }
  // ...
}

// Test implementation
class FakeAuthRepository implements AuthRepository {
  @override
  Future<User> login(String email, String password) async => testUser;
  // ...
}
```

The value: your BLoC/Notifier/Controller depends on `AuthRepository` (the interface), not `FirebaseAuthRepository` (the implementation). Swapping implementations via DI is trivial.

### Service Layer Abstraction

Beyond repositories (which handle data), services encapsulate cross-cutting concerns:

```dart
abstract class AnalyticsService {
  void trackEvent(String name, Map<String, dynamic> params);
  void setUserId(String userId);
}

abstract class CrashReportingService {
  void recordError(Object error, StackTrace stackTrace);
}

abstract class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
```

These services are registered via your DI system of choice and injected into repositories, BLoCs, or notifiers as needed.

### Environment-Based Configuration

All DI approaches support environment-specific implementations:

```dart
// With get_it + injectable
@Environment('prod')
@LazySingleton(as: HttpClient)
class ProdHttpClient implements HttpClient { /* real API */ }

@Environment('dev')
@LazySingleton(as: HttpClient)
class DevHttpClient implements HttpClient { /* mock/staging API */ }

// With Riverpod
final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(baseUrl: const String.fromEnvironment('API_URL'));
});

// Override in tests
ProviderScope(
  overrides: [httpClientProvider.overrideWithValue(MockHttpClient())],
  child: MyApp(),
)

// With BLoC + manual setup
void setupDependencies(AppEnvironment env) {
  switch (env) {
    case AppEnvironment.prod:
      getIt.registerSingleton<HttpClient>(ProdHttpClient());
    case AppEnvironment.dev:
      getIt.registerSingleton<HttpClient>(DevHttpClient());
  }
}
```

### Feature-Based Module Registration

For larger apps, organize DI registrations by feature rather than by layer:

```dart
// feature_auth/di.dart
void registerAuthDependencies() {
  getIt.registerLazySingleton<AuthRepository>(() => FirebaseAuthRepository(getIt()));
  getIt.registerFactory<AuthBloc>(() => AuthBloc(getIt()));
}

// feature_cart/di.dart
void registerCartDependencies() {
  getIt.registerLazySingleton<CartRepository>(() => CartRepository(getIt()));
  getIt.registerFactory<CartBloc>(() => CartBloc(getIt()));
}

// main.dart
void setupDependencies() {
  registerCoreDependencies(); // HttpClient, analytics, etc.
  registerAuthDependencies();
  registerCartDependencies();
}
```

This pattern works with get_it and injectable. With Riverpod, the equivalent is simply organizing provider declarations into feature-specific files -- no central registration needed since providers are globally declared.

---

## 9. Recommendations for Solo Dev / Freelance

### Which DI Approach for Different Project Types

**Small app (< 10 screens, simple data flow)**:
- Use `Provider` or plain constructor injection. You likely do not need a DI framework at all. Define your repositories as class instances and pass them through constructors or a single `MultiProvider` at the root.

**Medium app (10-30 screens, multiple data sources, auth)**:
- If using BLoC for state management: `get_it` for repository/service registration + `BlocProvider` for BLoCs. This is the most common production pattern.
- If using Riverpod: Riverpod handles both DI and state management -- no additional package needed.

**Large/complex app (30+ screens, offline sync, multi-module)**:
- `get_it` + `injectable` for type-safe, code-generated DI with environment support.
- Or Riverpod with `riverpod_generator` for unified DI + state management with code gen.

**Package/library development**:
- Avoid DI frameworks entirely. Accept dependencies via constructor parameters. Let the consuming app decide how to provide them.

**Prototype / MVP / hackathon**:
- Use `get_it` with manual registration. It takes 5 minutes to set up, requires no code generation, and you can always add more structure later.

### Is Mixing Approaches Ever a Good Idea?

**get_it + BLoC**: Yes, this is a well-established, intentional combination. They handle different concerns (DI vs state management) and complement each other.

**Riverpod + get_it**: Generally no. Riverpod already provides DI. Adding get_it creates two parallel systems. The exception is during a gradual migration from get_it to Riverpod.

**BLoC + Riverpod**: No. These are competing state management solutions. Pick one.

**Provider + get_it**: Acceptable but becoming outdated. Provider for widget-tree DI, get_it for non-widget DI. Consider migrating to Riverpod or BLoC + get_it instead.

### The "Just Enough DI" Philosophy

For freelance projects, over-engineering DI is a real risk. Here is the minimum viable DI:

1. **Define repository interfaces** for any external data source (API, database, local storage). This costs almost nothing and makes testing possible.

2. **Use constructor injection** for all dependencies. Classes should declare what they need in their constructor.

3. **Pick one registration mechanism** -- get_it, Riverpod, or RepositoryProvider -- and use it consistently.

4. **Do not create interfaces for everything**. Only abstract things you actually need to swap (data sources, platform services). An `AuthBloc` does not need an `IAuthBloc` interface.

5. **Avoid deep abstraction layers** unless the project will grow. For a freelance app, `AuthRepository` depending directly on `FirebaseAuth` is fine. You do not need `AuthDataSource`, `AuthRemoteDataSource`, `AuthLocalDataSource`, and `AuthRepository` for a 15-screen app.

### Common Mistakes to Avoid

1. **Registering everything as a singleton**: BLoCs and Cubits should almost always be factories (new instance per use). Singletons are for shared services (HTTP client, database, analytics).

2. **Ignoring disposal**: Forgetting to close streams, database connections, or subscriptions. Use `BlocProvider` (auto-closes), Riverpod auto-dispose, or get_it's `dispose` callbacks.

3. **Service locator abuse**: If every class calls `getIt<Something>()` internally, dependencies become invisible. Prefer constructor injection even when using get_it -- let the registration site do the `getIt` lookups, and pass results into constructors.

4. **Circular dependencies**: A depends on B, B depends on A. This usually indicates a design problem. Extract the shared logic into a third dependency C.

5. **Async initialization spaghetti**: If you have many async singletons (database, shared prefs, firebase), initialize them in `main()` before `runApp()` rather than scattering `FutureProvider`/`FutureBuilder` throughout the tree.

6. **Over-abstracting for testability you never use**: Writing 5 interfaces and 3 layers "for testing" but never writing tests. Be pragmatic -- add abstractions when you actually need to swap implementations.

---

## 10. Code Examples

The following examples show equivalent DI setups for a common scenario:

> An `AuthRepository` that depends on an `HttpClient` and a `SecureStorageService`, consumed by an `AuthBloc` (or `AuthNotifier` for Riverpod).

### Shared Interfaces and Models

```dart
// models/user.dart
class User {
  final String id;
  final String email;
  final String name;
  User({required this.id, required this.email, required this.name});
}

// services/http_client.dart
abstract class HttpClient {
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers});
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers});
}

class DioHttpClient implements HttpClient {
  final String baseUrl;
  DioHttpClient({required this.baseUrl});

  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) async {
    // Dio implementation
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    throw UnimplementedError();
  }
}

// services/secure_storage_service.dart
abstract class SecureStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageService implements SecureStorageService {
  @override
  Future<String?> read(String key) async => /* flutter_secure_storage impl */ null;
  @override
  Future<void> write(String key, String value) async { /* ... */ }
  @override
  Future<void> delete(String key) async { /* ... */ }
}

// repositories/auth_repository.dart
abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
}

class AuthRepositoryImpl implements AuthRepository {
  final HttpClient httpClient;
  final SecureStorageService secureStorage;

  AuthRepositoryImpl({required this.httpClient, required this.secureStorage});

  @override
  Future<User> login(String email, String password) async {
    final response = await httpClient.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    final token = response['token'] as String;
    await secureStorage.write('auth_token', token);
    return User(
      id: response['user']['id'],
      email: response['user']['email'],
      name: response['user']['name'],
    );
  }

  @override
  Future<void> logout() async {
    await secureStorage.delete('auth_token');
  }

  @override
  Future<User?> getCurrentUser() async {
    final token = await secureStorage.read('auth_token');
    if (token == null) return null;
    final response = await httpClient.get('/auth/me', headers: {
      'Authorization': 'Bearer $token',
    });
    return User(
      id: response['id'],
      email: response['email'],
      name: response['name'],
    );
  }
}
```

---

### BLoC + get_it Approach

```dart
// === auth_bloc.dart ===
// Events
sealed class AuthEvent {}
class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested({required this.email, required this.password});
}
class AuthLogoutRequested extends AuthEvent {}
class AuthCheckRequested extends AuthEvent {}

// States
sealed class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final User user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onCheckRequested);
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.login(event.email, event.password);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onCheckRequested(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final user = await _authRepository.getCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }
}

// === injection.dart (get_it setup) ===
final getIt = GetIt.instance;

void configureDependencies() {
  // Services
  getIt.registerLazySingleton<HttpClient>(
    () => DioHttpClient(baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'https://api.example.com')),
  );
  getIt.registerLazySingleton<SecureStorageService>(
    () => FlutterSecureStorageService(),
  );

  // Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      httpClient: getIt<HttpClient>(),
      secureStorage: getIt<SecureStorageService>(),
    ),
  );

  // BLoCs (factory = new instance each time)
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: getIt<AuthRepository>()),
  );
}

// === main.dart ===
void main() {
  configureDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthBloc>()..add(AuthCheckRequested()),
      child: MaterialApp(home: AuthGate()),
    );
  }
}

// === auth_gate.dart ===
class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthAuthenticated(user: final user) => HomePage(user: user),
          AuthUnauthenticated() => LoginPage(),
          AuthLoading() => const Scaffold(body: Center(child: CircularProgressIndicator())),
          AuthError(message: final msg) => LoginPage(errorMessage: msg),
          AuthInitial() => const Scaffold(body: Center(child: CircularProgressIndicator())),
        };
      },
    );
  }
}

// === Testing ===
// test/auth_bloc_test.dart
void main() {
  late MockAuthRepository mockAuthRepo;
  late AuthBloc authBloc;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
    authBloc = AuthBloc(authRepository: mockAuthRepo);
  });

  tearDown(() => authBloc.close());

  blocTest<AuthBloc, AuthState>(
    'emits [AuthLoading, AuthAuthenticated] on successful login',
    build: () {
      when(() => mockAuthRepo.login(any(), any()))
          .thenAnswer((_) async => User(id: '1', email: 'a@b.com', name: 'Test'));
      return authBloc;
    },
    act: (bloc) => bloc.add(AuthLoginRequested(email: 'a@b.com', password: 'pass')),
    expect: () => [
      isA<AuthLoading>(),
      isA<AuthAuthenticated>(),
    ],
  );
}
```

---

### Riverpod Approach

```dart
// === providers.dart (with riverpod_generator) ===

// Services
@riverpod
HttpClient httpClient(Ref ref) {
  return DioHttpClient(
    baseUrl: const String.fromEnvironment('API_URL', defaultValue: 'https://api.example.com'),
  );
}

@riverpod
SecureStorageService secureStorageService(Ref ref) {
  return FlutterSecureStorageService();
}

// Repository
@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    httpClient: ref.watch(httpClientProvider),
    secureStorage: ref.watch(secureStorageServiceProvider),
  );
}

// === auth_notifier.dart ===
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<User?> build() async {
    // Check for existing session on initialization
    final repo = ref.watch(authRepositoryProvider);
    return repo.getCurrentUser();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(authRepositoryProvider);
      return repo.login(email, password);
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
  }
}

// === main.dart ===
void main() {
  runApp(
    const ProviderScope(child: MyApp()),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(home: AuthGate());
  }
}

// === auth_gate.dart ===
class AuthGate extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return authState.when(
      data: (user) {
        if (user != null) return HomePage(user: user);
        return LoginPage();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => LoginPage(errorMessage: error.toString()),
    );
  }
}

// === login_page.dart (showing ref.read for actions) ===
class LoginPage extends ConsumerWidget {
  final String? errorMessage;
  const LoginPage({this.errorMessage, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for errors to show snackbar
    ref.listen(authNotifierProvider, (prev, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      }
    });

    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            ref.read(authNotifierProvider.notifier).login('user@test.com', 'password');
          },
          child: const Text('Login'),
        ),
      ),
    );
  }
}

// === Testing ===
// test/auth_notifier_test.dart
void main() {
  test('login updates state to authenticated', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    // Initial state -- checks getCurrentUser
    await container.read(authNotifierProvider.future);

    // Perform login
    await container.read(authNotifierProvider.notifier).login('a@b.com', 'pass');

    final state = container.read(authNotifierProvider);
    expect(state.value, isNotNull);
    expect(state.value!.email, 'a@b.com');
  });
}

// Widget test
testWidgets('AuthGate shows login when unauthenticated', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(currentUser: null),
        ),
      ],
      child: const MaterialApp(home: AuthGate()),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.byType(LoginPage), findsOneWidget);
});
```

---

### get_it Standalone Approach (Without BLoC or Riverpod)

```dart
// For completeness: using get_it as both DI and basic state management
// (only suitable for simple apps or non-Flutter Dart code)

// === injection.dart ===
final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Services
  getIt.registerLazySingleton<HttpClient>(
    () => DioHttpClient(baseUrl: 'https://api.example.com'),
  );
  getIt.registerLazySingleton<SecureStorageService>(
    () => FlutterSecureStorageService(),
  );

  // Repository
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      httpClient: getIt<HttpClient>(),
      secureStorage: getIt<SecureStorageService>(),
    ),
  );
}

// === main.dart ===
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const MyApp());
}

// Usage anywhere -- no context needed
class SomeService {
  final authRepo = GetIt.I<AuthRepository>();

  Future<void> doSomething() async {
    final user = await authRepo.getCurrentUser();
    // ...
  }
}

// === Testing ===
void main() {
  setUp(() {
    // Reset and re-register with mocks
    GetIt.I.reset();
    GetIt.I.registerSingleton<HttpClient>(MockHttpClient());
    GetIt.I.registerSingleton<SecureStorageService>(MockSecureStorage());
    GetIt.I.registerSingleton<AuthRepository>(FakeAuthRepository());
  });

  test('can resolve auth repository', () {
    final repo = GetIt.I<AuthRepository>();
    expect(repo, isA<FakeAuthRepository>());
  });
}
```

---

### Side-by-Side Registration Comparison

```
┌─────────────────────┬─────────────────────────────────────────────────────┐
│ Registration Type   │ Equivalent Across Approaches                       │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Singleton           │ get_it:    registerSingleton<T>(instance)          │
│                     │ Riverpod:  @riverpod + keepAlive (or Provider)     │
│                     │ BLoC:      RepositoryProvider(create: (_) => ...)  │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Lazy Singleton      │ get_it:    registerLazySingleton<T>(() => ...)     │
│                     │ Riverpod:  @riverpod (default is lazy)             │
│                     │ BLoC:      RepositoryProvider (default is lazy)    │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Factory             │ get_it:    registerFactory<T>(() => ...)           │
│                     │ Riverpod:  @riverpod with autoDispose (default)    │
│                     │ BLoC:      BlocProvider(create: (_) => ...)        │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Async               │ get_it:    registerSingletonAsync + allReady()     │
│                     │ Riverpod:  FutureProvider / AsyncNotifier          │
│                     │ BLoC:      Manual init in main() before runApp()   │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Scoped              │ get_it:    pushNewScope() / popScope()             │
│                     │ Riverpod:  Nested ProviderScope(overrides: [...])  │
│                     │ BLoC:      Nested BlocProvider at subtree level    │
├─────────────────────┼─────────────────────────────────────────────────────┤
│ Test Override       │ get_it:    reset() + re-register                   │
│                     │ Riverpod:  ProviderContainer(overrides: [...])     │
│                     │ BLoC:      BlocProvider.value(value: mockBloc)     │
└─────────────────────┴─────────────────────────────────────────────────────┘
```

---

## Sources

- [Flutter BLoC Concepts -- Official Documentation](https://bloclibrary.dev/flutter-bloc-concepts/)
- [RepositoryProvider Class -- flutter_bloc API](https://pub.dev/documentation/flutter_bloc/latest/flutter_bloc/RepositoryProvider-class.html)
- [Riverpod Official Documentation](https://riverpod.dev/)
- [What's New in Riverpod 3.0](https://riverpod.dev/docs/whats_new)
- [Riverpod Provider Overrides](https://riverpod.dev/docs/concepts2/overrides)
- [Riverpod Scoping Providers](https://riverpod.dev/docs/concepts2/scoping)
- [Riverpod Refs (ref.watch, ref.read, ref.listen)](https://riverpod.dev/docs/concepts2/refs)
- [Riverpod Family Providers](https://riverpod.dev/docs/concepts2/family)
- [riverpod_generator Package](https://pub.dev/packages/riverpod_generator)
- [Flutter Riverpod 2.0: The Ultimate Guide -- Code with Andrea](https://codewithandrea.com/articles/flutter-state-management-riverpod/)
- [get_it Package](https://pub.dev/packages/get_it)
- [get_it Scopes Documentation](https://flutter-it.dev/documentation/get_it/scopes)
- [get_it Advanced Features](https://flutter-it.dev/documentation/get_it/advanced)
- [injectable Package](https://pub.dev/packages/injectable)
- [kiwi Package](https://pub.dev/packages/kiwi)
- [Approaches to Dependency Injection in Flutter -- DEV Community](https://dev.to/ptrbrynt/approaches-to-dependency-injection-in-flutter-4311)
- [Dependency Injection in Flutter with Provider, GetIt, and Riverpod -- Relia Software](https://reliasoftware.com/blog/dependency-injection-in-flutter)
- [Flutter State Management Guide 2026 -- Foresight Mobile](https://foresightmobile.com/blog/best-flutter-state-management)
- [A Deep Dive into Riverpod vs BLoC -- Appunite](https://tech.appunite.com/posts/a-deep-dive-into-riverpod-vs-bloc)
- [Can Riverpod Do What get_it Can Do? -- Rex Cole](https://rexcoding.medium.com/can-riverpod-do-what-get-it-can-do-6e6bc3927d63)
- [Flutter Communicating Between Layers -- Official Docs](https://docs.flutter.dev/app-architecture/case-study/dependency-injection)
