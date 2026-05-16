import 'dart:async';
import 'package:flutter/material.dart';

class SuccessDialog extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onConfirm;
  final bool isOffline;

  const SuccessDialog({
    super.key,
    this.title = 'Berhasil!',
    this.message = 'Data Anda telah berhasil disimpan ke sistem.',
    this.onConfirm,
    this.isOffline = false,
  });

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();

  static void show(
    BuildContext context, {
    String title = 'Berhasil!',
    String message = 'Data Anda telah berhasil disimpan ke sistem.',
    VoidCallback? onConfirm,
    bool isOffline = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SuccessDialog(
        title: title,
        message: message,
        onConfirm: onConfirm,
        isOffline: isOffline,
      ),
    );
  }
}

class _SuccessDialogState extends State<SuccessDialog> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto close after 4 seconds
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _handleConfirm();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleConfirm() {
    _timer?.cancel();
    if (widget.onConfirm != null) {
      widget.onConfirm!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10.0,
              offset: const Offset(0.0, 10.0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: widget.isOffline ? Colors.orange[50] : Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isOffline ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
                color: widget.isOffline ? Colors.orange[800] : Colors.blue[900],
                size: 60,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isOffline ? 'Tersimpan Offline' : widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isOffline ? Colors.orange[800] : const Color(0xFF01579B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 5,
                  shadowColor: (widget.isOffline ? Colors.orange : const Color(0xFF01579B)).withValues(alpha: 0.3),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

