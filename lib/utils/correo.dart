String correoDesdeEntrada(String entrada) {
  final t = entrada.trim().toLowerCase();
  if (t.contains('@')) return t;
  if (RegExp(r'^a?\d+$').hasMatch(t)) {
    return '${t.startsWith('a') ? t : 'a$t'}@unison.mx';
  }
  return '$t@unison.mx';
}