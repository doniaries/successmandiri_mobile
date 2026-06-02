import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/models/laporan_tonase.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Get Kasir Name and Printed By
    String kasirName = 'Kasir';
    String dicetakOleh = 'Admin';
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('cached_user');
      if (userStr != null) {
        final Map<String, dynamic> userMap = jsonDecode(userStr);
        kasirName = userMap['perusahaan_kasir'] ?? userMap['nama_kasir'] ?? 'Kasir';
        dicetakOleh = userMap['name'] ?? 'Admin';
      }
    } catch (_) {}

    final pageTheme = pw.PageTheme(
      pageFormat: pageFormat,
      theme: theme,
    );

    pdf.addPage(
      pw.Page(
        pageTheme: pageTheme,
        build: (pw.Context context) {
          return pw.DefaultTextStyle(
            style: const pw.TextStyle(fontSize: 9),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Container
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Spacer untuk menyimbangkan agar teks perusahaan tetap di tengah jika qr dikanan
                      pw.SizedBox(width: 50),
                      
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 5),
                              decoration: const pw.BoxDecoration(
                                border: pw.Border(bottom: pw.BorderSide(width: 1)),
                              ),
                              child: pw.Text(
                                transaction.perusahaanNama ?? 'Perusahaan Sawit',
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            // Alamat dan telepon (bisa dikosongkan karena tidak ada di model mobile)
                          ],
                        ),
                      ),
                      
                      // QR Code container dikanan
                      pw.Container(
                        width: 50,
                        margin: const pw.EdgeInsets.only(left: 10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: transaction.nomor,
                              width: 40,
                              height: 40,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text('Scan QR', style: const pw.TextStyle(fontSize: 6)),
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
                  margin: const pw.EdgeInsets.only(top: 10),
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Kasir: $kasirName',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                          pw.Text(
                            'Dicetak oleh: $dicetakOleh',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Dicetak pada: ${dateFormat.format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
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

  static Future<Uint8List> generateLaporanTonasePdf(LaporanTonaseResponse data, int month, int year) async {
    final pdf = pw.Document();

    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
    );

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final monthFormat = DateFormat('MMMM yyyy', 'id_ID');
    final numberFormat = NumberFormat.decimalPattern('id');

    // Mengambil data perusahaan & kasir
    String kasirName = '-';
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('cached_user');
      if (userStr != null) {
        final Map<String, dynamic> userMap = jsonDecode(userStr);
        kasirName = userMap['name'] ?? '-';
      }
    } catch (_) {}

    String perusahaanName = 'Semua Perusahaan';
    if (data.perusahaanPabrik != null && data.perusahaanPabrik!.trim().isNotEmpty) {
      perusahaanName = data.perusahaanPabrik!;
    } else if (data.perusahaanName != null && data.perusahaanName!.trim().isNotEmpty) {
      perusahaanName = data.perusahaanName!;
    }

    final pageFormat = PdfPageFormat.a4;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          theme: theme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        ),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text('Kasir: $kasirName', style: const pw.TextStyle(fontSize: 10)),
              ),
              pw.Container(
                alignment: pw.Alignment.center,
                margin: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Column(
                  children: [
                    pw.Text(
                      perusahaanName.toUpperCase(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'LAPORAN TONASE BULANAN\n${monthFormat.format(DateTime(year, month)).toUpperCase()}',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                  ]
                ),
              ),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Dicetak pada: ${dateFormat.format(DateTime.now())} - Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Table(
              border: pw.TableBorder.all(width: 1, color: PdfColors.black),
              columnWidths: {
                0: const pw.FixedColumnWidth(30),
                1: const pw.FixedColumnWidth(80),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Table Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildCell('No', isBold: true, align: pw.TextAlign.center),
                    _buildCell('Tanggal', isBold: true, align: pw.TextAlign.center),
                    _buildCell('Tonase (Kg)', isBold: true, align: pw.TextAlign.right),
                    _buildCell('Harga (Rp)', isBold: true, align: pw.TextAlign.right),
                    _buildCell('Keterangan', isBold: true, align: pw.TextAlign.left),
                  ],
                ),
                // Table Body
                ...data.report.asMap().entries.map((entry) {
                  final index = entry.key;
                  final row = entry.value;
                  final textColor = row.isHoliday ? PdfColors.red : PdfColors.black;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: row.isHoliday ? PdfColors.red50 : PdfColors.white),
                    children: [
                      _buildCell('${index + 1}', align: pw.TextAlign.center, color: textColor),
                      _buildCell(row.tanggal, align: pw.TextAlign.center, color: textColor),
                      _buildCell(row.tonase > 0 ? numberFormat.format(row.tonase) : '-', align: pw.TextAlign.right, color: textColor),
                      _buildCell(row.harga > 0 ? numberFormat.format(row.harga) : '-', align: pw.TextAlign.right, color: textColor),
                      _buildCell(row.keterangan, align: pw.TextAlign.left, color: textColor),
                    ],
                  );
                }),
                // Total Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildCell('', align: pw.TextAlign.center),
                    _buildCell('TOTAL', isBold: true, align: pw.TextAlign.center),
                    _buildCell(numberFormat.format(data.totalTonase), isBold: true, align: pw.TextAlign.right),
                    _buildCell('', align: pw.TextAlign.center),
                    _buildCell('', align: pw.TextAlign.center),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildCell(String text, {bool isBold = false, pw.TextAlign align = pw.TextAlign.left, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3), // Diperkecil agar tabel tidak overflow
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
          fontSize: 9, // Font sedikit lebih kecil agar lebih fit
        ),
      ),
    );
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
