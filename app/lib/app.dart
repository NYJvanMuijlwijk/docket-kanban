import 'package:app/config/router.dart';
import 'package:app/config/theme.dart';
import 'package:flutter/material.dart';

/// A collaborative Kanban board application.
///
/// A material design application that allows users to create and manage their
/// own Kanban boards, with real-time collaboration features.
class KanbanApp extends StatelessWidget {
  /// Creates a new instance of [KanbanApp].
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Collaborative Kanban Board',
      theme: lightTheme,
      darkTheme: darkTheme,
      routerConfig: appRouter,
    );
  }
}
