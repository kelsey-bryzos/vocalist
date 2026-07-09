import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/sign_in_screen.dart';
import '../../features/auth/screens/sign_up_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/notes/screens/note_detail_screen.dart';
import '../../features/notes/screens/notes_list_screen.dart';
import '../../features/projects/screens/project_detail_screen.dart';
import '../../features/projects/screens/projects_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../widgets/app_shell.dart';

const kRouteHome = '/';
const kRouteSearch = '/search';
const kRouteSignIn = '/sign-in';
const kRouteSignUp = '/sign-up';
const kRouteForgotPassword = '/forgot-password';
const kRouteNotes = '/notes';
const kRouteNoteDetail = '/notes/:id';
const kRouteTasks = '/tasks';
const kRouteProjects = '/projects';
const kRouteProjectDetail = '/projects/:id';

/// Fade + slight-scale page transition used for all main routes.
CustomTransitionPage<T> _fadePage<T>(BuildContext context, GoRouterState state,
    Widget child) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: kRouteHome,
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isAuthenticated = authState.valueOrNull?.session != null;
      final loc = state.matchedLocation;
      final isOnAuthRoute = loc == kRouteSignIn ||
          loc == kRouteSignUp ||
          loc == kRouteForgotPassword;

      if (!isAuthenticated && !isOnAuthRoute) return kRouteSignIn;
      if (isAuthenticated && isOnAuthRoute) return kRouteHome;
      return null;
    },
    routes: [
      // ── Auth routes (no shell) ──────────────────────────────────────────
      GoRoute(
        path: kRouteSignIn,
        pageBuilder: (c, s) => _fadePage(c, s, const SignInScreen()),
      ),
      GoRoute(
        path: kRouteSignUp,
        pageBuilder: (c, s) => _fadePage(c, s, const SignUpScreen()),
      ),
      GoRoute(
        path: kRouteForgotPassword,
        pageBuilder: (c, s) => _fadePage(c, s, const ForgotPasswordScreen()),
      ),

      // ── Main app shell ──────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: kRouteHome,
            pageBuilder: (c, s) => _fadePage(c, s, const HomeScreen()),
          ),
          GoRoute(
            path: kRouteNotes,
            pageBuilder: (c, s) => _fadePage(
              c,
              s,
              NotesListScreen(
                projectId: s.uri.queryParameters['projectId'],
              ),
            ),
          ),
          GoRoute(
            path: kRouteTasks,
            pageBuilder: (c, s) => _fadePage(
              c,
              s,
              TasksScreen(
                projectId: s.uri.queryParameters['projectId'],
              ),
            ),
          ),
          GoRoute(
            path: kRouteProjects,
            pageBuilder: (c, s) => _fadePage(c, s, const ProjectsScreen()),
          ),
        ],
      ),

      // ── Detail / overlay routes (no bottom nav — full screen) ───────────
      GoRoute(
        path: kRouteNoteDetail,
        pageBuilder: (c, s) => _fadePage(
          c,
          s,
          NoteDetailScreen(noteId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: kRouteProjectDetail,
        pageBuilder: (c, s) => _fadePage(
          c,
          s,
          ProjectDetailScreen(projectId: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: kRouteSearch,
        pageBuilder: (c, s) => _fadePage(c, s, const SearchScreen()),
      ),
    ],
  );
});
