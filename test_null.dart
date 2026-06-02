void main() {
  dynamic rawUserData = null;
  try {
    Map<String, dynamic>.from(rawUserData);
  } catch(e) {
    print(e.toString());
  }
}
