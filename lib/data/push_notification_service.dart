import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef PushTokenCallback = Future<void> Function(String token);
typedef PushOpenCallback = void Function(Map<String, String> data);

class PushNotificationService {
  static const enabled = bool.fromEnvironment('FCM_ENABLED', defaultValue: false);
  static bool get isSupported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  static const _channel = AndroidNotificationChannel(
    'smartbin_notifications',
    'Notifikasi SmartBIN',
    description: 'Peringatan setoran dan informasi akun SmartBIN.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openSubscription;
  PushTokenCallback? _onToken;
  PushOpenCallback? _onOpen;
  bool _initialized = false;
  bool _authorized = false;
  String? _registeredToken;
  Completer<String?>? _registrationCompleter;

  Future<void> initialize({required PushTokenCallback onToken, required PushOpenCallback onOpen}) async {
    if (!enabled || !isSupported) return;
    _onToken = onToken;
    _onOpen = onOpen;
    if (_initialized) return;

    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          _open(const {});
          return;
        }
        _open(_payloadData(payload));
      },
    );
    await _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
    await _messaging.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);

    _tokenSubscription = _messaging.onRegistered.listen((token) {
      _registeredToken = token;
      final registration = _registrationCompleter;
      if (registration != null && !registration.isCompleted) registration.complete(token);
      if (_authorized && _registrationCompleter == null) unawaited(_registerToken(token));
    }, onError: (Object error) => debugPrint('SmartBIN FCM registration stream failed: $error'));
    _messageSubscription = FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _openSubscription = FirebaseMessaging.onMessageOpenedApp.listen((message) => _open(_messageData(message)));
    _initialized = true;

    final localLaunch = await _localNotifications.getNotificationAppLaunchDetails();
    final localPayload = localLaunch?.notificationResponse?.payload;
    if (localLaunch?.didNotificationLaunchApp == true && localPayload != null && localPayload.isNotEmpty) {
      _open(_payloadData(localPayload));
    }
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _open(_messageData(initialMessage));
  }

  Future<String?> requestPermissionAndGetToken() async {
    if (!enabled || !isSupported || !_initialized) return null;
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    _authorized = settings.authorizationStatus == AuthorizationStatus.authorized || settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!_authorized) return null;
    final registration = Completer<String?>();
    _registrationCompleter = registration;
    try {
      await _messaging.register();
      final token = _registeredToken ?? await registration.future.timeout(const Duration(seconds: 20));
      return token;
    } finally {
      _registrationCompleter = null;
    }
  }

  Future<String?> currentToken() async => !enabled || !isSupported || !_initialized ? null : _registeredToken;

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openSubscription?.cancel();
  }

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<void> _registerToken(String token) async {
    try {
      await _onToken?.call(token);
    } on FirebaseException catch (error) {
      debugPrint('SmartBIN FCM token refresh failed: ${error.code}');
    } catch (error) {
      debugPrint('SmartBIN FCM token registration failed: $error');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;
    await _localNotifications.show(
      id: (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch) & 0x7fffffff,
      title: title ?? 'SmartBIN',
      body: body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(_messageData(message)),
    );
  }

  Map<String, String> _messageData(RemoteMessage message) => message.data.map((key, value) => MapEntry(key, value.toString()));

  Map<String, String> _payloadData(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return const {};
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  void _open(Map<String, String> data) => _onOpen?.call(data);
}
