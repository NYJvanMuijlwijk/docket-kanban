# Requirements
- State management solution for a small-scope collaborative kanban board app built by a solo developer.
- Must integrate well with Firebase/Firestore's real-time streams.
- Should keep boilerplate low to maintain development velocity on a small project.
- Needs solid async support for handling Firestore queries, authentication, and real-time listeners.

# Options considered
- BLoC (flutter_bloc)
- Riverpod

## BLoC
- Industry-proven, event-driven architecture with strict separation of concerns.
- Excellent testability via the `bloc_test` package.
- Strong enterprise track record and Flutter Favorite status.

cons
- High boilerplate — each feature requires event classes, state classes, and the Bloc itself.
- Steep learning curve with streams, sealed state classes, and the BLoC widget ecosystem.
- Overkill for a small project with a solo developer.

## Riverpod
- Compile-time safety catches provider errors before runtime.
- Context-independent — providers work outside the widget tree, simplifying testing and service-layer code.
- Low boilerplate with code generation (`@riverpod` annotation).
- Excellent async support via `AsyncNotifier`, `FutureProvider`, and `StreamProvider`, mapping naturally to Firestore streams.
- Built-in auto-dispose and lifecycle management reduces risk of memory leaks.
- Most downloaded state management package on pub.dev, with comprehensive documentation.

cons
- Code generation adds a build step.
- Smaller enterprise track record compared to BLoC (though growing).

# Decision
Riverpod is selected as the state management solution for this project for two reasons:

1. **Better fit for project scope.** As a solo-developed MVP targeting small teams with under 100 tasks, the project does not benefit from BLoC's enterprise-oriented ceremony. Riverpod provides the same level of testability and scalability with significantly less boilerplate, allowing faster iteration. Its `StreamProvider` maps directly to Firestore's real-time snapshots, keeping the data layer clean.

2. **Developer learning goals.** Building this project with Riverpod serves as a hands-on opportunity to deepen practical knowledge of the framework, which is an explicit goal alongside delivering the product.

Riverpod 3.0 with code generation will be used throughout the project.
