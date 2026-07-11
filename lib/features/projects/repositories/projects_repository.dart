import '../../../core/supabase/supabase_client.dart';
import '../models/project.dart';

class ProjectsRepository {
  static const _table = 'projects';

  Future<List<Project>> fetchAll() async {
    final data = await supabase
        .from(_table)
        .select()
        .order('created_at', ascending: true);
    return (data as List)
        .map((j) => Project.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Project> create(String name) async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from(_table)
        .insert({'name': name, 'user_id': userId})
        .select()
        .single();
    return Project.fromJson(data);
  }

  Future<Project> rename(String id, String name) async {
    final data = await supabase
        .from(_table)
        .update({'name': name})
        .eq('id', id)
        .select()
        .single();
    return Project.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }
}
