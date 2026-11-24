import 'package:flutter/foundation.dart';

/// Pide al menú que cambie a la pestaña con esa etiqueta (por ejemplo, 'Citas').
final ValueNotifier<String?> irAPestana = ValueNotifier<String?>(null);

void irA(String etiqueta) {
  irAPestana.value = etiqueta;
}