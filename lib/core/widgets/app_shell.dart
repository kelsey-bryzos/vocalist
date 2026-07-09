import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/router.dart';

/// Persistent shell with bottom navigation + floating mic FAB.
/// Wraps all main destinations: Home, Notes, Tasks, Projects.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    _Destination(kRouteHome, Icons.home_rounded, Icons.home_outlined, 'Home'),
    _Destination(kRouteNotes, Icons.notes_rounded, Icons.notes_outlined, 'Notes'),
    _Destination(
        kRouteTasks, Icons.checklist_rounded, Icons.checklist_outlined, 'Tasks'),
    _Destination(kRouteProjects, Icons.folder_rounded, Icons.folder_outlined,
        'Projects'),
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          if (i != selected) {
            context.go(_destinations[i].route);
          }
        },
        destinations: _destinations
            .map((d) => NavigationDestination(
                  icon: Icon(d.inactiveIcon),
                  selectedIcon: Icon(d.activeIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.route, this.activeIcon, this.inactiveIcon, this.label);

  final String route;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
}
