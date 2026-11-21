const kMaxBytes = 5 * 1024 * 1024; // 5 MB
const kExtPermitidas = ['pdf', 'jpg', 'jpeg', 'png'];

String extDe(String nombre) =>
    nombre.contains('.') ? nombre.split('.').last.toLowerCase() : '';

String mimeDe(String nombre) {
  switch (extDe(nombre)) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    default:
      return 'image/jpeg';
  }
}

/// Devuelve un mensaje de error, o null si el archivo es válido.
String? validarArchivo(String nombre, int bytes) {
  if (!kExtPermitidas.contains(extDe(nombre))) {
    return 'Formato no permitido. Usa PDF, JPG o PNG.';
  }
  if (bytes == 0) return 'El archivo está vacío.';
  if (bytes > kMaxBytes) return 'El archivo pesa más de 5 MB.';
  return null;
}