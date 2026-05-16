import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LiveDateTimeWidget extends StatefulWidget {
  final TextStyle? style;
  final Color? color;
  final bool showSeconds;

  const LiveDateTimeWidget({
    super.key,
    this.style,
    this.color,
    this.showSeconds = true,
  });

  @override
  State<LiveDateTimeWidget> createState() => _LiveDateTimeWidgetState();
}

class _LiveDateTimeWidgetState extends State<LiveDateTimeWidget> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('E, d MMM yyyy', 'id_ID');
    final timeFormat = DateFormat(widget.showSeconds ? 'HH:mm:ss' : 'HH:mm', 'id_ID');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (widget.color ?? const Color(0xFF01579B)).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (widget.color ?? const Color(0xFF01579B)).withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 14,
            color: widget.color ?? const Color(0xFF01579B),
          ),
          const SizedBox(width: 8),
          Text(
            '${dateFormat.format(_currentTime)} • ${timeFormat.format(_currentTime)}',
            style: widget.style ?? TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.color ?? const Color(0xFF01579B),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
