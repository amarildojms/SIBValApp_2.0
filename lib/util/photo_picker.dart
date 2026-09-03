import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';

/// Escolhe uma foto da galeria e abre a tela de corte/reposicionamento antes
/// de devolver o arquivo final. Base compartilhada por
/// [pickAndCropProfilePhoto] (círculo 1:1) e [pickAndCropBannerPhoto]
/// (retângulo 16:9) — generalizada em 03/09/2026 (pedido do usuário: "em
/// todos os locais onde é possível inserir foto" ganhar a mesma capacidade
/// de reenquadrar/cortar que já existia só pra foto de perfil). Retorna
/// `null` se o usuário cancelar em qualquer etapa (seleção ou corte).
Future<File?> pickAndCropPhoto({
  required CropStyle cropStyle,
  CropAspectRatio? aspectRatio,
  bool lockAspectRatio = true,
  String toolbarTitle = 'Ajustar foto',
}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1280,
    maxHeight: 1280,
  );
  if (picked == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
    aspectRatio: aspectRatio,
    compressQuality: 82,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: toolbarTitle,
        toolbarColor: SibValColors.navyBlue,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: SibValColors.goldAccent,
        backgroundColor: Colors.black,
        cropStyle: cropStyle,
        lockAspectRatio: lockAspectRatio,
        hideBottomControls: false,
      ),
    ],
  );
  if (cropped == null) return null;

  return File(cropped.path);
}

/// Foto de perfil/avatar (círculo 1:1) — usada em toda tela que envolve foto
/// de pessoa: `register_page.dart`, `complete_google_profile_page.dart`,
/// `edit_profile_page.dart` e `members_page.dart` (foto do membro no Rol de
/// Membros, mesmo enquadramento por ser exibida do mesmo jeito, em
/// `CircleAvatar`).
Future<File?> pickAndCropProfilePhoto() => pickAndCropPhoto(
      cropStyle: CropStyle.circle,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    );

/// Imagem em formato "banner"/flyer (retângulo 16:9) — usada em eventos
/// (`event_form_page.dart`), Repositório de Flyers
/// (`recurring_event_flyer_repository_page.dart`), Quadro de Avisos
/// (`notice_form_page.dart`) e posts do Mural (`post_form_page.dart`),
/// todas já com o mesmo aviso visual "Proporção recomendada: 16:9" antes
/// desta mudança.
Future<File?> pickAndCropBannerPhoto() => pickAndCropPhoto(
      cropStyle: CropStyle.rectangle,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      toolbarTitle: 'Ajustar imagem',
    );
