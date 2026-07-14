/// image_source_sheet.dart — Bottom sheet "Tirar foto" / "Galeria" + pick.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../tokens.dart';

/// Abre o sheet de origem e devolve a [ImageSource] escolhida (ou null se cancelar).
///
/// Na **web**, a câmera costuma ser pouco útil (e falha em vários browsers
/// desktop) — o sheet só oferece galeria/arquivo.
Future<ImageSource?> showImageSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: ClxSpace.x2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ClxSpace.x4,
                  ClxSpace.x1,
                  ClxSpace.x4,
                  ClxSpace.x2,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Foto de perfil',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Tirar foto'),
                  subtitle: const Text('Usar a câmera agora'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(kIsWeb ? 'Escolher arquivo' : 'Escolher da galeria'),
                subtitle: Text(
                  kIsWeb
                      ? 'JPG ou PNG do computador'
                      : 'Selecionar uma imagem salva',
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              const SizedBox(height: ClxSpace.x2),
            ],
          ),
        ),
      );
    },
  );
}

/// Sheet de origem + `pickImage`. Retorna o [XFile] ou null se cancelar.
///
/// Web: abre o seletor de arquivo (galeria) direto — sem sheet de câmera.
Future<XFile?> pickImageWithSource(
  BuildContext context, {
  int maxWidth = 800,
  int maxHeight = 800,
  int imageQuality = 85,
  ImagePicker? picker,
}) async {
  final source = await showImageSourceSheet(context);
  if (source == null) return null;
  final p = picker ?? ImagePicker();
  return p.pickImage(
    source: source,
    maxWidth: maxWidth.toDouble(),
    maxHeight: maxHeight.toDouble(),
    imageQuality: imageQuality,
  );
}
