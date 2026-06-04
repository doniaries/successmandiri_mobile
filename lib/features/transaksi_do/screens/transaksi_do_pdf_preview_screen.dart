import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/utils/pdf_generator.dart';

import 'dart:io';
import 'dart:ui' as ui;
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
        maxPageWidth: 2000,
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
                  final ui.Image image = await page.toImage();
                  
                  // Buat canvas dengan background putih (menghindari background hitam di WA/sosmed)
                  final recorder = ui.PictureRecorder();
                  final canvas = ui.Canvas(recorder);
                  final bgPaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
                  
                  canvas.drawRect(
                    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
                    bgPaint,
                  );
                  
                  // Gambar hasil PDF di atas background putih
                  canvas.drawImage(image, ui.Offset.zero, ui.Paint());
                  
                  final picture = recorder.endRecording();
                  final imgWithBg = await picture.toImage(image.width, image.height);
                  final byteData = await imgWithBg.toByteData(format: ui.ImageByteFormat.png);
                  final imageBytes = byteData!.buffer.asUint8List();
                  
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/DO_${transaction.nomor}.jpg');
                  await file.writeAsBytes(imageBytes);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  }
                  
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(file.path, mimeType: 'image/jpeg')],
                      text: 'Bukti Transaksi DO ${transaction.nomor}',
                    ),
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
