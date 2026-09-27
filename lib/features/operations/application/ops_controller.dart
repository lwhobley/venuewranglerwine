import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_ops_repository.dart';

final opsRepositoryProvider = Provider<SupabaseOpsRepository>((ref) {
  return SupabaseOpsRepository(Supabase.instance.client);
});
