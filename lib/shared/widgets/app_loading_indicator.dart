import 'package:flutter/material.dart';
import 'package:sawitappmobile/shared/widgets/custom_loading_logo.dart';

class AppLoadingIndicator extends StatelessWidget {
  final double size;
  const AppLoadingIndicator({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedPulsingLogo(size: size),
    );
  }
}

class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.white.withValues(alpha: 0.7), // Subtle white overlay instead of dark
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLoadingIndicator(size: 90),
                  if (message != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF01579B), // Use primary color for text
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

