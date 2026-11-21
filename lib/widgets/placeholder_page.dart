import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(
      {super.key, required this.title, required this.icon, required this.text});
  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: AppColors.navy),
            const SizedBox(height: 12),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }
}