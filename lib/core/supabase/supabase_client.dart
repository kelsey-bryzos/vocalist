import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client accessor — convenience shortcut used throughout the app.
SupabaseClient get supabase => Supabase.instance.client;
