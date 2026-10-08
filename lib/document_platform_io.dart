import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class LocalFileDocument {
  final String name;
  final String path;
  final int size;

  const LocalFileDocument({
    required this.name,
    required this.path,
    required this.size,
  });
}

Future<LocalFileDocument?> selectAndSaveDocument() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    withData: false,
  );
  if (result == null || result.files.single.path == null) return null;

  final selected = result.files.single;
  final appDirectory = await getApplicationDocumentsDirectory();
  final documentsDirectory = Directory('${appDirectory.path}/documentos');
  await documentsDirectory.create(recursive: true);
  final safeName = '${DateTime.now().microsecondsSinceEpoch}_${selected.name}';
  final destination = File('${documentsDirectory.path}/$safeName');
  await File(selected.path!).copy(destination.path);

  return LocalFileDocument(
    name: selected.name,
    path: destination.path,
    size: selected.size,
  );
}

Future<bool> openStoredDocument(String path) async {
  final result = await OpenFilex.open(path);
  return result.type == ResultType.done;
}

Future<void> deleteStoredDocument(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // El índice se puede limpiar aunque el archivo ya no exista.
  }
}
