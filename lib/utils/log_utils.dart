import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> logToFile(String message) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/app_logs.txt');
    await file.writeAsString('${DateTime.now()} - $message\n', mode: FileMode.append);
    print('Log escrito com sucesso: $message');
  } catch (e, stackTrace) {
    print('Falha ao escrever log: $e\nStackTrace: $stackTrace');
  }
}