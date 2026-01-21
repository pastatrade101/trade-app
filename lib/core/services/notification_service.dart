import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../../app/navigation.dart';
import '../../features/home/presentation/signal_detail_screen.dart';
import '../../features/tips/presentation/tip_detail_screen.dart';
import '../../services/analytics_service.dart';
import '../widgets/app_toast.dart';
import '../models/user_membership.dart';
import 'membership_service.dart';

class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
    String projectId = 'asset-vista',
    String region = 'us-central1',
  })
      : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client(),
        _projectId = projectId,
        _region = region;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String _projectId;
  final String _region;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _handlersInitialized = false;
  bool _localInitialized = false;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<UserMembership?>? _premiumSessionsSub;
  bool? _premiumSessionsEnabled;

  Future<void> initForUser(String uid) async {
    if (kIsWeb || uid.isEmpty) {
      return;
    }
    await ensurePermission();
    await _initLocalNotifications();
    _initHandlers();
    final token = await _messaging.getToken();
    if (token != null) {
      await _persistToken(uid, token);
      _currentToken = token;
    }
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      await _persistToken(uid, newToken);
      if (_currentToken != null && _currentToken != newToken) {
        await _deleteToken(uid, _currentToken!);
      }
      _currentToken = newToken;
    });
  }

  Future<bool> ensurePermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  void _initHandlers() {
    if (_handlersInitialized) {
      return;
    }
    _handlersInitialized = true;
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageNavigation(message);
      }
    });
  }

  Future<void> _persistToken(String uid, String token) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token)
          .set({
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        if (kDebugMode) {
          debugPrint('NotificationService: permission denied writing token for $uid');
        }
        return;
      }
      rethrow;
    }
  }

  Future<void> _deleteToken(String uid, String token) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('tokens')
          .doc(token)
          .delete();
    } catch (_) {}
  }

  Future<void> clearUserToken(String uid) async {
    if (kIsWeb || uid.isEmpty) {
      return;
    }
    final token = _currentToken ?? await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _deleteToken(uid, token);
    try {
      await _messaging.deleteToken();
    } catch (_) {}
    if (_currentToken == token) {
      _currentToken = null;
    }
  }

  Future<void> resetUserSession({String? uid}) async {
    await stopPremiumSessionsTopicSync();
    if (uid != null && uid.isNotEmpty) {
      await clearUserToken(uid);
    }
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  Future<void> subscribeToTraderTopic(String traderUid) async {
    if (kIsWeb || traderUid.isEmpty) {
      return;
    }
    await _messaging.subscribeToTopic(_topicForTrader(traderUid));
  }

  Future<void> subscribeToPremiumSessionsTopic() async {
    if (kIsWeb) {
      return;
    }
    await _messaging.subscribeToTopic('premium_sessions');
    await AnalyticsService.instance.logEvent(
      'session_alert_enabled',
      params: {'sessionName': 'all'},
    );
  }

  Future<void> unsubscribeFromTraderTopic(String traderUid) async {
    if (kIsWeb || traderUid.isEmpty) {
      return;
    }
    await _messaging.unsubscribeFromTopic(_topicForTrader(traderUid));
  }

  Future<void> unsubscribeFromPremiumSessionsTopic() async {
    if (kIsWeb) {
      return;
    }
    await _messaging.unsubscribeFromTopic('premium_sessions');
  }

  void startPremiumSessionsTopicSync({
    required String uid,
    required Stream<UserMembership?> membershipStream,
    required MembershipService membershipService,
  }) {
    if (kIsWeb || uid.isEmpty) {
      return;
    }
    _premiumSessionsSub?.cancel();
    _premiumSessionsEnabled = null;
    _premiumSessionsSub = membershipStream.listen((membership) async {
      final enabled = membershipService.isPremiumActive(membership);
      if (_premiumSessionsEnabled == enabled) {
        return;
      }
      _premiumSessionsEnabled = enabled;
      if (enabled) {
        await subscribeToPremiumSessionsTopic();
      } else {
        await unsubscribeFromPremiumSessionsTopic();
      }
    });
  }

  Future<void> stopPremiumSessionsTopicSync() async {
    await _premiumSessionsSub?.cancel();
    _premiumSessionsSub = null;
    if (_premiumSessionsEnabled == true) {
      await unsubscribeFromPremiumSessionsTopic();
    }
    _premiumSessionsEnabled = null;
  }

  Future<void> syncTraderTopics({
    required List<String> traderUids,
    required bool enabled,
  }) async {
    if (kIsWeb) {
      return;
    }
    for (final uid in traderUids) {
      if (enabled) {
        await subscribeToTraderTopic(uid);
      } else {
        await unsubscribeFromTraderTopic(uid);
      }
    }
  }

  Future<void> _initLocalNotifications() async {
    if (_localInitialized) {
      return;
    }
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );
    const channel = AndroidNotificationChannel(
      'signals',
      'Signal alerts',
      description: 'Notifications for new trading signals',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _localInitialized = true;
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    await _showLocalNotificationPayload(
      title: notification?.title ?? 'New signal',
      body: notification?.body ?? '',
      data: message.data,
    );
  }

  Future<void> _showLocalNotificationPayload({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    await _initLocalNotifications();
    final androidDetails = AndroidNotificationDetails(
      'signals',
      'Signal alerts',
      channelDescription: 'Notifications for new trading signals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    try {
      final data = jsonDecode(payload);
      if (data is Map) {
        _navigateFromData(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      return;
    }
    final title = message.notification?.title ?? 'New signal';
    final body = message.notification?.body;
    AppToast.info(context, body == null ? title : '$title • $body');
    unawaited(_showLocalNotification(message));
  }

  void _handleMessageNavigation(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  void _navigateFromData(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type != 'new_signal' && type != 'new_tip') {
      return;
    }
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    if (type == 'new_tip') {
      final tipId = data['tipId']?.toString();
      if (tipId == null || tipId.isEmpty) {
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => TipDetailScreen(tipId: tipId),
        ),
      );
      return;
    }
    final signalId = data['signalId']?.toString();
    if (signalId == null || signalId.isEmpty) {
      return;
    }
    navigator.push(
      MaterialPageRoute(
        builder: (_) => SignalDetailScreen(signalId: signalId),
      ),
    );
  }

  String _topicForTrader(String traderUid) => 'trader_$traderUid';

  Uri get _testNotificationUri => Uri.https(
        '$_region-$_projectId.cloudfunctions.net',
        '/sendTestSignalNotification',
      );

  Uri get _testSessionReminderUri => Uri.https(
        '$_region-$_projectId.cloudfunctions.net',
        '/sendTestSessionReminder',
      );

  Future<void> sendTestNotification({String? traderUid}) async {
    if (kIsWeb) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to send test notifications.');
    }
    final idToken = await user.getIdToken();
    final response = await _httpClient.post(
      _testNotificationUri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (traderUid != null && traderUid.isNotEmpty) 'traderUid': traderUid,
      }),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Unable to send test notification (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> sendTestSessionReminder({String session = 'london'}) async {
    if (kIsWeb) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to send test notifications.');
    }
    final idToken = await user.getIdToken();
    final response = await _httpClient.post(
      _testSessionReminderUri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'session': session}),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Unable to send test session reminder (${response.statusCode}): ${response.body}',
      );
    }
  }
}
