String normalizar(String s) {
  var t = s.toLowerCase();
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  for (var i = 0; i < de.length; i++) {
    t = t.replaceAll(de[i], a[i]);
  }
  t = t.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _stop = {
  'de',
  'del',
  'la',
  'el',
  'las',
  'los',
  'en',
  'entre',
  'y',
  'a',
  'por',
  'para',
  'con',
  'mas',
  'anos',
};

int _puntos(String texto, Map<String, dynamic> t) {
  final padded = ' $texto ';
  var p = 0;
  for (final k in ((t['palabras_clave'] as List?) ?? []).cast<String>()) {
    final kn = normalizar(k);
    if (kn.isEmpty) continue;
    if (padded.contains(' $kn ')) p += kn.split(' ').length + 1;
  }
  for (final w in normalizar(t['nombre'] as String).split(' ')) {
    if (w.length < 4 || _stop.contains(w)) continue;
    if (padded.contains(' $w ')) p += 1;
  }
  return p;
}

class _Intencion {
  const _Intencion(this.id, this.frases);
  final String id;
  final List<String> frases;
}

const _intenciones = [
  _Intencion('saludo', [
    'hola',
    'buenas',
    'buenos dias',
    'buenas tardes',
    'buenas noches',
    'que tal',
    'hey',
  ]),
  _Intencion('gracias', ['gracias', 'muchas gracias']),
  _Intencion('cita', [
    'agendar cita',
    'agendar una cita',
    'sacar cita',
    'pedir cita',
    'como agendo',
    'citas',
    'cita',
  ]),
  _Intencion('estado', [
    'estado de mi tramite',
    'seguimiento',
    'en que va mi',
    'como va mi',
    'mi solicitud',
    'mi tramite',
  ]),
  _Intencion('cancelar', ['cancelar', 'anular', 'ya no quiero mi tramite']),
  _Intencion('turno', ['turno', 'mi lugar en la fila', 'cuanto falta', 'fila']),
  _Intencion('cuenta', [
    'contrasena',
    'olvide mi contrasena',
    'recuperar mi cuenta',
  ]),
  _Intencion('ayuda', [
    'ayuda',
    'que puedes hacer',
    'que haces',
    'para que sirves',
  ]),
];

class Analisis {
  Analisis(this.candidatos, this.seguro, this.intencion);
  final List<Map<String, dynamic>> candidatos;
  final bool seguro;
  final String? intencion;
}

String? _detectarIntencion(String texto) {
  final padded = ' $texto ';
  String? mejor;
  var largo = 0;
  for (final i in _intenciones) {
    for (final f in i.frases) {
      if (padded.contains(' $f ') && f.length > largo) {
        mejor = i.id;
        largo = f.length;
      }
    }
  }
  return mejor;
}

Analisis analizar(String entrada, List<Map<String, dynamic>> tramites) {
  final texto = normalizar(entrada);
  final puntuados = <MapEntry<Map<String, dynamic>, int>>[];
  for (final t in tramites) {
    final p = _puntos(texto, t);
    if (p > 0) puntuados.add(MapEntry(t, p));
  }
  puntuados.sort((a, b) => b.value.compareTo(a.value));

  final intencion = _detectarIntencion(texto);
  if (puntuados.isEmpty) return Analisis([], false, intencion);

  final mejor = puntuados.first.value;
  if (mejor >= 2) {
    final corte = mejor * 0.7 < 2 ? 2 : mejor * 0.7;
    final cand = puntuados
        .where((e) => e.value >= corte)
        .take(3)
        .map((e) => e.key)
        .toList();
    return Analisis(cand, true, intencion);
  }
  // Coincidencia débil: se ofrecen opciones, salvo que sea una pregunta frecuente
  if (intencion != null) return Analisis([], false, intencion);
  return Analisis(
    puntuados.take(3).map((e) => e.key).toList(),
    false,
    intencion,
  );
}
