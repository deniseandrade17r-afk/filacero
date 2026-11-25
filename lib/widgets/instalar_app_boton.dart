import 'dart:async';
import 'package:material_ui/material_ui.dart';

import '../utils/pwa.dart';
import 'glass_card.dart';

class InstalarAppBoton extends StatefulWidget {
  const InstalarAppBoton({super.key});
  @override
  State<InstalarAppBoton> createState() => _InstalarAppBotonState();
}

class _InstalarAppBotonState extends State<InstalarAppBoton> {
  Timer? _timer;
  int _intentos = 0;
  bool _puede = pwaPuedeInstalar();
  bool _instalada = pwaYaInstalada();

  @override
  void initState() {
    super.initState();
    // El navegador avisa que se puede instalar unos segundos después de cargar
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _intentos++;
      final p = pwaPuedeInstalar();
      if (mounted && p != _puede) setState(() => _puede = p);
      if (_intentos >= 10) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _instalar() async {
    final r = await pwaInstalar();
    if (!mounted) return;
    if (r == 'accepted') {
      mostrarAviso(context, 'FilaCero se instaló. Búscala entre tus aplicaciones.',
          tipo: TipoAviso.exito);
    }
    setState(() {
      _puede = pwaPuedeInstalar();
      _instalada = pwaYaInstalada();
    });
  }

  void _ayuda() {
    final ios = pwaPlataforma() == 'ios';
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Instalar FilaCero'),
        content: Text(ios
            ? '1. Abre esta página en Safari.\n'
                '2. Toca el botón Compartir (el cuadro con una flecha hacia arriba).\n'
                '3. Elige "Agregar a pantalla de inicio".\n'
                '4. Toca "Agregar".'
            : 'En Chrome o Edge (computadora): usa el ícono de instalar en la '
                'barra de direcciones o el menú ⋮ → "Instalar FilaCero".\n\n'
                'En Android: menú ⋮ → "Instalar aplicación" o "Agregar a la '
                'pantalla principal".\n\n'
                'En Firefox de escritorio no está disponible; usa Chrome o Edge.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Entendido')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_instalada) return const SizedBox.shrink();
    return OutlinedButton.icon(
      onPressed: _puede ? _instalar : _ayuda,
      icon: const Icon(Icons.install_mobile_rounded),
      label: Text(_puede ? 'Instalar FilaCero' : 'Cómo instalar la app'),
    );
  }
}