import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_repository.dart';
import 'notification_navigation.dart';

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
/// Só a exibição em primeiro plano precisa de código aqui
/// (`flutter_local_notifications`, canal `default_channel`) — em segundo
/// plano/app finalizado o próprio SDK do FCM já exibe a notificação no
/// system tray sem passar por código do app, igual no nativo.
class PushNotificationService {
  PushNotificationService(this._userRepository);

  final UserRepository _userRepository;

  /// Usado pelo `MaterialApp` em main.dart e por este serviço para navegar a
  /// partir do toque numa notificação, já que isso acontece fora da árvore
  /// de qualquer tela específica.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const _channelId = 'default_channel';
  static const _channelName = 'Notificações';

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
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName, icon: 'ic_notification'),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _navigate(message.data['type'] as String? ?? '', message.data['targetId'] as String? ?? '');
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final data = jsonDecode(payload) as Map<String, dynamic>;
    _navigate(data['type'] as String? ?? '', data['targetId'] as String? ?? '');
  }

  void _navigate(String type, String targetId) {
    if (type.isEmpty) return;
    final context = navigatorKey.currentContext;
    if (context == null) return;
    navigateForNotificationType(context, type: type, targetId: targetId);
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(userRepositoryProvider));
});
