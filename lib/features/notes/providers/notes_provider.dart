import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/note.dart';
import '../repositories/notes_repository.dart';

final notesRepositoryProvider = Provider((_) => NotesRepository());

// Family: one notifier per project (null = all notes)
final notesProvider =
    AsyncNotifierProviderFamily<NotesNotifier, List<Note>, String?>(
        NotesNotifier.new);

class NotesNotifier extends FamilyAsyncNotifier<List<Note>, String?> {
  NotesRepository get _repo => ref.read(notesRepositoryProvider);

  @override
  Future<List<Note>> build(String? arg) => _repo.fetchAll(projectId: arg);

  Future<void> saveNote(
    String id, {
    String? title,
    String? summary,
    List<NoteSection>? sections,
    String? projectId,
  }) async {
    final updated = await _repo.update(
      id,
      title: title,
      summary: summary,
      sections: sections,
      projectId: projectId,
    );
    state = AsyncData(
      (state.value ?? []).map((n) => n.id == id ? updated : n).toList(),
    );
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData(
      (state.value ?? []).where((n) => n.id != id).toList(),
    );
  }
}
