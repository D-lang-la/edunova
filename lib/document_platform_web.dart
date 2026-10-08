// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const _prefix = 'edunova_web_document_';

Future<LocalFileDocument?> selectAndSaveDocument() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    withData: true,
  );
  if (result == null || result.files.single.bytes == null) return null;

  final selected = result.files.single;
  final key = '$_prefix${DateTime.now().microsecondsSinceEpoch}_${selected.name}';
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(key, base64Encode(selected.bytes!));

  return LocalFileDocument(name: selected.name, path: key, size: selected.size);
}

Future<bool> openStoredDocument(String path) async {
  final preferences = await SharedPreferences.getInstance();
  final encoded = preferences.getString(path);
  if (encoded == null) return false;

  final bytes = base64Decode(encoded);
  final blob = html.Blob(<Uint8List>[Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..target = '_blank'
    ..download = path.substring(path.lastIndexOf('_') + 1)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}

Future<void> deleteStoredDocument(String path) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.remove(path);
}
