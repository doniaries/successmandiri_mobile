import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<Uint8List> generateTransaksiDoPdf(TransaksiDo transaction) async {
    final pdf = pw.Document();

    // Font setup
    // Use default fonts, or you can load a custom font if needed
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
    );

    final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'id_ID');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DELIVERY ORDER (DO)',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          transaction.perusahaanNama ?? 'Perusahaan Sawit',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'No: ${transaction.nomor}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          dateFormat.format(transaction.tanggal),
                          style: const pw.TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 30),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 20),

                // Pihak Terkait
                pw.Text(
                  'PIHAK TERKAIT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 10),
                _buildInfoRow('Penjual', transaction.penjualNama ?? '-'),
                _buildInfoRow('Supir', transaction.displaySupirNama),
                _buildInfoRow('No. Polisi', transaction.noPolisi ?? '-'),

                pw.SizedBox(height: 20),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 20),

                // Detail Barang
                pw.Text(
                  'DETAIL TRANSAKSI',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 10),
                
                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Deskripsi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Jumlah', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Kelapa Sawit (${transaction.tonase} Kg @ ${CurrencyFormatter.formatRupiah(transaction.hargaSatuan)})'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${transaction.tonase} Kg'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(CurrencyFormatter.formatRupiah(transaction.subTotal)),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                // Rincian Pembayaran
                pw.Container(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildSummaryRow('Sub Total:', CurrencyFormatter.formatRupiah(transaction.subTotal)),
                      _buildSummaryRow('Upah Bongkar:', '- ${CurrencyFormatter.formatRupiah(transaction.upahBongkar)}'),
                      _buildSummaryRow('Biaya Lain/Peng.:', '- ${CurrencyFormatter.formatRupiah(transaction.biayaLain)}'),
                      if (transaction.keteranganBiayaLain != null && transaction.keteranganBiayaLain!.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(
                            '(${transaction.keteranganBiayaLain})',
                            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                          ),
                        ),
                      _buildSummaryRow('Hutang Awal:', CurrencyFormatter.formatRupiah(transaction.hutangAwal)),
                      _buildSummaryRow('Bayar Hutang:', '- ${CurrencyFormatter.formatRupiah(transaction.pembayaranHutang)}'),
                      pw.Divider(width: 250, color: PdfColors.grey400),
                      pw.SizedBox(height: 5),
                      _buildSummaryRow('Total Bersih:', CurrencyFormatter.formatRupiah(transaction.sisaBayar), isBold: true, isTotal: true),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 20),

                // Status
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'INFORMASI PEMBAYARAN',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text('Metode: ${(transaction.caraBayar ?? '-').toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Sisa Hutang: ${CurrencyFormatter.formatRupiah(transaction.sisaHutangPenjual)}'),
                          if (transaction.keteranganPembayaran != null && transaction.keteranganPembayaran!.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text('Keterangan: ${transaction.keteranganPembayaran}'),
                          ],
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.SizedBox(height: 40),
                          pw.Text('_______________________'),
                          pw.SizedBox(height: 4),
                          pw.Text('Tanda Tangan / Cap', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700)),
          ),
          pw.Text(': '),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label, 
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                color: isTotal ? PdfColors.black : PdfColors.grey700,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: isTotal ? 14 : 12,
              )
            ),
          ),
          pw.SizedBox(width: 15),
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: isTotal ? 16 : 12,
                color: isTotal ? PdfColors.blue800 : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
