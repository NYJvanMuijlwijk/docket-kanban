import 'package:go_router/go_router.dart';
import 'package:kanban_board/features/board/presentation/board_detail_screen.dart';
import 'package:kanban_board/features/board/presentation/board_list_screen.dart';

GoRouter createRouter() => GoRouter(
      initialLocation: '/',
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
