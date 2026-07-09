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
      GoRoute(
        path: kRouteHome,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: kRouteSignIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: kRouteSignUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: kRouteForgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: kRouteNotes,
        builder: (context, state) => NotesListScreen(
          projectId: state.uri.queryParameters['projectId'],
        ),
      ),
      GoRoute(
        path: kRouteNoteDetail,
        builder: (context, state) =>
            NoteDetailScreen(noteId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: kRouteTasks,
        builder: (context, state) => TasksScreen(
          projectId: state.uri.queryParameters['projectId'],
        ),
      ),
      GoRoute(
        path: kRouteProjects,
        builder: (context, state) => const ProjectsScreen(),
      ),
      GoRoute(
        path: kRouteProjectDetail,
        builder: (context, state) => ProjectDetailScreen(
          projectId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: kRouteSearch,
        builder: (context, state) => const SearchScreen(),
      ),
    ],
  );
});
