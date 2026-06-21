import 'package:flutter/material.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';

class BalanceValidationModal extends StatelessWidget {
  final double currentBalance;
  final double requiredAmount;
  final VoidCallback onAddBalance;

  const BalanceValidationModal({
    super.key,
    required this.currentBalance,
    required this.requiredAmount,
    required this.onAddBalance,
  });

  static void show(
    BuildContext context, {
    required double currentBalance,
    required double requiredAmount,
    required VoidCallback onAddBalance,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BalanceValidationModal(
        currentBalance: currentBalance,
        requiredAmount: requiredAmount,
        onAddBalance: onAddBalance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Saldo Tidak Mencukupi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Saldo Anda saat ini tidak mencukupi untuk melakukan pembayaran secara Tunai atau Transfer.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Saldo Perusahaan',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.formatRupiah(currentBalance),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Tetap Lanjut',
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onAddBalance();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01579B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Tambah Saldo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

