import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart') && !f.path.contains('app_time.dart'));
  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('DateTime.now()')) {
      content = content.replaceAll('DateTime.now()', 'AppTime.now()');
      if (!content.contains('import ''package:sawitappmobile/core/utils/app_time.dart'';')) {
        final lines = content.split('\n');
        int insertIdx = 0;
        for (int i=0; i<lines.length; i++) {
          if (lines[i].startsWith('import ')) insertIdx = i + 1;
        }
        lines.insert(insertIdx, 'import ''package:sawitappmobile/core/utils/app_time.dart'';');
        content = lines.join('\n');
      }
      file.writeAsStringSync(content);
      print('Updated ' + file.path);
    }
  }
}
