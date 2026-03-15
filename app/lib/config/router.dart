import 'package:app/features/auth/auth_notifier.dart';
import 'package:app/features/auth/screens/login_screen.dart';
import 'package:app/features/boards/screens/board_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

/// Defines the application's routes and their corresponding screens.
abstract class AppRoutes {
  /// The home route, which displays the list of boards.
  static const String home = '/';

  /// The login route, which displays the login screen.
  static const String login = '/login';
}

/// The main router for the application, defining all routes
/// and their corresponding screens.
final appRouter = GoRouter(
  refreshListenable: AuthNotifier(),
  redirect: (context, state) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    if (!signedIn) {
      return AppRoutes.login;
    } else if (state.matchedLocation == AppRoutes.login) {
      return AppRoutes.home;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const BoardListScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
  ],
);
