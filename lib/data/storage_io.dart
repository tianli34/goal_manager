import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class AppStorage {
  Future<String?> read();

  Future<void> write(String content);

  String get description;
}

AppStorage createDefaultStorage() => FileAppStorage();

class FileAppStorage implements AppStorage {
  static const String fileName = 'goal_manager_data.json';

  String? _path;

  @override
  String get description => _path ?? '应用支持目录/$fileName';

  Future<File> _file() async {
    if (_path != null) return File(_path!);
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    _path = file.path;
    return file;
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String content) async {
    final file = await _file();
    await file.writeAsString(content, flush: true);
  }
}

class MemoryAppStorage implements AppStorage {
  MemoryAppStorage([this.content]);

  String? content;

  @override
  String get description => '内存存储（仅本次会话）';

  @override
  Future<String?> read() async => content;

  @override
  Future<void> write(String value) async {
    content = value;
  }
}

Future<String> writeBackupFile(String fileName, String content) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(content, flush: true);
  return file.path;
}
