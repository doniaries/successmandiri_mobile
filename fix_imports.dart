import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('import package:sawitappmobile/core/utils/app_time.dart;')) {
      content = content.replaceAll('import package:sawitappmobile/core/utils/app_time.dart;', 'import ''package:sawitappmobile/core/utils/app_time.dart'';');
      file.writeAsStringSync(content);
      print('Fixed ' + file.path);
    }
  }
}
