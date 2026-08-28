import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_repository.dart';
import '../data/user_repository.dart';
import '../firebase_options.dart';
import '../models/notification.dart';
import 'notification_navigation.dart';

const _pushChannelId = 'default_channel';
const _pushChannelName = 'Notificações';

/// Id local determinístico a partir do id do doc em `notifications`
/// (`notificationId`, presente em toda mensagem desde 22/08/2026) — permite
/// cancelar essa notificação específica da barra depois (ver
/// `PushNotificationService.cancelNotification` e
/// `lib/notifications/notification_read_sync.dart`), coisa que não dava com
/// `message.hashCode` (não reproduzível a partir do id salvo no Firestore).
int _localNotificationId(String notificationId) => notificationId.hashCode;

/// Mostra a notificação local a partir de `data` (mensagem só-com-dados,
/// sem bloco `notification` do FCM — ver `dataOnlyMessage` em
/// `SIBValApp2/functions/index.js`, 24/08/2026). Função solta (fora da
/// classe) porque também é chamada por `firebaseMessagingBackgroundHandler`,
/// que roda num isolate separado e não pode reaproveitar a instância de
/// `PushNotificationService`.
Future<void> showFcmLocalNotification(Map<String, dynamic> data) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(_pushChannelId, _pushChannelName, importance: Importance.high),
      );
  final notificationId = data['notificationId'] as String? ?? '';
  await plugin.show(
    id: notificationId.isNotEmpty ? _localNotificationId(notificationId) : DateTime.now().millisecondsSinceEpoch,
    title: data['title'] as String?,
    body: data['body'] as String?,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(_pushChannelId, _pushChannelName, icon: 'ic_notification'),
      iOS: DarwinNotificationDetails(),
    ),
    payload: jsonEncode(data),
  );
}

/// Manipulador de mensagens FCM em segundo plano/app fechado — exigido pelo
/// `firebase_messaging` pra rodar num isolate próprio quando o app não está
/// em primeiro plano, registrado em main.dart antes do `runApp`. Precisa
/// inicializar o Firebase de novo (isolates não compartilham o estado do
/// motor Flutter). Substitui a exibição automática do SDK do FCM (que
/// existia enquanto as mensagens carregavam o bloco `notification`) — agora
/// o app decide mostrar em qualquer estado, com o mesmo id previsível de
/// `showFcmLocalNotification`, pra poder cancelar depois.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await showFcmLocalNotification(message.data);
}

/// Espelha app/src/main/java/com/sibval/app/notifications/FcmService.kt
/// (`onNewToken`/`onMessageReceived`) + o `setUpNotifications()` de
/// HomeFragment.kt (pede permissão e registra o token FCM em `users/{uid}`,
/// consumido pelas Cloud Functions em `functions/index.js` do repo nativo) +
/// `MainActivity.handleNotificationIntent` (navega pro destino certo ao
/// tocar). Ícone `ic_notification` copiado de
/// `SIBValApp2/app/src/main/res/mipmap-*` p/ `android/app/.../res/drawable-*`
/// (flutter_local_notifications só resolve ícone pequeno como recurso
/// `drawable`, não `mipmap`).
///
/// Desde 24/08/2026 as mensagens do FCM são só-com-dados (sem bloco
/// `notification`) — o app decide exibir sozinho em qualquer estado
/// (`_onForegroundMessage` aqui, ou `firebaseMessagingBackgroundHandler` em
/// segundo plano/fechado), o que permite cancelar uma notificação
/// específica da barra depois (`cancelNotification`), usado quando o
/// usuário abre a tela relacionada sem tocar na notificação (ver
/// `lib/notifications/notification_read_sync.dart`).
class PushNotificationService {
  PushNotificationService(this._userRepository, this._notificationRepository);

  final UserRepository _userRepository;
  final NotificationRepository _notificationRepository;

  /// Usado pelo `MaterialApp` em main.dart e por este serviço para navegar a
  /// partir do toque numa notificação, já que isso acontece fora da árvore
  /// de qualquer tela específica.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const _channelId = _pushChannelId;
  static const _channelName = _pushChannelName;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  final Set<String> _registeredUids = {};

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(_channelId, _channelName, importance: Importance.high),
        );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _onMessageOpenedApp(initialMessage);
  }

  /// Chamado quando há um uid logado (ver `main_shell.dart`, disparado a
  /// cada build enquanto logado — o guard por uid evita repetir o pedido de
  /// permissão e criar múltiplos listeners de `onTokenRefresh`) — pede
  /// permissão de notificação (cobre POST_NOTIFICATIONS no Android 13+ e
  /// APNs no iOS) e salva/atualiza o token FCM do dispositivo.
  Future<void> requestPermissionAndRegisterToken(String uid) async {
    if (_registeredUids.contains(uid)) return;
    _registeredUids.add(uid);

    await _ensureInitialized();
    await FirebaseMessaging.instance.requestPermission();

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _userRepository.updateFcmToken(uid, token);
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _userRepository.updateFcmToken(uid, newToken);
    });
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    if (message.data.isEmpty) return;
    // Finalização de culto vira um popup de verdade em vez do banner do
    // sistema, pra quem já está com o app aberto (28/08/2026, pedido do
    // usuário: "exibir uma popup para todos os usuários") — em segundo
    // plano/fechado, `firebaseMessagingBackgroundHandler` continua mostrando
    // o banner normal (não dá pra abrir diálogo Flutter fora do app rodando).
    if (message.data['type'] == NotificationType.serviceOrderFinalized) {
      _showFinalizedBlessingDialog(message.data);
      return;
    }
    await showFcmLocalNotification(message.data);
  }

  void _showFinalizedBlessingDialog(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(data['title'] as String? ?? 'Culto finalizado'),
        content: Text(data['body'] as String? ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Amém'),
          ),
        ],
      ),
    );
  }

  /// Cancela a notificação da barra do celular — usado tanto ao tocar nela
  /// (`_navigate`, autocancel já cuida disso, mas não custa) quanto quando o
  /// usuário chega na tela relacionada por outro caminho (ver
  /// `lib/notifications/notification_read_sync.dart`). `notificationId`
  /// vazio (push antigo, sem esse campo) é ignorado — nada pra cancelar.
  Future<void> cancelNotification(String notificationId) async {
    if (notificationId.isEmpty) return;
    await _ensureInitialized();
    await _localNotifications.cancel(id: _localNotificationId(notificationId));
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _navigate(
      type: message.data['type'] as String? ?? '',
      targetId: message.data['targetId'] as String? ?? '',
      notificationId: message.data['notificationId'] as String? ?? '',
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    _navigate(
      type: data['type'] as String? ?? '',
      targetId: data['targetId'] as String? ?? '',
      notificationId: data['notificationId'] as String? ?? '',
    );
  }

  /// Marca como lida mesmo quando a notificação é aberta direto pelo toque
  /// (push ou notificação local), sem passar pela Central de notificações
  /// dentro do app — antes só acontecia ali (22/08/2026, a pedido do
  /// usuário). `notificationId` vem no payload desde a mesma data (ver
  /// `SIBValApp2/functions/index.js`); ausente = push antigo, ignora.
  Future<void> _navigate({required String type, required String targetId, required String notificationId}) async {
    if (type.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (notificationId.isNotEmpty && uid != null) {
      await _notificationRepository.markAsRead([notificationId], uid);
    }
    final context = navigatorKey.currentContext;
    if (context == null) return;
    navigateForNotificationType(context, type: type, targetId: targetId);
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(userRepositoryProvider), ref.watch(notificationRepositoryProvider));
});
