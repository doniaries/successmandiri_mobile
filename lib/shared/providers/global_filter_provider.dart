import 'package:flutter/material.dart';

class GlobalFilterProvider extends ChangeNotifier {
  DateTime? _selectedDate;

  DateTime? get selectedDate => _selectedDate;

  /// Update tanggal filter global dan beritahu seluruh listener
  void setDate(DateTime? date) {
    // Hanya update jika tanggal benar-benar berubah
    if (_selectedDate?.year == date?.year &&
        _selectedDate?.month == date?.month &&
        _selectedDate?.day == date?.day) {
      return;
    }
    _selectedDate = date;
    notifyListeners();
  }

  /// Reset filter tanggal
  void clearDate() {
    if (_selectedDate != null) {
      _selectedDate = null;
      notifyListeners();
    }
  }
}
