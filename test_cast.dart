void main() {
  dynamic p = null;
  try {
    var x = p as Map<String, dynamic>;
  } catch(e) {
    print("Test 1: " + e.toString());
  }
}
