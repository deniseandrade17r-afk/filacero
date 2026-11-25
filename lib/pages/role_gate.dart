import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/app_shell.dart';
import 'catalogo_admin_page.dart';
import 'citas_page.dart';
import 'demanda_page.dart';
import 'horarios_page.dart';
import 'notificaciones_page.dart';
import 'seguimiento_page.dart';
import 'solicitudes_page.dart';
import 'tramites_alumno_page.dart';
import 'turnos_page.dart';
import 'usuarios_page.dart';
import 'inicio_alumno_page.dart';

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});
  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  late final Future<Map<String, dynamic>> _perfil;

  @override
  void initState() {
    super.initState();
    final db = Supabase.instance.client;
    _perfil = db
        .from('profiles')
        .select()
        .eq('id', db.auth.currentUser!.id)
        .single();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _perfil,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar tu perfil.'),
                TextButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        const avisos = NavItem(
          'Avisos',
          Icons.notifications_rounded,
          NotificacionesPage(),
        );
        const horarios = NavItem(
          'Horarios',
          Icons.schedule_rounded,
          HorariosPage(),
        );
        const demanda = NavItem(
          'Demanda',
          Icons.insights_rounded,
          DemandaPage(),
        );

        switch (snap.data!['rol']) {
          case 'admin':
            return AppShell(
              rol: 'Administrador',
              items: [
                const NavItem(
                  'Catálogo',
                  Icons.list_alt_rounded,
                  CatalogoAdminPage(),
                ),
                horarios,
                const NavItem('Usuarios', Icons.group_rounded, UsuariosPage()),
                demanda,
                avisos,
              ],
            );
          case 'coordinador':
            return AppShell(
              rol: 'Coordinador',
              items: [
                const NavItem(
                  'Solicitudes',
                  Icons.inbox_rounded,
                  SolicitudesPage(),
                ),
                const NavItem(
                  'Turnos',
                  Icons.confirmation_number_rounded,
                  TurnosPage(),
                ),
                horarios,
                demanda,
                avisos,
              ],
            );
          default:
            return AppShell(
              rol: 'Alumno',
              items: [
                const NavItem('Inicio', Icons.home_rounded, InicioAlumnoPage()),
                const NavItem(
                  'Trámites',
                  Icons.assignment_rounded,
                  TramitesAlumnoPage(),
                ),
                const NavItem('Citas', Icons.event_rounded, CitasPage()),
                const NavItem(
                  'Seguimiento',
                  Icons.timeline_rounded,
                  SeguimientoPage(),
                ),
                avisos,
              ],
            );
        }
      },
    );
  }
}
