import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cantidad de avisos sin leer; el menú la muestra como insignia.
final ValueNotifier<int> noLeidas = ValueNotifier<int>(0);

Future<void> actualizarNoLeidas() async {
  try {
    final res = await Supabase.instance.client
        .from('notificaciones')
        .select('id')
        .eq('leida', false);
    noLeidas.value = res.length;
  } catch (_) {}
}