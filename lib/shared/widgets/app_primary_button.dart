import 'package:flutter/material.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';

class AppPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final double borderRadius;
  final double verticalPadding;
  final double fontSize;
  final bool isFullWidth;

  const AppPrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.borderRadius = 16,
    this.verticalPadding = 16,
    this.fontSize = 16,
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = backgroundColor ?? const Color(0xFF01579B);
    
    Widget button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 4,
        shadowColor: themeColor.withValues(alpha: 0.4),
        disabledBackgroundColor: themeColor.withValues(alpha: 0.6),
      ),
      child: isLoading
          ? const AppLoadingIndicator(size: 24)
          : Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
