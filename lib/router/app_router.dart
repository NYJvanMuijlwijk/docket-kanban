import 'package:go_router/go_router.dart';
import 'package:kanban_board/features/board/presentation/board_detail_screen.dart';
import 'package:kanban_board/features/board/presentation/board_list_screen.dart';
import 'package:kanban_board/router/error_screen.dart';

GoRouter createRouter({String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
      errorBuilder: (context, state) => ErrorScreen(state: state),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const BoardListScreen(),
        ),
        GoRoute(
          path: '/board/:id',
          builder: (context, state) => BoardDetailScreen(
            boardId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
