import 'dart:js_interop';

@JS('pwaDisponible')
external bool _disponible();

@JS('pwaInstalada')
external bool _instalada();

@JS('pwaPlataforma')
external String _plataforma();

@JS('pwaInstalar')
external JSPromise<JSString> _instalar();

bool pwaPuedeInstalar() {
  try {
    return _disponible();
  } catch (_) {
    return false;
  }
}

bool pwaYaInstalada() {
  try {
    return _instalada();
  } catch (_) {
    return false;
  }
}

String pwaPlataforma() {
  try {
    return _plataforma();
  } catch (_) {
    return 'otro';
  }
}

Future<String> pwaInstalar() async {
  try {
    final r = await _instalar().toDart;
    return r.toDart;
  } catch (_) {
    return 'error';
  }
}