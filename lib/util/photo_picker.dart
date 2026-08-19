import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

/// Escolhe uma foto da galeria e abre a tela de corte/reposicionamento
/// (círculo 1:1, igual ao avatar exibido no app) antes de devolver o
/// arquivo final — usado em toda tela que envolve foto de perfil
/// (`register_page.dart`, `complete_google_profile_page.dart`,
/// `edit_profile_page.dart`). Retorna `null` se o usuário cancelar em
/// qualquer etapa (seleção ou corte).
Future<File?> pickAndCropProfilePhoto() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
  );
  if (picked == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    compressQuality: 82,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Ajustar foto',
        toolbarColor: SibValColors.navyBlue,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: SibValColors.goldAccent,
        backgroundColor: Colors.black,
        cropStyle: CropStyle.circle,
        lockAspectRatio: true,
        hideBottomControls: false,
      ),
    ],
  );
  if (cropped == null) return null;

  return File(cropped.path);
}
