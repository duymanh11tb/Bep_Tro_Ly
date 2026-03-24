import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationDetails _shoppingAndroidDetails =
      AndroidNotificationDetails(
        'shopping_suggestion_channel',
        'Goi y mua sam',
        channelDescription:
            'Thong bao nguyen lieu thieu va goi y mua sam cho mon an',
        importance: Importance.max,
        priority: Priority.high,
      );

  static const AndroidNotificationDetails _cookingAndroidDetails =
      AndroidNotificationDetails(
        'cooking_timer_channel',
        'Hen gio nau an',
        channelDescription: 'Thong bao ket thuc hen gio nau an',
        importance: Importance.max,
        priority: Priority.high,
      );

  static const AndroidNotificationDetails _chatAndroidDetails =
      AndroidNotificationDetails(
        'chat_message_channel',
        'Tin nhan chat',
        channelDescription: 'Thong bao khi co tin nhan moi tu thanh vien',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    tz.initializeTimeZones();
    _initialized = true;
  }

  static int cookingNotificationId(String recipeId) {
    final hash = recipeId.hashCode.abs();
    return 20000 + (hash % 10000);
  }

  static Future<void> showMissingIngredientsSuggestion({
    required String recipeName,
    required List<String> missingIngredients,
  }) async {
    if (!_initialized || missingIngredients.isEmpty) return;

    final preview = missingIngredients.take(3).join(', ');
    final more = missingIngredients.length > 3
        ? ' va ${missingIngredients.length - 3} nguyen lieu khac'
        : '';

    await _plugin.show(
      10000 + (recipeName.hashCode.abs() % 1000),
      'Thieu nguyen lieu cho $recipeName',
      'Can mua: $preview$more',
      const NotificationDetails(android: _shoppingAndroidDetails),
    );
  }

  static Future<void> scheduleCookingDoneNotification({
    required int notificationId,
    required String recipeName,
    required int inSeconds,
  }) async {
    if (!_initialized || inSeconds <= 0) return;

    await _plugin.zonedSchedule(
      notificationId,
      'Mon an da san sang',
      'Da het thoi gian nau mon $recipeName. Kiem tra va thuong thuc ngay.',
      tz.TZDateTime.now(tz.local).add(Duration(seconds: inSeconds)),
      const NotificationDetails(android: _cookingAndroidDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'cooking_done',
    );
  }

  static Future<void> showChatNotification({
    required String senderName,
    required String content,
    required int fridgeId,
  }) async {
    if (!_initialized) return;

    await _plugin.show(
      30000 + (fridgeId % 10000),
      senderName,
      content,
      const NotificationDetails(android: _chatAndroidDetails),
      payload: 'chat_$fridgeId',
    );
  }

  static Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    await _plugin.cancel(id);
  }
}
