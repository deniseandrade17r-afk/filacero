import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
];

String _larga(DateTime d) => '${d.day} de ${_meses[d.month - 1]} de ${d.year}';

Future<Uint8List> generarJustificantePdf({
  required String folio,
  required String alumno,
  required String matricula,
  required String carrera,
  required DateTime desde,
  required DateTime hasta,
  required String motivo,
  required String coordinador,
}) async {
  final logoBytes = (await rootBundle.load('assets/logo.png')).buffer.asUint8List();
  final logo = pw.MemoryImage(logoBytes);
  final periodo = (desde.year == hasta.year &&
          desde.month == hasta.month &&
          desde.day == hasta.day)
      ? 'el ${_larga(desde)}'
      : 'del ${_larga(desde)} al ${_larga(hasta)}';

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(56),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Image(logo, height: 70),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('UNIVERSIDAD DE SONORA',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text('Coordinación de carrera',
                      style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(height: 4),
                  pw.Text('Folio: $folio',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 40),
          pw.Center(
            child: pw.Text('JUSTIFICANTE DE INASISTENCIA',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 18)),
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            'Por medio del presente se hace constar que el(la) alumno(a) '
            '$alumno, con matricula $matricula, del programa $carrera, '
            'presento comprobante para justificar su inasistencia $periodo, '
            'por el siguiente motivo:',
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
          ),
          pw.SizedBox(height: 12),
          pw.Text('"$motivo"',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 12)),
          pw.SizedBox(height: 12),
          pw.Text(
            'La coordinacion reviso y valido el comprobante entregado.',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Se extiende el presente a solicitud del interesado para los '
            'fines que a este convengan, el ${_larga(DateTime.now())}.',
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
          ),
          pw.Spacer(),
          pw.Center(
            child: pw.Column(children: [
              pw.Container(width: 220, height: 1, color: PdfColors.black),
              pw.SizedBox(height: 6),
              pw.Text(coordinador, style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Coordinador(a) de carrera',
                  style: const pw.TextStyle(fontSize: 10)),
            ]),
          ),
          pw.SizedBox(height: 36),
          pw.Divider(),
          pw.Text('Documento generado en FilaCero. Folio $folio.',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    ),
  );
  return doc.save();
}