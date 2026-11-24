import 'package:material_ui/material_ui.dart';
import '../theme/app_theme.dart';

class AppBackground extends StatefulWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;
  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _blob(Color color, Alignment a, double size) => Align(
        alignment: a,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              color.withValues(alpha: 0.35),
              color.withValues(alpha: 0),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: RepaintBoundary(child: widget.child),
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.bg),
            _blob(AppColors.navy,
                Alignment.lerp(const Alignment(-1.1, -1.0), const Alignment(-0.6, -0.5), t)!, 620),
            _blob(AppColors.yellow,
                Alignment.lerp(const Alignment(1.1, -0.6), const Alignment(0.7, -0.9), t)!, 520),
            _blob(AppColors.red,
                Alignment.lerp(const Alignment(0.9, 1.1), const Alignment(0.4, 0.7), t)!, 560),
            child!,
          ],
        );
      },
    );
  }
}