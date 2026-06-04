import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:sawitappmobile/core/utils/pdf_generator.dart';
import 'package:sawitappmobile/models/laporan_tonase.dart';

class LaporanTonasePdfPreviewScreen extends StatelessWidget {
  final LaporanTonaseResponse data;
  final int month;
  final int year;

  const LaporanTonasePdfPreviewScreen({
    super.key,
    required this.data,
    required this.month,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Laporan Tonase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF27AE60),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => PdfGenerator.generateLaporanTonasePdf(data, month, year),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        maxPageWidth: 2000,
        pdfFileName: 'Laporan_Tonase_${year}_$month.pdf',
        previewPageMargin: const EdgeInsets.all(8),
      ),
    );
  }
}
