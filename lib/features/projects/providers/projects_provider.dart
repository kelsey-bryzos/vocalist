import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project.dart';
import '../repositories/projects_repository.dart';

final projectsRepositoryProvider = Provider((_) => ProjectsRepository());

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<Project>>(
        ProjectsNotifier.new);

class ProjectsNotifier extends AsyncNotifier<List<Project>> {
  ProjectsRepository get _repo => ref.read(projectsRepositoryProvider);

  @override
  Future<List<Project>> build() => _repo.fetchAll();

  Future<void> create(String name) async {
    final project = await _repo.create(name);
    state = AsyncData([...state.value ?? [], project]);
  }

  Future<void> rename(String id, String name) async {
    final updated = await _repo.rename(id, name);
    state = AsyncData(
      (state.value ?? []).map((p) => p.id == id ? updated : p).toList(),
    );
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData(
      (state.value ?? []).where((p) => p.id != id).toList(),
    );
  }
}
