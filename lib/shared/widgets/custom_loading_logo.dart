import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';

class AnimatedPulsingLogo extends StatefulWidget {
  final double size;
  const AnimatedPulsingLogo({super.key, this.size = 60});

  @override
  State<AnimatedPulsingLogo> createState() => _AnimatedPulsingLogoState();
}

class _AnimatedPulsingLogoState extends State<AnimatedPulsingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_controller);

    _floatAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -10).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 0).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
    ]).animate(_controller);

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Color transition logic (0.0 to 1.0 to 0.0)
        final colorProgress = (t < 0.5 ? t * 2 : (1 - t) * 2);

        final resourceProvider = context.watch<ResourceProvider>();
        final appLogo = resourceProvider.appLogoUrl;

        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner Glow / Aura
                Container(
                  width: widget.size * 1.5,
                  height: widget.size * 1.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF01579B).withValues(alpha: 0.2 * colorProgress),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // Main Logo Container
                ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: [
                        _shimmerAnimation.value - 0.3,
                        _shimmerAnimation.value,
                        _shimmerAnimation.value + 0.3,
                      ],
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.srcATop,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: appLogo != null && appLogo.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: appLogo,
                            width: widget.size,
                            height: widget.size,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Image.asset(
                              'assets/images/logo.png',
                              width: widget.size,
                              height: widget.size,
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              'assets/images/logo.png',
                              width: widget.size,
                              height: widget.size,
                            ),
                          )
                        : Image.asset(
                            'assets/images/logo.png',
                            width: widget.size,
                            height: widget.size,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

