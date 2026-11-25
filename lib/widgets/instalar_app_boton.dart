import 'dart:async';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/pwa.dart';
import 'glass_card.dart';

void _ayudaInstalar(BuildContext context) {
  final ios = pwaPlataforma() == 'ios';
  showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Instalar FilaCero'),
      content: SingleChildScrollView(
        child: Text(ios
            ? 'En iPhone o iPad:\n\n'
                '1. Abre esta página en Safari.\n'
                '2. Toca el botón Compartir (el cuadro con una flecha hacia arriba).\n'
                '3. Elige "Agregar a pantalla de inicio".\n'
                '4. Toca "Agregar".\n\n'
                'En Chrome para iPhone: menú ⋯ → "Agregar a pantalla de inicio".'
            : 'En Chrome o Edge (computadora): ícono de instalar en la barra de '
                'direcciones, o menú ⋮ → "Transmitir, guardar y compartir" → '
                '"Instalar página como aplicación".\n\n'
                'En Android (Chrome): menú ⋮ → "Instalar aplicación" o '
                '"Agregar a la pantalla principal".\n\n'
                'En Mac con Safari: Archivo → "Agregar al Dock".\n\n'
                'En Firefox de escritorio no está disponible; usa Chrome o Edge.'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: const Text('Entendido')),
      ],
    ),
  );
}

Future<void> _instalarOAyudar(BuildContext context) async {
  if (pwaPuedeInstalar()) {
    final r = await pwaInstalar();
    if (!context.mounted) return;
    if (r == 'accepted') {
      mostrarAviso(context, 'FilaCero se instaló. Búscala entre tus aplicaciones.',
          tipo: TipoAviso.exito);
    }
  } else {
    _ayudaInstalar(context);
  }
}

/// Botón para la pantalla de inicio de sesión (en iPhone muestra las instrucciones).
class InstalarAppBoton extends StatefulWidget {
  const InstalarAppBoton({super.key});
  @override
  State<InstalarAppBoton> createState() => _InstalarAppBotonState();
}

class _InstalarAppBotonState extends State<InstalarAppBoton> {
  Timer? _timer;
  int _intentos = 0;
  bool _puede = pwaPuedeInstalar();
  final bool _instalada = pwaYaInstalada();

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

  @override
  Widget build(BuildContext context) {
    if (_instalada) return const SizedBox.shrink();

    if (pwaPlataforma() == 'ios') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.yellow.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.ios_share_rounded, color: AppColors.navy),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
                'Instala FilaCero en tu iPhone: toca Compartir y elige '
                '"Agregar a pantalla de inicio".',
                style: TextStyle(fontSize: 13)),
          ),
          TextButton(
              onPressed: () => _ayudaInstalar(context),
              child: const Text('Pasos')),
        ]),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _instalarOAyudar(context),
      icon: const Icon(Icons.install_mobile_rounded),
      label: Text(_puede ? 'Instalar FilaCero' : 'Cómo instalar la app'),
    );
  }
}

/// Ícono para el menú de la app (visible después de iniciar sesión).
class InstalarAppIcono extends StatelessWidget {
  const InstalarAppIcono({super.key});

  @override
  Widget build(BuildContext context) {
    if (pwaYaInstalada()) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Instalar app',
      icon: const Icon(Icons.install_mobile_rounded),
      onPressed: () => _instalarOAyudar(context),
    );
  }
}