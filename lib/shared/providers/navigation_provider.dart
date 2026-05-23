import 'package:flutter/material.dart';

class MainNavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  String? _journalFilter;

  int get selectedIndex => _selectedIndex;
  String? get journalFilter => _journalFilter;

  void setIndex(int index, {String? journalFilter}) {
    _journalFilter = journalFilter;
    if (_selectedIndex == index) {
      if (journalFilter != null) notifyListeners();
      return;
    }
    _selectedIndex = index;
    notifyListeners();
  }
  
  void clearJournalFilter() {
    _journalFilter = null;
  }
}
