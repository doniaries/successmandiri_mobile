import 'package:flutter/material.dart';
import '../models/dashboard_summary_model.dart';
import '../repositories/dashboard_repository.dart';

class DashboardProvider with ChangeNotifier {
  final DashboardRepository _repository = DashboardRepository();

  DashboardSummary? _summary;
  bool _isLoading = false;
  String? _error;

  DashboardSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchSummary() async {
    if (_summary == null) _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _repository.getSummary();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearData() {
    _summary = null;
    _error = null;
    notifyListeners();
  }
}

