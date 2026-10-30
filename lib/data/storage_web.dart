abstract class AppStorage {
  Future<String?> read();

  Future<void> write(String content);

  String get description;
}

AppStorage createDefaultStorage() => MemoryAppStorage();

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
  throw UnsupportedError('浏览器环境不能直接写入文件，内容已复制到剪贴板。');
}
