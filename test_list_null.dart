void main() {
  var list = [null];
  try {
    for (var p in list) {
      var x = p as Map<dynamic, dynamic>;
    }
  } catch(e) {
    print("Test: " + e.toString());
  }
}
