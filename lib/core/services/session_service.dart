import 'dart:async';
import 'package:flutter/material.dart';

class SessionService extends WidgetsBindingObserver {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Timer? _timer;
  VoidCallback? _onTimeout;
  DateTime? _lastActive;
  bool _isActive = false;

  void start({required VoidCallback onTimeout}) {
    _onTimeout = onTimeout;
    _isActive = true;
    _lastActive = DateTime.now();
    _resetTimer();
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    _isActive = false;
    _timer?.cancel();
    _onTimeout = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void reset() {
    if (!_isActive) return;
    _lastActive = DateTime.now();
    _resetTimer();
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(minutes: 5), () {
      if (_onTimeout != null) {
        _onTimeout!();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isActive) return;

    if (state == AppLifecycleState.resumed) {
      if (_lastActive != null) {
        final duration = DateTime.now().difference(_lastActive!);
        if (duration.inMinutes >= 5) {
          if (_onTimeout != null) _onTimeout!();
        } else {
          _resetTimer();
        }
      }
    } else if (state == AppLifecycleState.paused) {
      _lastActive = DateTime.now();
      _timer?.cancel(); // In background, we'll check duration on resume
    }
  }
}

