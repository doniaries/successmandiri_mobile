class AppTime {
  static DateTime now() {
    return DateTime.now().toUtc().add(const Duration(hours: 7));
  }
}
