import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/utils/pdf_generator.dart';

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
        allowSharing: false, // Disable default PDF sharing
        pdfFileName: 'DO_${transaction.nomor}.pdf',
        previewPageMargin: const EdgeInsets.all(8),
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.share),
            onPressed: (context, build, pageFormat) async {
              try {
                // Tampilkan loading snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Menyiapkan gambar untuk dibagikan...')),
                );
                
                final pdfBytes = await build(pageFormat);
                
                // Render halaman pertama PDF menjadi gambar
                await for (final page in Printing.raster(pdfBytes, dpi: 300)) {
                  final imageBytes = await page.toPng();
                  
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/DO_${transaction.nomor}.jpg');
                  await file.writeAsBytes(imageBytes);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  }
                  
                  await Share.shareXFiles(
                    [XFile(file.path, mimeType: 'image/jpeg')],
                    text: 'Bukti Transaksi DO ${transaction.nomor}',
                  );
                  break; // Hanya halaman pertama
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal membagikan gambar: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
