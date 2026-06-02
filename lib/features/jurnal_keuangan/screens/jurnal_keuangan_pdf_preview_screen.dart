import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:dio/dio.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

class JurnalKeuanganPdfPreviewScreen extends StatefulWidget {
  final DateTime targetDate;

  const JurnalKeuanganPdfPreviewScreen({
    super.key,
    required this.targetDate,
  });

  @override
  State<JurnalKeuanganPdfPreviewScreen> createState() => _JurnalKeuanganPdfPreviewScreenState();
}

class _JurnalKeuanganPdfPreviewScreenState extends State<JurnalKeuanganPdfPreviewScreen> {
  Future<Uint8List> _fetchPdf(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final token = await authProvider.getAuthToken();
    if (token == null) throw Exception('No token');

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.targetDate);
    final url = '${ApiConstants.baseUrl.replaceAll('/api', '')}/jurnal-keuangan/rekap?token=${Uri.encodeComponent(token)}&start_date=$dateStr&end_date=$dateStr&rentang=hari_ini&download=1';

    final dio = Dio();
    final response = await dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode == 200) {
      return Uint8List.fromList(response.data);
    } else {
      throw Exception('Failed to load PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Laporan Keuangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => _fetchPdf(context),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Laporan_Keuangan_${DateFormat('yyyyMMdd').format(widget.targetDate)}.pdf',
        previewPageMargin: const EdgeInsets.all(8),
      ),
    );
  }
}
