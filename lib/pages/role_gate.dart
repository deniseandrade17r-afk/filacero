import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_shell.dart';
import '../widgets/placeholder_page.dart';
import 'catalogo_page.dart';
import 'tramites_alumno_page.dart';
import 'seguimiento_page.dart';

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
    _perfil =
        db.from('profiles').select().eq('id', db.auth.currentUser!.id).single();
  }

  Widget _ph(String t, IconData i, String x) =>
      PlaceholderPage(title: t, icon: i, text: x);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _perfil,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('No se pudo cargar tu perfil.'),
              TextButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ]),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        switch (snap.data!['rol']) {
          case 'admin':
            return AppShell(rol: 'Administrador', items: [
              const NavItem('Catálogo', Icons.list_alt_rounded,
                  CatalogoPage(titulo: 'Catálogo de trámites')),
              NavItem('Usuarios', Icons.group_rounded,
                  _ph('Usuarios y roles', Icons.group_rounded,
                      'Aquí el administrador autorizará personal y asignará roles.')),
            ]);
          case 'coordinador':
            return AppShell(rol: 'Coordinador', items: [
              NavItem('Solicitudes', Icons.inbox_rounded,
                  _ph('Solicitudes', Icons.inbox_rounded,
                      'Aquí se revisarán y resolverán las solicitudes de los alumnos.')),
              NavItem('Turnos', Icons.confirmation_number_rounded,
                  _ph('Atender turnos', Icons.confirmation_number_rounded,
                      'Aquí se atenderá la fila del día.')),
              NavItem('Justificantes', Icons.description_rounded,
                  _ph('Justificantes', Icons.description_rounded,
                      'Aquí se emitirán justificantes de inasistencia.')),
              NavItem('Demanda', Icons.insights_rounded,
                  _ph('Panel de demanda', Icons.insights_rounded,
                      'Aquí se verán los trámites más frecuentes y las semanas pico.')),
            ]);
                    default:
            return AppShell(rol: 'Alumno', items: [
              const NavItem('Inicio', Icons.home_rounded,
                  CatalogoPage(titulo: 'Trámites disponibles', saludo: true)),
              const NavItem(
                  'Trámites', Icons.assignment_rounded, TramitesAlumnoPage()),
              NavItem(
                  'Citas',
                  Icons.event_rounded,
                  _ph('Mis citas', Icons.event_rounded,
                      'Aquí agendarás y consultarás tus citas.')),
              const NavItem(
                  'Seguimiento', Icons.timeline_rounded, SeguimientoPage()),
            ]);
        }
      },
    );
  }
}