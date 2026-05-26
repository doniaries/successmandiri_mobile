import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import package:sawitappmobile/core/utils/app_time.dart;

class DigitalClock extends StatefulWidget {
  const DigitalClock({super.key});

  @override
  State<DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  late Timer _timer;
  DateTime _now = AppTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = AppTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  static final DateFormat _dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss', 'id_ID');

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Text(
        '${_dateFormat.format(_now)} • ${_timeFormat.format(_now)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

