import 'package:material_ui/material_ui.dart';
import '../theme/app_theme.dart';

String estadoLabel(String e) {
  switch (e) {
    case 'borrador':
      return 'Borrador';
    case 'recibido':
      return 'Recibido';
    case 'en_revision':
      return 'En revisión';
    case 'requiere_correccion':
      return 'Requiere corrección';
    case 'aprobado':
      return 'Aprobado';
    case 'listo_para_recoger':
      return 'Listo para recoger';
    case 'rechazado':
      return 'Rechazado';
    case 'cancelado':
      return 'Cancelado';
    default:
      return e;
  }
}

Color estadoColor(String e) {
  switch (e) {
    case 'recibido':
      return AppColors.navy;
    case 'en_revision':
      return const Color(0xFFB7791F);
    case 'requiere_correccion':
    case 'rechazado':
      return AppColors.red;
    case 'aprobado':
    case 'listo_para_recoger':
      return const Color(0xFF2E7D32);
    default:
      return Colors.blueGrey;
  }
}