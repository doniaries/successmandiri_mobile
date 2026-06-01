import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/utils/pdf_generator.dart';

class TransaksiDoPdfPreviewScreen extends StatelessWidget {
  final TransaksiDo transaction;

  const TransaksiDoPdfPreviewScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Cetak DO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => PdfGenerator.generateTransaksiDoPdf(transaction),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'DO_${transaction.nomor}.pdf',
        previewPageMargin: const EdgeInsets.all(8),
      ),
    );
  }
}
