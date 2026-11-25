import 'package:material_ui/material_ui.dart';

import '../pages/asistente_page.dart';
import 'glass_card.dart';

class AsistenteTarjeta extends StatelessWidget {
  const AsistenteTarjeta({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AsistentePage()),
        ),
        child: Row(children: [
          Image.asset(
            'assets/buho.png',
            height: 56,
            width: 56,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.smart_toy_rounded, size: 40),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿No sabes qué trámite necesitas?',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 2),
                Text('Cuéntale al asistente qué quieres hacer y te orienta.'),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }
}