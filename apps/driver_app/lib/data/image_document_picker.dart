import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'session.dart';

/// Documents are photographed (or chosen from the gallery) and compressed before upload.
class ImageDocumentPicker implements DocumentPicker {
  final _picker = ImagePicker();

  @override
  Future<PickedDocument?> pick(DocumentSource source) async {
    final file = await _picker.pickImage(
      source: source == DocumentSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 75,
    );
    if (file == null) return null;
    final name = file.name.isEmpty ? 'document.jpg' : file.name;
    final mime = file.mimeType ?? (name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    return PickedDocument(bytes: await file.readAsBytes(), filename: name, mime: mime);
  }
}

final documentPickerProvider = Provider<DocumentPicker>((ref) => ImageDocumentPicker());
