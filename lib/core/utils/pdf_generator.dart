import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<Uint8List> generateTransaksiDoPdf(TransaksiDo transaction) async {
    final pdf = pw.Document();

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
    );

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final numberFormat = NumberFormat.decimalPattern('id');

    // Custom Page Size: 165mm x 210mm
    final pageFormat = PdfPageFormat(165 * PdfPageFormat.mm, 210 * PdfPageFormat.mm, marginAll: 8 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: theme,
        build: (pw.Context context) {
          return pw.DefaultTextStyle(
            style: const pw.TextStyle(fontSize: 9),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Container
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 1)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              transaction.perusahaanNama ?? 'Perusahaan Sawit',
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                            ),
                            // Alamat dan telepon (bisa dikosongkan karena tidak ada di model mobile,
                            // atau diganti placeholder)
                          ],
                        ),
                      ),
                      // QR Code container bisa dikosongkan untuk versi mobile
                      pw.Container(
                        margin: const pw.EdgeInsets.only(left: 10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            // Placeholder untuk QR agar layout seimbang jika diperlukan
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Title
                pw.Container(
                  alignment: pw.Alignment.center,
                  margin: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Text(
                    'BUKTI TRANSAKSI DO',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ),

                // Table
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 30),
                  child: pw.Table(
                    border: pw.TableBorder.all(width: 1, color: PdfColors.black),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(100),
                      1: const pw.FlexColumnWidth(),
                    },
                    children: [
                      _buildTableRow('Nomor DO', transaction.nomor, isBoldRight: true),
                      _buildTableRow('Tanggal & Waktu', dateFormat.format(transaction.tanggal.toLocal())),
                      _buildTableRow('Nama Penjual', transaction.penjualNama ?? 'N/A'),
                      _buildTableRow('Nama Supir', transaction.displaySupirNama),
                      _buildTableRow('Nomor Polisi', transaction.noPolisi ?? 'N/A'),
                      _buildTableRow('Tonase (Kg)', numberFormat.format(transaction.tonase)),
                      _buildTableRow('Harga Satuan', 'Rp${numberFormat.format(transaction.hargaSatuan)}'),
                      _buildTableRow('Sub Total', 'Rp${numberFormat.format(transaction.subTotal)}'),
                      _buildTableRow('Upah Bongkar', 'Rp${numberFormat.format(transaction.upahBongkar)}'),
                      _buildTableRow('Biaya Lain', 'Rp${numberFormat.format(transaction.biayaLain)}'),
                      _buildTableRow('Hutang Awal', 'Rp${numberFormat.format(transaction.hutangAwal)}'),
                      _buildTableRow('Pembayaran Hutang', 'Rp${numberFormat.format(transaction.pembayaranHutang)}'),
                      _buildTableRow('Sisa Hutang', 'Rp${numberFormat.format(transaction.sisaHutangPenjual)}', isBoldRight: true),
                      _buildTableRow('Cara Bayar', transaction.caraBayar ?? ''),
                      _buildTableRow('Sisa Bayar', 'Rp${numberFormat.format(transaction.sisaBayar)}', isBoldRight: true),
                      if (transaction.isMismatch)
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: pw.Text('Catatan Penting', style: const pw.TextStyle(color: PdfColors.red)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: pw.Text('Rekap manual dengan inputan tidak Cocok', style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Footer
                pw.Container(
                  alignment: pw.Alignment.center,
                  margin: const pw.EdgeInsets.only(top: 10),
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text(
                    'Dicetak pada: ${dateFormat.format(DateTime.now())} melalui Aplikasi Mobile',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  static pw.TableRow _buildTableRow(String label, String value, {bool isBoldRight = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(label),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: pw.Text(value, style: pw.TextStyle(fontWeight: isBoldRight ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ],
    );
  }
}
