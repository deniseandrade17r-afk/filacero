import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login_page.dart';
import 'pages/role_gate.dart';
import 'theme/app_theme.dart';
import 'widgets/app_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://tfyllgrplejawkxjvjsg.supabase.co', // Project URL
    anonKey: 'sb_publishable_NKBL_PjEk5rsMODpjTGUtw_qmH4C3HY',    //clave anon/publishable
  );
  runApp(const FilaCeroApp());
}

class FilaCeroApp extends StatelessWidget {
  const FilaCeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FilaCero',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => AppBackground(child: child!),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, _) {
          final session = Supabase.instance.client.auth.currentSession;
          return session == null ? const LoginPage() : const RoleGate();
        },
      ),
    );
  }
}