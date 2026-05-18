import 'package:flutter/material.dart';
import 'package:sawitappmobile/features/dashboard/models/dashboard_summary_model.dart';
import 'package:sawitappmobile/shared/repositories/dashboard_repository.dart';

class DashboardProvider with ChangeNotifier {
  final DashboardRepository _repository = DashboardRepository();

  DashboardSummary? _summary;
  bool _isLoading = false;
  String? _error;

  DashboardSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchSummary({String? date}) async {
    if (_summary == null || date != null) _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _repository.getSummary(date: date);
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

