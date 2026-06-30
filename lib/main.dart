import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'widgets/privacy_policy_button.dart';

class VipTheme {
  // ألوان فودكس المعتمدة من الشعار الجديد
  static const yellow = Color(0xffffc107);
  static const yellowDark = Color(0xfff4a900);
  static const yellowLight = Color(0xffffd54f);
  static const cream = Color(0xfffffbf0);
  static const warmCream = Color(0xfffff3e0);
  static const navy = Color(0xff0f172a);
  static const royal = Color(0xff1f2937);
  static const blue = yellow;
  static const gold = yellow;
  static const goldLight = yellowLight;
  static const page = cream;
  static const muted = Color(0xff6b7280);
  static const mint = Color(0xffe8f5e9);
}

class AppAssets {
  static const logo = 'assets/images/foodx_logo.png';
  static const icon = 'assets/images/foodx_icon.png';
  static const car = 'assets/images/foodx_car.png';
  static const bg = 'assets/images/foodx_bg.png';
  static const welcomeVip = 'assets/images/foodx_welcome_vip.png';
  static const companyLogo = 'assets/images/ah_softtech_logo.png';
}

String productImageUrl(dynamic image) {
  String img = (image ?? '').toString().trim();

  img = img.replaceAll('\\', '/');

  if (img.startsWith('http://') || img.startsWith('https://')) {
    return img;
  }

  img = img.replaceFirst(RegExp(r'^/+'), '');

  if (img.startsWith('storage/')) {
    img = img.replaceFirst('storage/', '');
  }

  if (img.startsWith('public/')) {
    img = img.replaceFirst('public/', '');
  }

  return '${ApiService.storageUrl}/$img';
}

final FlutterLocalNotificationsPlugin customerLocalNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> customerFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class CustomerNotificationService {
  static bool _refreshListenerStarted = false;

  static const AndroidNotificationChannel customerChannel =
      AndroidNotificationChannel(
        'customer_notifications_channel',
        'إشعارات الزبون',
        description: 'تنبيهات وإشعارات تطبيق الزبون',
        importance: Importance.max,
        playSound: true,
      );

  static Future<void> init() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await customerLocalNotifications.initialize(settings: initSettings);

      await customerLocalNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(customerChannel);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title =
            message.notification?.title ??
            message.data['title'] ??
            'إشعار جديد';
        final body =
            message.notification?.body ??
            message.data['body'] ??
            'وصل إشعار جديد إلى حسابك';

        showLocalNotification(title: title, body: body);
      });
    } catch (e) {
      debugPrint('CUSTOMER NOTIFICATION INIT ERROR: $e');
    }
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'customer_notifications_channel',
        'إشعارات الزبون',
        channelDescription: 'تنبيهات وإشعارات تطبيق الزبون',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await customerLocalNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('CUSTOMER LOCAL NOTIFICATION ERROR: $e');
    }
  }

  static Future<void> saveTokenToServer(String authToken) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();

      debugPrint('CUSTOMER FCM TOKEN: $fcmToken');

      if (fcmToken == null || fcmToken.isEmpty) {
        return;
      }

      await ApiService.saveDeviceToken(
        authToken,
        fcmToken,
        deviceType: kIsWeb ? 'web' : 'android',
      );

      if (!_refreshListenerStarted) {
        _refreshListenerStarted = true;

        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          try {
            final prefs = await SharedPreferences.getInstance();
            final token = prefs.getString('token') ?? '';

            if (token.isNotEmpty) {
              await ApiService.saveDeviceToken(
                token,
                newToken,
                deviceType: kIsWeb ? 'web' : 'android',
              );
            }
          } catch (e) {
            debugPrint('CUSTOMER TOKEN REFRESH SAVE ERROR: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('CUSTOMER SAVE TOKEN ERROR: $e');
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: VipTheme.yellow,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: VipTheme.cream,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: VipTheme.cream,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(
    customerFirebaseMessagingBackgroundHandler,
  );

  await CustomerNotificationService.init();

  runApp(const FoodxCustomerApp());
}

class FoodxCustomerApp extends StatelessWidget {
  const FoodxCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "فودكس",
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: "Tahoma",
        scaffoldBackgroundColor: VipTheme.page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: VipTheme.yellow,
          primary: VipTheme.yellow,
          secondary: VipTheme.navy,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: VipTheme.yellow,
          foregroundColor: VipTheme.navy,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: VipTheme.navy,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontFamily: "Tahoma",
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: VipTheme.yellow,
            foregroundColor: VipTheme.navy,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontFamily: "Tahoma",
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: VipTheme.yellow, width: 1.6),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xffeadfbc)),
          ),
        ),
      ),
      home: const SplashPage(),
    );
  }
}

Future<String> getSavedToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString("token") ?? "";
}

dynamic mapValue(dynamic source, List<String> keys) {
  if (source is! Map) return null;
  for (final key in keys) {
    final value = source[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value;
    }
  }
  return null;
}

String? dynamicImageUrl(dynamic source, List<String> keys) {
  final value = mapValue(source, keys);
  if (value == null) return null;
  final url = productImageUrl(value);
  if (url.trim().isEmpty || url.endsWith('/')) return null;
  return url;
}

String storeDeliveryTime(dynamic store) {
  final direct = mapValue(store, [
    'delivery_time',
    'delivery_time_text',
    'estimated_delivery_time',
    'delivery_duration',
  ]);

  if (direct != null) {
    final text = direct.toString();
    return text.contains('دقيقة') ? text : '$text دقيقة';
  }

  final min = mapValue(store, [
    'delivery_time_min',
    'min_delivery_time',
    'delivery_min',
  ]);
  final max = mapValue(store, [
    'delivery_time_max',
    'max_delivery_time',
    'delivery_max',
  ]);

  if (min != null && max != null) return '$min-$max دقيقة';
  if (min != null) return '$min دقيقة';

  return '25-35 دقيقة';
}

String storeRating(dynamic store) {
  final rating = mapValue(store, ['rating', 'avg_rating', 'rate', 'stars']);
  if (rating == null) return '4.8';
  return rating.toString();
}

String storeAddress(dynamic store) {
  final address = mapValue(store, [
    'address',
    'location_name',
    'full_address',
    'area',
  ]);
  return address?.toString() ?? 'لا يوجد عنوان';
}

String storeTypeName(dynamic store) {
  if (store is! Map) return '';
  final nested = store['store_type'];
  if (nested is Map && nested['name'] != null) return nested['name'].toString();
  return mapValue(store, [
        'store_type_name',
        'type_name',
        'category_name',
      ])?.toString() ??
      '';
}

class FavoriteService {
  static const String productKey = 'favorite_products';
  static const String storeKey = 'favorite_stores';

  static String idOf(dynamic item) =>
      (item is Map ? item['id'] : item)?.toString() ?? '';

  static Future<List<Map<String, dynamic>>> _readList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _writeList(
    String key,
    List<Map<String, dynamic>> list,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(list));
  }

  static Future<bool> isFavoriteProduct(dynamic id) async {
    final list = await _readList(productKey);
    final sid = id.toString();
    return list.any((e) => idOf(e) == sid);
  }

  static Future<bool> isFavoriteStore(dynamic id) async {
    final list = await _readList(storeKey);
    final sid = id.toString();
    return list.any((e) => idOf(e) == sid);
  }

  static Future<bool> toggleProduct(Map<String, dynamic> product) async {
    final list = await _readList(productKey);
    final id = idOf(product);
    final index = list.indexWhere((e) => idOf(e) == id);
    if (index >= 0) {
      list.removeAt(index);
      await _writeList(productKey, list);
      return false;
    }
    list.add(product);
    await _writeList(productKey, list);
    return true;
  }

  static Future<bool> toggleStore(Map<String, dynamic> store) async {
    final list = await _readList(storeKey);
    final id = idOf(store);
    final index = list.indexWhere((e) => idOf(e) == id);
    if (index >= 0) {
      list.removeAt(index);
      await _writeList(storeKey, list);
      return false;
    }
    list.add(store);
    await _writeList(storeKey, list);
    return true;
  }

  static Future<List<Map<String, dynamic>>> products() => _readList(productKey);
  static Future<List<Map<String, dynamic>>> stores() => _readList(storeKey);
}

class FavoriteHeart extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isStore;
  final double size;

  const FavoriteHeart({
    super.key,
    required this.item,
    this.isStore = false,
    this.size = 20,
  });

  @override
  State<FavoriteHeart> createState() => _FavoriteHeartState();
}

class _FavoriteHeartState extends State<FavoriteHeart> {
  bool favorite = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = widget.item['id'];
    if (id == null) return;
    final result = widget.isStore
        ? await FavoriteService.isFavoriteStore(id)
        : await FavoriteService.isFavoriteProduct(id);
    if (!mounted) return;
    setState(() => favorite = result);
  }

  Future<void> toggle() async {
    final result = widget.isStore
        ? await FavoriteService.toggleStore(widget.item)
        : await FavoriteService.toggleProduct(widget.item);
    if (!mounted) return;
    setState(() => favorite = result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result ? 'تمت الإضافة إلى المفضلة' : 'تمت الإزالة من المفضلة',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: toggle,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: widget.size + 18,
        height: widget.size + 18,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 8)],
        ),
        child: Icon(
          favorite ? Icons.favorite : Icons.favorite_border,
          color: favorite ? VipTheme.yellowDark : Colors.grey.shade600,
          size: widget.size,
        ),
      ),
    );
  }
}

class FoodxBottomNav extends StatelessWidget {
  final String active;

  const FoodxBottomNav({super.key, required this.active});

  void go(BuildContext context, Widget page, String key) {
    if (active == key) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  Widget item({
    required BuildContext context,
    required String key,
    required IconData icon,
    required String label,
    required Widget page,
  }) {
    final selected = active == key;
    return Expanded(
      child: InkWell(
        onTap: () => go(context, page, key),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? VipTheme.yellowDark : const Color(0xff555555),
              size: 25,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? VipTheme.yellowDark : const Color(0xff555555),
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 6),
      child: Container(
        height: 82,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                item(
                  context: context,
                  key: 'home',
                  icon: Icons.home_rounded,
                  label: 'الرئيسية',
                  page: const HomePage(),
                ),
                item(
                  context: context,
                  key: 'orders',
                  icon: Icons.receipt_long_outlined,
                  label: 'الطلبات',
                  page: const CustomerOrdersPage(),
                ),
                const SizedBox(width: 84),
                item(
                  context: context,
                  key: 'favorites',
                  icon: Icons.favorite_border,
                  label: 'المفضلة',
                  page: const FavoritesPage(),
                ),
                item(
                  context: context,
                  key: 'user',
                  icon: Icons.person_outline,
                  label: 'المستخدم',
                  page: const UserProfilePage(),
                ),
              ],
            ),
            Positioned(
              top: -1,
              child: GestureDetector(
                onTap: () => go(context, const CartPage(), 'cart'),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [VipTheme.yellowLight, VipTheme.yellowDark],
                    ),
                    border: Border.all(color: Colors.white, width: 6),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44d6a640),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.local_grocery_store_rounded,
                    color: active == 'cart' ? Colors.white : VipTheme.navy,
                    size: 31,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerSavedLocation {
  final double? latitude;
  final double? longitude;
  final String address;

  const CustomerSavedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

class CustomerLocationService {
  static const String latKey = 'customer_latitude';
  static const String lngKey = 'customer_longitude';
  static const String addressKey = 'customer_delivery_address';

  static Future<CustomerSavedLocation> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return CustomerSavedLocation(
      latitude: prefs.getDouble(latKey),
      longitude: prefs.getDouble(lngKey),
      address: prefs.getString(addressKey) ?? 'عنوان الزبون التجريبي',
    );
  }

  static Future<void> saveLocation({
    double? latitude,
    double? longitude,
    required String address,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (latitude != null && longitude != null) {
      await prefs.setDouble(latKey, latitude);
      await prefs.setDouble(lngKey, longitude);
    }

    await prefs.setString(addressKey, address);
  }

  static Future<String> reverseGeocodeAddress(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude&accept-language=ar',
      );

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'FoodxCustomerApp/1.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];

        if (address is Map) {
          final parts = <String>[
            address['road']?.toString() ?? '',
            address['suburb']?.toString() ??
                address['neighbourhood']?.toString() ??
                '',
            address['city']?.toString() ??
                address['town']?.toString() ??
                address['village']?.toString() ??
                '',
            address['state']?.toString() ?? '',
          ].where((e) => e.trim().isNotEmpty).toList();

          if (parts.isNotEmpty) {
            return parts.take(3).join('، ');
          }
        }

        final displayName = data['display_name']?.toString();
        if (displayName != null && displayName.trim().isNotEmpty) {
          return displayName.split(',').take(3).join('، ');
        }
      }
    } catch (_) {}

    return 'موقع التوصيل المحدد';
  }

  static Future<Position?> getCurrentGpsLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return null;
    }

    if (permission == LocationPermission.denied) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 15));
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _shineController;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    _introController.forward();
    _shineController.repeat();

    _timer = Timer(const Duration(seconds: 4), _goNext);
  }

  Future<void> _goNext() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => token == null ? const LoginPage() : const HomePage(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  Widget _fallbackWelcome() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffffffff), Color(0xfffffbef), Color(0xfffff4d8)],
        ),
      ),
      child: Center(
        child: Image.asset(
          AppAssets.logo,
          width: 270,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.eco_rounded,
            color: VipTheme.yellowDark,
            size: 150,
          ),
        ),
      ),
    );
  }

  Widget _vipShineOverlay(Size size) {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        final x = -size.width + (size.width * 2.25 * _shineController.value);

        return IgnorePointer(
          child: Transform.translate(
            offset: Offset(x, 0),
            child: Transform.rotate(
              angle: -0.42,
              child: Container(
                width: size.width * 0.38,
                height: size.height * 1.25,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.00),
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _bottomVipGlow() {
    return Positioned(
      left: 35,
      right: 35,
      bottom: 16,
      child: AnimatedBuilder(
        animation: _introController,
        builder: (context, child) {
          final v = Curves.easeOut.transform(_introController.value);
          return Opacity(opacity: .35 * v, child: child);
        },
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(60),
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                VipTheme.yellow.withValues(alpha: .22),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: VipTheme.yellow.withValues(alpha: .18),
                blurRadius: 35,
                spreadRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _skipButton() {
    return Positioned(
      top: 18,
      right: 18,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: _introController,
          builder: (context, child) {
            return Opacity(
              opacity: Curves.easeOut.transform(_introController.value),
              child: child,
            );
          },
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: _goNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .58),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withValues(alpha: .75)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .05),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Text(
                'تخطي',
                style: TextStyle(
                  color: Color(0xff6F5A2A),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xffFFF9ED),
        body: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _introController,
                builder: (context, child) {
                  final v = Curves.easeOutCubic.transform(
                    _introController.value,
                  );
                  return Opacity(
                    opacity: v.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1.035 - (.035 * v),
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  AppAssets.welcomeVip,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallbackWelcome(),
                ),
              ),
            ),

            Positioned.fill(child: _vipShineOverlay(size)),

            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, 0.15),
                      radius: .92,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.white.withValues(alpha: .10),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            _bottomVipGlow(),
            _skipButton(),
          ],
        ),
      ),
    );
  }
}

String buildIraqPhone(String localPhone) {
  String clean = localPhone.replaceAll(RegExp(r'\D'), '');

  if (clean.startsWith('0')) {
    clean = clean.substring(1);
  }

  if (clean.startsWith('964')) {
    clean = clean.substring(3);
  }

  if (clean.length > 10) {
    clean = clean.substring(clean.length - 10);
  }

  return '+964$clean';
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool showPassword = false;

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? validateLocalPhone() {
    final phone = phoneController.text.trim();
    if (phone.length != 10) {
      return 'أدخل رقم الهاتف 10 أرقام بعد مفتاح العراق';
    }
    if (!phone.startsWith('7')) {
      return 'رقم الهاتف يجب أن يبدأ بـ 7';
    }
    return null;
  }

  Future<void> login() async {
    final phoneError = validateLocalPhone();
    final password = passwordController.text.trim();

    if (phoneError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل الرقم السري 6 خانات على الأقل')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final phone = buildIraqPhone(phoneController.text.trim());
      final result = await ApiService.loginWithPassword(
        phone: phone,
        password: password,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (result['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        final authToken = result['token'].toString();
        final user = result['user'] ?? {};

        await prefs.setString('token', authToken);
        await prefs.setString(
          'customer_name',
          (user['name'] ?? 'زبون Foodx').toString(),
        );
        await prefs.setString('customer_phone', phone);

        CustomerNotificationService.saveTokenToServer(
          authToken,
        ).timeout(const Duration(seconds: 10)).catchError((e) {
          debugPrint('CUSTOMER SAVE TOKEN AFTER LOGIN ERROR: $e');
        });

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'فشل تسجيل الدخول')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر الاتصال بالخادم: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget phoneField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 10,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        labelText: 'رقم الهاتف',
        counterText: '',
        prefixIcon: Container(
          width: 82,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(left: 8),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xffeadfbc))),
          ),
          child: const Text(
            '+964',
            style: TextStyle(
              color: VipTheme.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        hintText: '7800000000',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget passwordField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: () => setState(() => showPassword = !showPassword),
          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: 430,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: VipTheme.yellow,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(AppAssets.icon, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: VipTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'أدخل رقم الهاتف والرقم السري',
                        style: TextStyle(color: VipTheme.muted),
                      ),
                      const SizedBox(height: 24),
                      phoneField(phoneController),
                      const SizedBox(height: 12),
                      passwordField(
                        controller: passwordController,
                        label: 'الرقم السري',
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : login,
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'دخول',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              ),
                        child: const Text('إنشاء حساب جديد لأول مرة'),
                      ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              ),
                        child: const Text('نسيت كلمة السر؟'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;
  bool showPassword = false;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String? validateLocalPhone() {
    final phone = phoneController.text.trim();
    if (phone.length != 10) {
      return 'أدخل رقم الهاتف 10 أرقام بعد مفتاح العراق';
    }
    if (!phone.startsWith('7')) {
      return 'رقم الهاتف يجب أن يبدأ بـ 7';
    }
    return null;
  }

  Future<void> sendRegisterOtp() async {
    final name = nameController.text.trim();
    final phoneError = validateLocalPhone();
    final password = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (name.split(RegExp(r'\s+')).where((x) => x.trim().isNotEmpty).length <
        3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل الاسم الثلاثي')));
      return;
    }

    if (phoneError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرقم السري يجب أن يكون 6 خانات على الأقل'),
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تأكيد الرقم السري غير مطابق')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final phone = buildIraqPhone(phoneController.text.trim());
      final result = await ApiService.sendOtp(
        phone,
        purpose: 'register',
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (result['message_id'] != null ||
          result['provider_status'] != null ||
          result['phone'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'تم إرسال رمز التحقق')),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(
              purpose: 'register',
              name: name,
              phone: phone,
              password: password,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'فشل إرسال رمز التحقق')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال الرمز: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget phoneField() {
    return TextField(
      controller: phoneController,
      keyboardType: TextInputType.number,
      maxLength: 10,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        labelText: 'رقم الهاتف',
        counterText: '',
        prefixIcon: Container(
          width: 82,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(left: 8),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xffeadfbc))),
          ),
          child: const Text(
            '+964',
            style: TextStyle(
              color: VipTheme.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        hintText: '7800000000',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget passwordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: () => setState(() => showPassword = !showPassword),
          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إنشاء حساب جديد')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: 430,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_add_alt_1,
                        size: 70,
                        color: VipTheme.yellow,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'تسجيل أول مرة',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الثلاثي',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      phoneField(),
                      const SizedBox(height: 12),
                      passwordField(passwordController, 'الرقم السري'),
                      const SizedBox(height: 12),
                      passwordField(
                        confirmPasswordController,
                        'تأكيد الرقم السري',
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : sendRegisterOtp,
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'إرسال رمز التحقق',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final phoneController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  String? validateLocalPhone() {
    final phone = phoneController.text.trim();
    if (phone.length != 10) {
      return 'أدخل رقم الهاتف 10 أرقام بعد مفتاح العراق';
    }
    if (!phone.startsWith('7')) {
      return 'رقم الهاتف يجب أن يبدأ بـ 7';
    }
    return null;
  }

  Future<void> sendResetOtp() async {
    final phoneError = validateLocalPhone();

    if (phoneError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    setState(() => loading = true);

    try {
      final phone = buildIraqPhone(phoneController.text.trim());
      final result = await ApiService.sendOtp(
        phone,
        purpose: 'reset_password',
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (result['message_id'] != null ||
          result['provider_status'] != null ||
          result['phone'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'تم إرسال رمز التحقق')),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(purpose: 'reset_password', phone: phone),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'فشل إرسال رمز التحقق')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال الرمز: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget phoneField() {
    return TextField(
      controller: phoneController,
      keyboardType: TextInputType.number,
      maxLength: 10,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        labelText: 'رقم الهاتف',
        counterText: '',
        prefixIcon: Container(
          width: 82,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(left: 8),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xffeadfbc))),
          ),
          child: const Text(
            '+964',
            style: TextStyle(
              color: VipTheme.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ),
        hintText: '7800000000',
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('نسيت كلمة السر')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: 430,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_reset,
                        size: 74,
                        color: VipTheme.yellow,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'استعادة كلمة السر',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'أدخل رقم هاتفك، سنرسل لك رمز تحقق ثم تضع كلمة سر جديدة',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VipTheme.muted, height: 1.5),
                      ),
                      const SizedBox(height: 22),
                      phoneField(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : sendResetOtp,
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'إرسال رمز التحقق',
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OtpPage extends StatefulWidget {
  final String purpose;
  final String phone;
  final String? name;
  final String? password;

  const OtpPage({
    super.key,
    required this.purpose,
    required this.phone,
    this.name,
    this.password,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final codeController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool loading = false;
  bool showPassword = false;

  @override
  void dispose() {
    codeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> verify() async {
    final code = codeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل رمز التحقق')));
      return;
    }

    String? password = widget.password;

    if (widget.purpose == 'reset_password') {
      password = newPasswordController.text.trim();
      final confirm = confirmPasswordController.text.trim();

      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('كلمة السر الجديدة يجب أن تكون 6 خانات على الأقل'),
          ),
        );
        return;
      }

      if (password != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تأكيد كلمة السر غير مطابق')),
        );
        return;
      }
    }

    setState(() => loading = true);

    try {
      final result = await ApiService.verifyOtp(
        phone: widget.phone,
        code: code,
        purpose: widget.purpose,
        name: widget.name,
        password: password,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (result['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        final authToken = result['token'].toString();
        final user = result['user'] ?? {};

        await prefs.setString('token', authToken);
        await prefs.setString(
          'customer_name',
          (user['name'] ?? widget.name ?? 'زبون Foodx').toString(),
        );
        await prefs.setString('customer_phone', widget.phone);

        CustomerNotificationService.saveTokenToServer(
          authToken,
        ).timeout(const Duration(seconds: 10)).catchError((e) {
          debugPrint('CUSTOMER SAVE TOKEN AFTER OTP ERROR: $e');
        });

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'فشل التحقق')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر التحقق: $e')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget passwordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: () => setState(() => showPassword = !showPassword),
          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReset = widget.purpose == 'reset_password';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isReset ? 'تعيين كلمة سر جديدة' : 'رمز التحقق'),
          centerTitle: true,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: 430,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sms, size: 70, color: VipTheme.yellow),
                      const SizedBox(height: 15),
                      Text(
                        'تم إرسال الرمز إلى: ${widget.phone}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'رمز OTP',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (isReset) ...[
                        const SizedBox(height: 12),
                        passwordField(
                          newPasswordController,
                          'كلمة السر الجديدة',
                        ),
                        const SizedBox(height: 12),
                        passwordField(
                          confirmPasswordController,
                          'تأكيد كلمة السر الجديدة',
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : verify,
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isReset
                                      ? 'حفظ كلمة السر والدخول'
                                      : 'تحقق ودخول',
                                  style: const TextStyle(fontSize: 18),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData mainTypeIconByName(String name) {
  final n = name.trim();

  if (n.contains('مطعم') ||
      n.contains('اكل') ||
      n.contains('أكل') ||
      n.contains('وجبات') ||
      n.contains('طعام')) {
    return Icons.restaurant_menu_rounded;
  }

  if (n.contains('سوبر') ||
      n.contains('ماركت') ||
      n.contains('بقال') ||
      n.contains('مواد')) {
    return Icons.local_grocery_store_rounded;
  }

  if (n.contains('انش') ||
      n.contains('إنش') ||
      n.contains('بناء') ||
      n.contains('عدد') ||
      n.contains('كهرباء') ||
      n.contains('سباكة')) {
    return Icons.construction_rounded;
  }

  if (n.contains('سيار') ||
      n.contains('كراج') ||
      n.contains('إطارات') ||
      n.contains('اطارات')) {
    return Icons.directions_car_filled_rounded;
  }

  if (n.contains('صيد') || n.contains('دواء') || n.contains('طبي')) {
    return Icons.local_pharmacy_rounded;
  }

  if (n.contains('حلوي') || n.contains('حلو') || n.contains('كيك')) {
    return Icons.cake_rounded;
  }

  if (n.contains('مشروب') || n.contains('كاف') || n.contains('قهوة')) {
    return Icons.local_cafe_rounded;
  }

  if (n.contains('ملابس') || n.contains('ازياء') || n.contains('أزياء')) {
    return Icons.checkroom_rounded;
  }

  if (n.contains('الكتر') ||
      n.contains('إلكتر') ||
      n.contains('موبايل') ||
      n.contains('هاتف')) {
    return Icons.devices_rounded;
  }

  if (n.contains('منزل') || n.contains('اثاث') || n.contains('أثاث')) {
    return Icons.chair_rounded;
  }

  return Icons.category_rounded;
}

List<Color> mainTypeGradientByName(String name) {
  final n = name.trim();

  if (n.contains('مطعم') ||
      n.contains('اكل') ||
      n.contains('أكل') ||
      n.contains('وجبات') ||
      n.contains('طعام')) {
    return const [Color(0xffffc107), Color(0xffff8f00)];
  }

  if (n.contains('سوبر') ||
      n.contains('ماركت') ||
      n.contains('بقال') ||
      n.contains('مواد')) {
    return const [Color(0xff22c55e), Color(0xff16a34a)];
  }

  if (n.contains('انش') ||
      n.contains('إنش') ||
      n.contains('بناء') ||
      n.contains('عدد') ||
      n.contains('كهرباء') ||
      n.contains('سباكة')) {
    return const [Color(0xff64748b), Color(0xff334155)];
  }

  if (n.contains('سيار') ||
      n.contains('كراج') ||
      n.contains('إطارات') ||
      n.contains('اطارات')) {
    return const [Color(0xff38bdf8), Color(0xff0284c7)];
  }

  if (n.contains('صيد') || n.contains('دواء') || n.contains('طبي')) {
    return const [Color(0xff34d399), Color(0xff059669)];
  }

  if (n.contains('حلوي') || n.contains('حلو') || n.contains('كيك')) {
    return const [Color(0xffff8ab3), Color(0xffec4899)];
  }

  if (n.contains('مشروب') || n.contains('كاف') || n.contains('قهوة')) {
    return const [Color(0xffd97706), Color(0xff92400e)];
  }

  if (n.contains('ملابس') || n.contains('ازياء') || n.contains('أزياء')) {
    return const [Color(0xffa78bfa), Color(0xff7c3aed)];
  }

  if (n.contains('الكتر') ||
      n.contains('إلكتر') ||
      n.contains('موبايل') ||
      n.contains('هاتف')) {
    return const [Color(0xff60a5fa), Color(0xff2563eb)];
  }

  return const [Color(0xffffc107), Color(0xffffb300)];
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;
  List stores = [];
  List filteredStores = [];
  List storeTypes = [];
  List offers = [];
  List latestProducts = [];
  int? selectedTypeId;
  final searchController = TextEditingController();
  final PageController offersController = PageController(
    viewportFraction: 0.90,
  );
  Timer? offersTimer;
  String savedAddress = 'لم يتم تحديد الموقع';
  bool locating = false;

  @override
  void initState() {
    super.initState();
    saveNotificationTokenAgain();
    loadSavedLocation();
    loadHome();
  }

  @override
  void dispose() {
    offersTimer?.cancel();
    offersController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> saveNotificationTokenAgain() async {
    try {
      final token = await getSavedToken();

      if (token.isEmpty) {
        return;
      }

      await CustomerNotificationService.saveTokenToServer(
        token,
      ).timeout(const Duration(seconds: 10));

      debugPrint("CUSTOMER FCM TOKEN SAVED FROM HOME");
    } catch (e) {
      debugPrint("CUSTOMER FCM TOKEN SAVE FROM HOME ERROR: $e");
    }
  }

  Future<void> loadHome() async {
    final result = await ApiService.home();
    if (!mounted) return;
    setState(() {
      stores = result["stores"] ?? [];
      filteredStores = stores;
      storeTypes = result["store_types"] ?? [];
      offers = result["offers"] ?? [];
      latestProducts = result["latest_products"] ?? [];
      loading = false;
    });
    startOffersAutoSlide();
  }

  void startOffersAutoSlide() {
    offersTimer?.cancel();
    if (offers.length <= 1) return;

    offersTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !offersController.hasClients) return;
      final current = offersController.page?.round() ?? 0;
      final next = (current + 1) % offers.length;
      offersController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void applyFilters() {
    final q = searchController.text.trim();
    setState(() {
      filteredStores = stores.where((store) {
        final name = (store["name"] ?? "").toString();
        final address = (store["address"] ?? "").toString();
        final typeId = store["store_type_id"];
        final matchesSearch =
            q.isEmpty || name.contains(q) || address.contains(q);
        final matchesType = selectedTypeId == null || typeId == selectedTypeId;
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  Future<void> loadSavedLocation() async {
    final location = await CustomerLocationService.getSavedLocation();
    if (!mounted) return;
    setState(() => savedAddress = location.address);
  }

  Future<void> updateLocationFromGps() async {
    if (locating) return;
    setState(() => locating = true);

    try {
      final position = await CustomerLocationService.getCurrentGpsLocation();

      if (!mounted) return;

      if (position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحديد الموقع. فعّل GPS والصلاحيات.'),
          ),
        );
        return;
      }

      final address = await CustomerLocationService.reverseGeocodeAddress(
        position.latitude,
        position.longitude,
      );

      await CustomerLocationService.saveLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      setState(() => savedAddress = address);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث موقع التوصيل بنجاح')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تحديد الموقع حالياً')));
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> openManualAddressDialog() async {
    final controller = TextEditingController(text: savedAddress);

    final address = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تحديد عنوان يدوي'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'اكتب عنوان التوصيل',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (address == null || address.isEmpty) return;

    await CustomerLocationService.saveLocation(address: address);

    if (!mounted) return;
    setState(() => savedAddress = address);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ العنوان اليدوي')));
  }

  Future<void> openMapPicker() async {
    final picked = await Navigator.push<CustomerSavedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );

    if (picked == null) return;

    await CustomerLocationService.saveLocation(
      latitude: picked.latitude,
      longitude: picked.longitude,
      address: picked.address,
    );

    if (!mounted) return;
    setState(() => savedAddress = picked.address);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حفظ الموقع المحدد')));
  }

  Future<void> openLocationSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.my_location,
                    color: Color(0xffffc107),
                  ),
                  title: const Text('تحديث موقعي الحالي GPS'),
                  subtitle: const Text('يستخدم موقع الهاتف الحالي للتوصيل'),
                  onTap: () {
                    Navigator.pop(context);
                    updateLocationFromGps();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map, color: Color(0xffffc107)),
                  title: const Text('تحديد يدوي على الخريطة'),
                  subtitle: const Text('اختر نقطة التوصيل من الخريطة'),
                  onTap: () {
                    Navigator.pop(context);
                    openMapPicker();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.edit_location_alt,
                    color: Color(0xffffc107),
                  ),
                  title: const Text('كتابة عنوان يدوي'),
                  subtitle: const Text('يستخدم العنوان النصي إذا تعذر GPS'),
                  onTap: () {
                    Navigator.pop(context);
                    openManualAddressDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  Widget topHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: const BoxDecoration(color: VipTheme.page),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerNotificationsPage(),
                  ),
                ),
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xff6b3d00),
                        size: 27,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 8,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: VipTheme.yellow,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مطاعم، منتجات، وأكثر',
                    hintStyle: const TextStyle(color: Color(0xff9ca3af)),
                    suffixIcon: const Icon(
                      Icons.search,
                      color: Color(0xff666666),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xfff1e7cf)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xfff1e7cf)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: openLocationSheet,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: VipTheme.yellowDark,
                  size: 30,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    savedAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xff6b7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xff6b3d00),
                ),
                if (locating)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VipTheme.yellowDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget offersSection() {
    if (offers.isEmpty) {
      return Container(
        height: 155,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [VipTheme.royal, VipTheme.blue],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: VipTheme.blue.withValues(alpha: .22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'عروض Foodx المميزة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 165,
      child: PageView.builder(
        controller: offersController,
        padEnds: false,
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          final image = offer['image'];
          return Container(
            margin: EdgeInsets.only(right: index == 0 ? 16 : 8, left: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [VipTheme.navy, VipTheme.royal],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33123d72),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
              image: image != null
                  ? DecorationImage(
                      image: NetworkImage(productImageUrl(image)),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.35),
                        BlendMode.darken,
                      ),
                    )
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  offer['title'] ?? 'عرض خاص',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget typeItem(dynamic type) {
    final selected = selectedTypeId == type['id'];
    final name = type['name']?.toString() ?? '';
    final iconUrl = dynamicImageUrl(type, [
      'icon',
      'icon_url',
      'image',
      'image_url',
      'photo',
      'photo_url',
      'logo',
      'logo_url',
      'category_icon',
      'type_icon',
      'store_type_icon',
      'icon_path',
      'thumbnail',
    ]);

    final fallbackIcon = mainTypeIconByName(name);
    final gradientColors = mainTypeGradientByName(name);

    return GestureDetector(
      onTap: () {
        setState(() => selectedTypeId = selected ? null : type['id']);
        applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 96,
        margin: const EdgeInsets.only(left: 12),
        padding: const EdgeInsets.fromLTRB(9, 10, 9, 8),
        decoration: BoxDecoration(
          color: selected ? VipTheme.yellow : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: selected ? VipTheme.yellowDark : const Color(0xffffe8a3),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0x33ffb300)
                  : const Color(0x10000000),
              blurRadius: selected ? 18 : 12,
              offset: Offset(0, selected ? 9 : 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: selected ? 58 : 54,
              height: selected ? 58 : 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: selected
                      ? const [Colors.white, Color(0xfffff4cc)]
                      : gradientColors,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 13,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: iconUrl != null
                  ? ClipOval(
                      child: Image.network(
                        iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          fallbackIcon,
                          color: selected ? VipTheme.yellowDark : Colors.white,
                          size: 28,
                        ),
                      ),
                    )
                  : Icon(
                      fallbackIcon,
                      color: selected ? VipTheme.yellowDark : Colors.white,
                      size: 28,
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : VipTheme.navy,
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget typesSection() {
    return SizedBox(
      height: 116,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          GestureDetector(
            onTap: () {
              setState(() => selectedTypeId = null);
              applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 96,
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.fromLTRB(9, 10, 9, 8),
              decoration: BoxDecoration(
                color: selectedTypeId == null ? VipTheme.yellow : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: selectedTypeId == null
                      ? VipTheme.yellowDark
                      : const Color(0xffffe8a3),
                  width: selectedTypeId == null ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selectedTypeId == null
                        ? const Color(0x33ffb300)
                        : const Color(0x10000000),
                    blurRadius: selectedTypeId == null ? 18 : 12,
                    offset: Offset(0, selectedTypeId == null ? 9 : 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: selectedTypeId == null ? 58 : 54,
                    height: selectedTypeId == null ? 58 : 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selectedTypeId == null
                          ? const LinearGradient(
                              colors: [Colors.white, Color(0xfffff4cc)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xffffc107), Color(0xffff8f00)],
                            ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 13,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.dashboard_customize_rounded,
                      color: selectedTypeId == null
                          ? VipTheme.yellowDark
                          : Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الكل',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selectedTypeId == null
                          ? Colors.white
                          : VipTheme.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...storeTypes.map<Widget>((type) => typeItem(type)),
        ],
      ),
    );
  }

  Widget storeCard(dynamic store) {
    final map = Map<String, dynamic>.from(store as Map);
    final isOpen = map['is_open'] == 1 || map['is_open'] == true;
    final typeName = storeTypeName(map);
    final logoUrl = dynamicImageUrl(map, [
      'logo',
      'logo_url',
      'store_logo',
      'store_icon',
      'icon',
      'icon_url',
      'image',
      'image_url',
      'photo',
      'photo_url',
      'thumbnail',
    ]);
    final rating = storeRating(map);
    final deliveryTime = storeDeliveryTime(map);
    final address = storeAddress(map);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StoreDetailsPage(storeId: map['id'])),
      ),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xfffff3cd),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: logoUrl == null
                    ? const Icon(
                        Icons.storefront,
                        color: VipTheme.yellowDark,
                        size: 40,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(logoUrl, fit: BoxFit.cover),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map['name']?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      typeName.isEmpty ? address : '$typeName • $address',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: VipTheme.yellowDark,
                          size: 18,
                        ),
                        Text(
                          deliveryTime,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const Icon(
                          Icons.star,
                          color: VipTheme.yellowDark,
                          size: 18,
                        ),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          isOpen ? 'مفتوح' : 'مغلق',
                          style: TextStyle(
                            color: isOpen ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              FavoriteHeart(item: map, isStore: true, size: 19),
            ],
          ),
        ),
      ),
    );
  }

  Widget latestProductCard(dynamic product) {
    final map = Map<String, dynamic>.from(product as Map);
    final image = map['image'];
    final storeName = map['store']?['name'] ?? map['store_name'] ?? 'متجر';
    final categoryName =
        map['category']?['name'] ?? map['category_name'] ?? 'قسم';
    final storeId = map['store_id'];

    return GestureDetector(
      onTap: storeId == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StoreDetailsPage(storeId: storeId),
              ),
            ),
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: image != null
                      ? Image.network(
                          productImageUrl(image),
                          width: 165,
                          height: 105,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 165,
                          height: 105,
                          color: const Color(0xfffff3cd),
                          child: const Icon(
                            Icons.fastfood,
                            color: VipTheme.yellowDark,
                            size: 38,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        map['name']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$categoryName • $storeName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VipTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${map['price']} د.ع',
                        style: const TextStyle(
                          color: VipTheme.yellowDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              left: 8,
              child: FavoriteHeart(item: map, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  Widget latestProductsSection() {
    if (latestProducts.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'المنتجات المضافة حديثاً',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 205,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: latestProducts.length,
            itemBuilder: (context, index) =>
                latestProductCard(latestProducts[index]),
          ),
        ),
      ],
    );
  }

  Widget homeBottomBar() {
    return const FoodxBottomNav(active: 'home');
  }

  Future<void> openProfileSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('customer_name') ?? 'زبون Foodx';
    final phone = prefs.getString('customer_phone') ?? 'غير معروف';

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xfffff3cd),
                      child: Icon(Icons.person, color: VipTheme.blue, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            phone,
                            style: const TextStyle(color: VipTheme.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                ListTile(
                  leading: const Icon(
                    Icons.support_agent,
                    color: VipTheme.royal,
                  ),
                  title: const Text('الدعم والمحادثة'),
                  subtitle: const Text('محادثة مباشرة مع إدارة Foodx'),
                  onTap: () {
                    Navigator.pop(context);
                    if (mounted) {
                      Navigator.of(this.context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportChatPage(),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: VipTheme.royal),
                  title: const Text('إعدادات مستقبلية'),
                  subtitle: const Text('يمكن إضافة أزرار أخرى لاحقاً'),
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('تسجيل الخروج'),
                  onTap: () {
                    Navigator.pop(context);
                    logout();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: VipTheme.page,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: loadHome,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 90),
                  children: [
                    topHeader(),
                    const SizedBox(height: 18),
                    offersSection(),
                    const SizedBox(height: 22),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "الأقسام",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    typesSection(),
                    const SizedBox(height: 20),
                    latestProductsSection(),
                    const SizedBox(height: 18),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "المتاجر القريبة",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (filteredStores.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text("لا توجد متاجر")),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: filteredStores
                              .map<Widget>((store) => storeCard(store))
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
        bottomNavigationBar: homeBottomBar(),
      ),
    );
  }
}

class SocialLinksPage extends StatefulWidget {
  const SocialLinksPage({super.key});

  @override
  State<SocialLinksPage> createState() => _SocialLinksPageState();
}

class _SocialLinksPageState extends State<SocialLinksPage> {
  bool loading = true;
  Map<String, String> links = {};

  @override
  void initState() {
    super.initState();
    loadLinks();
  }

  Future<void> loadLinks() async {
    try {
      final data = await ApiService.appSettings();
      final app = data['app'];
      final social = app is Map ? app['social_links'] : null;
      if (!mounted) return;
      setState(() {
        links = {
          'facebook':
              (social is Map ? social['facebook'] : '')?.toString().trim() ??
              '',
          'instagram':
              (social is Map ? social['instagram'] : '')?.toString().trim() ??
              '',
          'whatsapp':
              (social is Map ? social['whatsapp'] : '')?.toString().trim() ??
              '',
          'website':
              (social is Map ? social['website'] : '')?.toString().trim() ?? '',
        };
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  String normalizeWhatsapp(String value) {
    var text = value.trim();
    if (text.isEmpty) return text;
    if (text.startsWith('http://') || text.startsWith('https://')) return text;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return text;
    final number = digits.startsWith('964')
        ? digits
        : '964${digits.startsWith('0') ? digits.substring(1) : digits}';
    return 'https://wa.me/$number';
  }

  Future<void> openExternal(String rawUrl) async {
    var value = rawUrl.trim();
    if (value.isEmpty) return;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط حالياً')));
    }
  }

  Widget socialTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String url,
    Color color = VipTheme.yellowDark,
  }) {
    final enabled = url.trim().isNotEmpty;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? () => openExternal(url) : null,
        leading: CircleAvatar(
          backgroundColor: const Color(0xfffff4d6),
          child: Icon(icon, color: enabled ? color : Colors.grey),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: enabled ? VipTheme.navy : Colors.grey,
          ),
        ),
        trailing: const Icon(Icons.open_in_new_rounded, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facebook = links['facebook'] ?? '';
    final instagram = links['instagram'] ?? '';
    final whatsapp = normalizeWhatsapp(links['whatsapp'] ?? '');
    final website = links['website'] ?? '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: VipTheme.page,
        appBar: AppBar(
          title: const Text('تابعنا على صفحاتنا'),
          centerTitle: true,
        ),
        bottomNavigationBar: const FoodxBottomNav(active: 'user'),
        body: SafeArea(
          top: false,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: loadLinks,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    children: [
                      socialTile(
                        icon: Icons.facebook,
                        title: 'صفحتنا على فيسبوك',
                        subtitle: 'افتح صفحة فودكس على Facebook',
                        url: facebook,
                        color: const Color(0xff1877f2),
                      ),
                      socialTile(
                        icon: Icons.camera_alt_outlined,
                        title: 'صفحتنا على انستغرام',
                        subtitle: 'افتح حساب فودكس على Instagram',
                        url: instagram,
                        color: const Color(0xffc13584),
                      ),
                      socialTile(
                        icon: Icons.chat_rounded,
                        title: 'راسلنا على واتساب',
                        subtitle: 'افتح محادثة واتساب مباشرة',
                        url: whatsapp,
                        color: const Color(0xff25d366),
                      ),
                      socialTile(
                        icon: Icons.language_rounded,
                        title: 'الموقع الإلكتروني',
                        subtitle: 'افتح الموقع الرسمي لفودكس',
                        url: website,
                        color: const Color(0xff0f766e),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String name = 'زبون Foodx';
  String phone = 'غير معروف';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      name = prefs.getString('customer_name') ?? 'زبون Foodx';
      phone = prefs.getString('customer_phone') ?? 'غير معروف';
    });
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget menuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: color ?? Colors.black54,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: color ?? VipTheme.navy,
          ),
        ),
        trailing: CircleAvatar(
          backgroundColor: const Color(0xfffff4d6),
          child: Icon(icon, color: color ?? VipTheme.yellowDark),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: VipTheme.page,
        bottomNavigationBar: const FoodxBottomNav(active: 'user'),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [VipTheme.yellow, VipTheme.yellowDark],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33ffc107),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        color: VipTheme.yellowDark,
                        size: 54,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                              color: VipTheme.navy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff5f4200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              menuItem(
                icon: Icons.notifications_none,
                title: 'الإشعارات',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerNotificationsPage(),
                  ),
                ),
              ),
              menuItem(
                icon: Icons.support_agent,
                title: 'الدعم',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SupportChatPage()),
                ),
              ),
              menuItem(
                icon: Icons.public_rounded,
                title: 'تابعنا على صفحاتنا',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SocialLinksPage()),
                ),
              ),
              menuItem(
                icon: Icons.info_outline,
                title: 'من نحن',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutFoodxPage()),
                ),
              ),
              menuItem(
                icon: Icons.settings_outlined,
                title: 'الإعدادات',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
              menuItem(
                icon: Icons.star_border_rounded,
                title: 'تقييم التطبيق',
                onTap: () => showAppRatingDialog(context),
              ),
              const PrivacyPolicyButton(),
              menuItem(
                icon: Icons.logout,
                title: 'تسجيل الخروج',
                color: Colors.red,
                onTap: logout,
              ),
              const SizedBox(height: 18),
              Opacity(
                opacity: .18,
                child: Center(
                  child: Image.asset(
                    AppAssets.companyLogo,
                    width: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> stores = [];

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final p = await FavoriteService.products();
    final s = await FavoriteService.stores();
    if (!mounted) return;
    setState(() {
      products = p;
      stores = s;
    });
  }

  Widget productTile(Map<String, dynamic> product) {
    final imageUrl = dynamicImageUrl(product, ['image', 'photo', 'icon']);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: imageUrl == null
            ? const CircleAvatar(
                backgroundColor: Color(0xfffff3cd),
                child: Icon(Icons.fastfood, color: VipTheme.yellowDark),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(
          product['name']?.toString() ?? 'منتج',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${product['price'] ?? ''} د.ع'),
        trailing: FavoriteHeart(item: product),
      ),
    );
  }

  Widget storeTile(Map<String, dynamic> store) {
    final logoUrl = dynamicImageUrl(store, [
      'logo',
      'logo_url',
      'store_logo',
      'store_icon',
      'icon',
      'icon_url',
      'image',
      'image_url',
      'photo',
      'photo_url',
      'thumbnail',
    ]);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: store['id'] == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreDetailsPage(storeId: store['id']),
                ),
              ),
        leading: logoUrl == null
            ? const CircleAvatar(
                backgroundColor: Color(0xfffff3cd),
                child: Icon(Icons.storefront, color: VipTheme.yellowDark),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  logoUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(
          store['name']?.toString() ?? 'متجر',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(storeAddress(store)),
        trailing: FavoriteHeart(item: store, isStore: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: VipTheme.page,
        bottomNavigationBar: const FoodxBottomNav(active: 'favorites'),
        appBar: AppBar(title: const Text('المفضلة'), centerTitle: true),
        body: RefreshIndicator(
          onRefresh: loadFavorites,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              const Text(
                'المتاجر المفضلة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (stores.isEmpty)
                const Text('لا توجد متاجر مفضلة')
              else
                ...stores.map(storeTile),
              const SizedBox(height: 24),
              const Text(
                'المنتجات المفضلة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (products.isEmpty)
                const Text('لا توجد منتجات مفضلة')
              else
                ...products.map(productTile),
            ],
          ),
        ),
      ),
    );
  }
}

class AboutFoodxPage extends StatelessWidget {
  const AboutFoodxPage({super.key});

  Widget section({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xfffff4d6),
              child: Icon(icon, color: VipTheme.yellowDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: VipTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget p(String text) => Text(
    text,
    style: const TextStyle(
      height: 1.65,
      fontSize: 15.5,
      color: Color(0xff2f2f2f),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: VipTheme.page,
        appBar: AppBar(title: const Text('من نحن'), centerTitle: true),
        bottomNavigationBar: const FoodxBottomNav(active: 'user'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Image.asset(AppAssets.logo, height: 92, fit: BoxFit.contain),
                  const SizedBox(height: 12),
                  const Text(
                    'مرحباً بك في فودكس',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: VipTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  p(
                    'منصتك الذكية للتسوق الإلكتروني بكل سهولة وأمان. نحن نعمل على توفير تجربة تسوق مريحة وسريعة تتيح لك تصفح المنتجات، اختيار ما يناسبك، وإتمام الطلب بخطوات بسيطة، مع خدمة توصيل موثوقة تصل إلى باب منزلك.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            section(
              icon: Icons.flag_outlined,
              title: 'هدفنا',
              child: p(
                'ربط الزبائن بالمتاجر والمحلات بطريقة حديثة وسهلة، مع توفير منتجات متنوعة، أسعار مناسبة، وخدمة عملاء تهتم براحتك ورضاك.',
              ),
            ),
            section(
              icon: Icons.remove_red_eye_outlined,
              title: 'رؤيتنا',
              child: p(
                'أن نكون من أفضل منصات التسوق الإلكتروني التي توفر للزبائن تجربة سهلة وآمنة وموثوقة.',
              ),
            ),
            section(
              icon: Icons.rocket_launch_outlined,
              title: 'رسالتنا',
              child: p(
                'تقديم خدمة تسوق إلكتروني متكاملة تجمع بين جودة المنتجات، سرعة التوصيل، وسهولة الاستخدام.',
              ),
            ),
            section(
              icon: Icons.verified_user_outlined,
              title: 'لماذا تختارنا؟',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('• سهولة تصفح المنتجات والطلب.'),
                  Text('• متاجر ومنتجات متنوعة.'),
                  Text('• توصيل سريع وموثوق.'),
                  Text('• دعم ومتابعة للطلبات.'),
                  Text('• تجربة استخدام بسيطة وآمنة.'),
                ],
              ),
            ),
            section(
              icon: Icons.shopping_bag_outlined,
              title: 'نص مختصر',
              child: p(
                'فودكس هو تطبيق تسوق إلكتروني يهدف إلى تسهيل عملية الشراء من المتاجر والمحلات، مع توفير تجربة سهلة وآمنة وخدمة توصيل موثوقة للزبائن.',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [VipTheme.yellow, VipTheme.yellowDark],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          AppAssets.companyLogo,
                          height: 42,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'AH SoftTech',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: VipTheme.navy,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [VipTheme.yellow, VipTheme.yellowDark],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Developer:\nAtheer 07876119151',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VipTheme.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String name = 'زبون Foodx';

  @override
  void initState() {
    super.initState();
    loadName();
  }

  Future<void> loadName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => name = prefs.getString('customer_name') ?? 'زبون Foodx');
  }

  Future<void> editName() async {
    final controller = TextEditingController(text: name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل الاسم'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customer_name', result);
    if (!mounted) return;
    setState(() => name = result);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تعديل الاسم محلياً')));
  }

  Widget item({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: CircleAvatar(
          backgroundColor: const Color(0xfffff4d6),
          child: Icon(icon, color: VipTheme.yellowDark),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: VipTheme.page,
        appBar: AppBar(title: const Text('الإعدادات'), centerTitle: true),
        bottomNavigationBar: const FoodxBottomNav(active: 'user'),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            item(
              icon: Icons.person_outline,
              title: 'تعديل اسم المستخدم',
              subtitle: name,
              onTap: editName,
            ),
            item(
              icon: Icons.lock_outline,
              title: 'تغيير كلمة السر',
              subtitle: 'من صفحة نسيت كلمة السر يمكنك تعيين كلمة جديدة',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
              ),
            ),
            item(
              icon: Icons.key_outlined,
              title: 'نسيت كلمة السر؟',
              subtitle: 'استعادة كلمة المرور عبر OTP',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
              ),
            ),
            item(
              icon: Icons.star_border_rounded,
              title: 'تقييم التطبيق',
              subtitle: 'شارك رأيك وساعدنا على التطوير',
              onTap: () => showAppRatingDialog(context),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAppRatingDialog(BuildContext context) async {
  int rating = 5;
  await showDialog(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('تقييم التطبيق'),
            content: Wrap(
              alignment: WrapAlignment.center,
              spacing: 0,
              runSpacing: 0,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: () => setDialogState(() => rating = value),
                  icon: Icon(
                    value <= rating ? Icons.star : Icons.star_border,
                    color: VipTheme.yellowDark,
                  ),
                );
              }),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('شكراً لتقييمك: $rating نجوم')),
                  );
                },
                child: const Text('إرسال'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class CustomerNotificationsPage extends StatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  State<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends State<CustomerNotificationsPage> {
  bool loading = true;
  List notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() => loading = true);

    final token = await getSavedToken();

    if (token.isEmpty) {
      if (!mounted) return;
      setState(() {
        notifications = [];
        loading = false;
      });
      return;
    }

    final result = await ApiService.customerNotifications(token);

    if (!mounted) return;

    final data = result['notifications'] ?? result['data'] ?? [];

    setState(() {
      notifications = data is List ? data : [];
      loading = false;
    });
  }

  Future<void> deleteNotification(dynamic notification) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'خيارات الإشعار',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.red),
                    title: const Text('حذف الإشعار'),
                    onTap: () => Navigator.pop(context, true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.close),
                    title: const Text('إلغاء'),
                    onTap: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    final token = await getSavedToken();
    final id = notification['id'];

    final result = await ApiService.deleteCustomerNotification(token, id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? 'تم حذف الإشعار')),
    );

    await loadNotifications();
  }

  String formatDate(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      final h = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');

      return '$y-$m-$d  $h:$min';
    } catch (_) {
      return value.toString();
    }
  }

  Widget notificationCard(dynamic notification) {
    final title = notification['title'] ?? 'إشعار';
    final body = notification['body'] ?? '';
    final createdAt = notification['created_at'];

    return GestureDetector(
      onLongPress: () => deleteNotification(notification),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xfffff3cd),
                child: Icon(Icons.notifications, color: Color(0xffffc107)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body.toString(),
                      style: const TextStyle(
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formatDate(createdAt),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'اضغط مطولاً للحذف',
                      style: TextStyle(color: Colors.black38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        bottomNavigationBar: const FoodxBottomNav(active: 'user'),
        appBar: AppBar(
          title: const Text('الإشعارات'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: loadNotifications,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : notifications.isEmpty
            ? const Center(child: Text('لا توجد إشعارات حالياً'))
            : RefreshIndicator(
                onRefresh: loadNotifications,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return notificationCard(notifications[index]);
                  },
                ),
              ),
      ),
    );
  }
}

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  bool loading = true;
  bool sending = false;
  List messages = [];
  Timer? refreshTimer;
  final messageController = TextEditingController();
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadMessages();
    refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      loadMessages(showLoading: false);
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadMessages({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => loading = true);
    }

    try {
      final token = await getSavedToken();

      if (token.isEmpty) {
        if (!mounted) return;
        setState(() {
          messages = [];
          loading = false;
        });
        return;
      }

      final result = await ApiService.supportMessages(
        token,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      final rawMessages = result['messages'] ?? [];

      setState(() {
        messages = rawMessages is List ? rawMessages : [];
        loading = false;
      });

      scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      if (showLoading) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحميل المحادثة: $e')));
      }
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty || sending) {
      return;
    }

    setState(() => sending = true);
    messageController.clear();

    try {
      final token = await getSavedToken();

      if (token.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تسجيل الدخول أولاً')),
        );
        return;
      }

      final result = await ApiService.sendSupportMessage(
        token,
        text,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      if (result['support_message'] == null && result['message'] == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('لم يتم إرسال الرسالة')));
      }

      await loadMessages(showLoading: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  String formatChatDate(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return value.toString();
    }
  }

  Widget messageBubble(dynamic msg) {
    final senderType = (msg['sender_type'] ?? '').toString();
    final isCustomer = senderType == 'customer';
    final text = (msg['message'] ?? '').toString();
    final createdAt = msg['created_at'];

    return Align(
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * .76,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: isCustomer
              ? const LinearGradient(colors: [VipTheme.blue, VipTheme.royal])
              : null,
          color: isCustomer ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topRight: const Radius.circular(18),
            topLeft: const Radius.circular(18),
            bottomRight: Radius.circular(isCustomer ? 4 : 18),
            bottomLeft: Radius.circular(isCustomer ? 18 : 4),
          ),
          border: isCustomer
              ? null
              : Border.all(color: const Color(0xffe5e7eb)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isCustomer ? 'أنت' : 'إدارة Foodx',
              style: TextStyle(
                color: isCustomer ? Colors.white70 : VipTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                color: isCustomer ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                formatChatDate(createdAt),
                style: TextStyle(
                  color: isCustomer ? Colors.white60 : Colors.black38,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget emptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: VipTheme.goldLight.withValues(alpha: .28),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.support_agent,
                size: 44,
                color: VipTheme.gold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'أهلاً بك في دعم Foodx',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'اكتب رسالتك للإدارة وسيتم الرد عليك من لوحة التحكم.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VipTheme.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget inputBox() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x16000000),
              blurRadius: 16,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك هنا...',
                  filled: true,
                  fillColor: const Color(0xfff3f4f6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: sending ? null : sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [VipTheme.goldLight, VipTheme.gold],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33d6a640), blurRadius: 12),
                  ],
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VipTheme.navy,
                        ),
                      )
                    : const Icon(Icons.send, color: VipTheme.navy),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        bottomNavigationBar: const FoodxBottomNav(active: 'user'),
        backgroundColor: VipTheme.page,
        appBar: AppBar(
          title: const Text('الدعم والمحادثة'),
          centerTitle: true,
          backgroundColor: VipTheme.navy,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: () => loadMessages(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [VipTheme.navy, VipTheme.royal],
                ),
              ),
              child: const Text(
                'يمكنك إرسال أي مشكلة أو استفسار للإدارة هنا',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                  ? emptyChat()
                  : RefreshIndicator(
                      onRefresh: () => loadMessages(),
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(14),
                        itemCount: messages.length,
                        itemBuilder: (context, index) =>
                            messageBubble(messages[index]),
                      ),
                    ),
            ),
            inputBox(),
          ],
        ),
      ),
    );
  }
}

class StoreDetailsPage extends StatefulWidget {
  final int storeId;
  const StoreDetailsPage({super.key, required this.storeId});

  @override
  State<StoreDetailsPage> createState() => _StoreDetailsPageState();
}

class _StoreDetailsPageState extends State<StoreDetailsPage> {
  bool loading = true;
  Map<String, dynamic>? store;
  List categories = [];
  int selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    loadStore();
  }

  Future<void> loadStore() async {
    final result = await ApiService.storeDetails(widget.storeId);
    setState(() {
      store = result["store"];
      categories = result["categories"] ?? [];
      loading = false;
    });
  }

  Future<void> showAddToCartDialog(dynamic product) async {
    final variants = product["variants"] ?? [];
    int quantity = 1;
    int? selectedVariantId;
    double price = double.tryParse(product["price"].toString()) ?? 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      product["name"] ?? "",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product["description"] ?? "",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    if (variants.isNotEmpty) ...[
                      const Text(
                        "اختر الحجم",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...variants.map<Widget>((variant) {
                        final id = variant["id"];
                        final vPrice =
                            double.tryParse(variant["price"].toString()) ??
                            price;
                        return RadioListTile<int>(
                          value: id,
                          groupValue: selectedVariantId,
                          title: Text(variant["name"] ?? ""),
                          subtitle: Text("${variant["price"]} د.ع"),
                          onChanged: (value) {
                            setSheetState(() {
                              selectedVariantId = value;
                              price = vPrice;
                            });
                          },
                        );
                      }).toList(),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          "الكمية",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: quantity > 1
                              ? () => setSheetState(() => quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          "$quantity",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setSheetState(() => quantity++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart),
                        label: Text("إضافة للسلة - ${price * quantity} د.ع"),
                        onPressed: () async {
                          final token = await getSavedToken();
                          if (token.isEmpty) {
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("يرجى تسجيل الدخول أولاً"),
                              ),
                            );
                            return;
                          }

                          final result = await ApiService.addToCart(
                            token,
                            storeId: widget.storeId,
                            productId: product["id"],
                            productVariantId: selectedVariantId,
                            quantity: quantity,
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result["message"] ?? "تمت الإضافة للسلة",
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget storeHeader() {
    final logoUrl = dynamicImageUrl(store, [
      'logo',
      'logo_url',
      'store_logo',
      'store_icon',
      'icon',
      'icon_url',
      'image',
      'image_url',
      'photo',
      'photo_url',
      'thumbnail',
    ]);
    final rating = storeRating(store);
    final deliveryTime = storeDeliveryTime(store);
    final address = storeAddress(store);
    final typeName = storeTypeName(store);
    final storeMap = store == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(store!);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 44, 16, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [VipTheme.yellow, VipTheme.yellowDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: VipTheme.navy),
              ),
              const Spacer(),
              FavoriteHeart(item: storeMap, isStore: true, size: 22),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartPage()),
                ),
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: VipTheme.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .92),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: const Color(0xfffff3cd),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: logoUrl == null
                          ? const Icon(
                              Icons.storefront,
                              color: VipTheme.yellowDark,
                              size: 45,
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Image.network(logoUrl, fit: BoxFit.cover),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            store?['name']?.toString() ?? 'المتجر',
                            style: const TextStyle(
                              color: VipTheme.navy,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            typeName.isEmpty ? 'متجر Foodx' : typeName,
                            style: const TextStyle(
                              color: VipTheme.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(
                                Icons.star,
                                color: VipTheme.yellowDark,
                                size: 18,
                              ),
                              Text(
                                rating,
                                style: const TextStyle(
                                  color: VipTheme.navy,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const Icon(
                                Icons.timer_outlined,
                                color: VipTheme.yellowDark,
                                size: 18,
                              ),
                              Text(
                                deliveryTime,
                                style: const TextStyle(
                                  color: VipTheme.navy,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: VipTheme.yellowDark,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: VipTheme.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: openStoreRatingDialog,
                        icon: const Icon(Icons.star_border),
                        label: const Text('قيّم المتجر'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => FavoriteService.toggleStore(storeMap),
                        icon: const Icon(Icons.favorite),
                        label: const Text('المفضلة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> openStoreRatingDialog() async {
    int rating = 5;
    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تقييم المتجر'),
              content: Wrap(
                alignment: WrapAlignment.center,
                spacing: 0,
                runSpacing: 0,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => setDialogState(() => rating = value),
                    icon: Icon(
                      value <= rating ? Icons.star : Icons.star_border,
                      color: VipTheme.yellowDark,
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('تم تسجيل تقييمك: $rating نجوم')),
                    );
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget categoryTabs() {
    if (categories.isEmpty) return const SizedBox();
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final selected = selectedCategoryIndex == index;
          final category = categories[index];
          final iconUrl = dynamicImageUrl(category, [
            'icon',
            'icon_url',
            'image',
            'image_url',
            'photo',
            'photo_url',
            'logo',
            'logo_url',
            'category_icon',
            'icon_path',
            'thumbnail',
          ]);

          return GestureDetector(
            onTap: () => setState(() => selectedCategoryIndex = index),
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected ? const Color(0xffffc107) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? const Color(0xffffc107)
                      : const Color(0xffe5e7eb),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (iconUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        iconUrl,
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    category["name"] ?? "",
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget productCard(dynamic product) {
    final image = product["image"];
    final variants = product["variants"] ?? [];
    final addons = product["addons"] ?? [];
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            child: image != null
                ? Image.network(
                    productImageUrl(image),
                    width: 120,
                    height: 125,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 120,
                    height: 125,
                    color: const Color(0xfffff3cd),
                    child: const Icon(
                      Icons.fastfood,
                      color: Color(0xffffc107),
                      size: 42,
                    ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product["name"] ?? "",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    product["description"] ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  if (variants.isNotEmpty)
                    Text(
                      "أحجام: ${variants.length}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  if (addons.isNotEmpty)
                    Text(
                      "إضافات: ${addons.length}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "${product["price"]} د.ع",
                          style: const TextStyle(
                            color: Color(0xffffc107),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xffffc107),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add, color: Colors.white),
                          onPressed: () => showAddToCartDialog(product),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget selectedCategoryProducts() {
    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: Text("لا توجد أقسام")),
      );
    }
    final products = categories[selectedCategoryIndex]["products"] ?? [];
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: Text("لا توجد منتجات داخل هذا القسم")),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: products
            .map<Widget>((product) => productCard(product))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        bottomNavigationBar: const FoodxBottomNav(active: 'home'),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  storeHeader(),
                  const SizedBox(height: 18),
                  categoryTabs(),
                  const SizedBox(height: 18),
                  selectedCategoryProducts(),
                  const SizedBox(height: 25),
                ],
              ),
      ),
    );
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final MapController mapController = MapController();
  LatLng selectedPosition = const LatLng(33.3152, 44.3661);
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadInitialLocation();
  }

  Future<void> loadInitialLocation() async {
    final saved = await CustomerLocationService.getSavedLocation();

    if (saved.hasCoordinates) {
      selectedPosition = LatLng(saved.latitude!, saved.longitude!);
    } else {
      try {
        final position = await CustomerLocationService.getCurrentGpsLocation();
        if (position != null) {
          selectedPosition = LatLng(position.latitude, position.longitude);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> savePickedLocation() async {
    final address = await CustomerLocationService.reverseGeocodeAddress(
      selectedPosition.latitude,
      selectedPosition.longitude,
    );

    if (!mounted) return;

    Navigator.pop(
      context,
      CustomerSavedLocation(
        latitude: selectedPosition.latitude,
        longitude: selectedPosition.longitude,
        address: address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحديد موقع التوصيل'),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: savePickedLocation,
              child: const Text(
                'حفظ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: selectedPosition,
                      initialZoom: 15,
                      onTap: (tapPosition, position) {
                        setState(() => selectedPosition = position);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.foodx_customer_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selectedPosition,
                            width: 58,
                            height: 58,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 52,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    left: 16,
                    bottom: 16,
                    child: ElevatedButton.icon(
                      onPressed: savePickedLocation,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('اعتماد هذا الموقع'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool loading = true;
  bool calculatingDelivery = false;

  Map<String, dynamic>? cart;
  Map<String, dynamic>? delivery;
  Map<String, dynamic>? couponResult;

  bool applyingCoupon = false;
  String? appliedCouponCode;
  double couponDiscount = 0;
  double deliveryDiscount = 0;

  final couponController = TextEditingController();

  final addressController = TextEditingController(
    text: "عنوان الزبون التجريبي",
  );

  double? customerLat;
  double? customerLng;

  @override
  void initState() {
    super.initState();
    loadCart();
  }

  @override
  void dispose() {
    couponController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> loadSavedLocationForCart() async {
    final saved = await CustomerLocationService.getSavedLocation();

    if (!mounted) return;

    setState(() {
      customerLat = saved.latitude;
      customerLng = saved.longitude;
      addressController.text = saved.address;
    });
  }

  Future<void> getCustomerLocation({bool showMessage = true}) async {
    try {
      final position = await CustomerLocationService.getCurrentGpsLocation();

      if (!mounted) return;

      if (position == null) {
        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر تحديد الموقع. فعّل GPS والصلاحيات.'),
            ),
          );
        }
        return;
      }

      final address = await CustomerLocationService.reverseGeocodeAddress(
        position.latitude,
        position.longitude,
      );

      await CustomerLocationService.saveLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );

      setState(() {
        customerLat = position.latitude;
        customerLng = position.longitude;
        addressController.text = address;
      });

      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث موقع التوصيل')));
      }
    } catch (_) {
      if (!mounted) return;
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديد الموقع حالياً')),
        );
      }
    }
  }

  Future<void> openManualAddressDialog() async {
    final controller = TextEditingController(text: addressController.text);

    final address = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('عنوان التوصيل'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'اكتب العنوان يدوياً',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (address == null || address.isEmpty) return;

    await CustomerLocationService.saveLocation(
      latitude: customerLat,
      longitude: customerLng,
      address: address,
    );

    if (!mounted) return;
    setState(() => addressController.text = address);
  }

  Future<void> openMapPickerFromCart() async {
    final picked = await Navigator.push<CustomerSavedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );

    if (picked == null) return;

    await CustomerLocationService.saveLocation(
      latitude: picked.latitude,
      longitude: picked.longitude,
      address: picked.address,
    );

    if (!mounted) return;

    setState(() {
      customerLat = picked.latitude;
      customerLng = picked.longitude;
      addressController.text = picked.address;
    });

    await calculateDeliveryFee();
  }

  void clearCoupon({bool refresh = true}) {
    appliedCouponCode = null;
    couponResult = null;
    couponDiscount = 0;
    deliveryDiscount = 0;

    if (refresh && mounted) {
      setState(() {});
    }
  }

  Future<void> applyCoupon() async {
    final code = couponController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('اكتب كود الكوبون أولاً')));
      return;
    }

    if (cart == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('السلة فارغة')));
      return;
    }

    if (mounted) setState(() => applyingCoupon = true);

    try {
      final token = await getSavedToken();

      final result = await ApiService.applyCoupon(
        token,
        code: code,
        latitude: customerLat,
        longitude: customerLng,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      final statusCode = result['_status_code'] ?? 200;
      if (statusCode >= 400) {
        clearCoupon(refresh: false);
        setState(() => applyingCoupon = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'الكوبون غير صالح')),
        );
        return;
      }

      setState(() {
        applyingCoupon = false;
        couponResult = result;
        appliedCouponCode =
            result['coupon_code']?.toString() ?? code.toUpperCase();
        couponDiscount =
            double.tryParse((result['coupon_discount'] ?? 0).toString()) ?? 0;
        deliveryDiscount =
            double.tryParse((result['delivery_discount'] ?? 0).toString()) ?? 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'تم تطبيق الكوبون')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => applyingCoupon = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تطبيق الكوبون: $e')));
    }
  }

  Future<void> loadCart() async {
    if (mounted) {
      setState(() {
        loading = true;
        calculatingDelivery = false;
      });
    }

    await loadSavedLocationForCart();

    try {
      final token = await getSavedToken();

      if (token.isEmpty) {
        if (!mounted) return;
        setState(() {
          cart = null;
          loading = false;
        });
        return;
      }

      final result = await ApiService.getCart(
        token,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      setState(() {
        cart = result['cart'];
        loading = false;
        clearCoupon(refresh: false);
      });

      await calculateDeliveryFee();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        calculatingDelivery = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء تحميل السلة: $e')));
    }
  }

  Future<void> calculateDeliveryFee() async {
    if (cart == null) return;

    final items = cart?['items'] ?? [];
    if (items.isEmpty) return;

    if (customerLat == null || customerLng == null) {
      setState(() => delivery = null);
      return;
    }

    if (mounted) setState(() => calculatingDelivery = true);

    try {
      final token = await getSavedToken();

      final result = await ApiService.calculateDelivery(
        token,
        latitude: customerLat!,
        longitude: customerLng!,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      setState(() {
        delivery = result;
        calculatingDelivery = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => calculatingDelivery = false);
    }
  }

  Future<void> updateItem(dynamic item, int quantity) async {
    if (quantity < 1) return;

    final token = await getSavedToken();

    final result = await ApiService.updateCartItem(
      token,
      itemId: item["id"],
      quantity: quantity,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result["message"] ?? "تم التحديث")));

    await loadCart();
  }

  Future<void> removeItem(dynamic item) async {
    final token = await getSavedToken();

    final result = await ApiService.removeCartItem(token, itemId: item["id"]);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result["message"] ?? "تم الحذف")));

    await loadCart();
  }

  Future<void> checkout() async {
    if (addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل عنوان التوصيل')));
      return;
    }

    if (customerLat == null || customerLng == null) {
      final continueWithoutLocation = await showDialog<bool>(
        context: context,
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('لم يتم تحديد الموقع'),
            content: const Text(
              'لم يتم تحديد موقع GPS. يمكنك إكمال الطلب بالعنوان اليدوي، لكن يفضل تحديد الموقع لحساب التوصيل بدقة.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('تحديد الموقع'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إكمال الطلب'),
              ),
            ],
          ),
        ),
      );

      if (continueWithoutLocation != true) {
        await getCustomerLocation();
        if (customerLat == null || customerLng == null) return;
      }
    }

    await CustomerLocationService.saveLocation(
      latitude: customerLat,
      longitude: customerLng,
      address: addressController.text.trim(),
    );

    final token = await getSavedToken();

    final result = await ApiService.checkout(
      token,
      deliveryAddress: addressController.text.trim(),
      latitude: customerLat,
      longitude: customerLng,
      couponCode: appliedCouponCode,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? 'تم إنشاء الطلب')),
    );

    if (result['order'] != null) {
      await loadCart();

      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  String money(dynamic value) {
    if (value == null) return "0";
    final number = double.tryParse(value.toString()) ?? 0;
    return number.toStringAsFixed(0);
  }

  Widget itemCard(dynamic item) {
    final product = item["product"];
    final variant = item["variant"];
    final quantity = item["quantity"] ?? 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xfffff3cd),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.fastfood, color: Color(0xffffc107)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product?["name"] ?? "",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (variant != null)
                    Text(
                      "الحجم: ${variant["name"]}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                  Text(
                    "${money(item["unit_price"])} د.ع",
                    style: const TextStyle(
                      color: Color(0xffffc107),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => updateItem(item, quantity - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  "$quantity",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => updateItem(item, quantity + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            IconButton(
              onPressed: () => removeItem(item),
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget priceRow(String title, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: bold ? 18 : 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 18 : 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? const Color(0xffffc107) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = cart?["items"] ?? [];

    final subtotal = delivery?["subtotal"] ?? cart?["subtotal"] ?? "0";
    final distanceKm = delivery?["distance_km"] ?? "0";
    final deliveryFee = delivery?["delivery_fee"] ?? "0";

    final subtotalNumber = double.tryParse(subtotal.toString()) ?? 0;
    final deliveryFeeNumber = double.tryParse(deliveryFee.toString()) ?? 0;
    final totalBeforeDiscount = subtotalNumber + deliveryFeeNumber;
    final finalTotal = totalBeforeDiscount - couponDiscount - deliveryDiscount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        bottomNavigationBar: const FoodxBottomNav(active: 'cart'),
        appBar: AppBar(title: const Text("السلة"), centerTitle: true),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : cart == null || items.isEmpty
            ? const Center(child: Text("السلة فارغة"))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    "المتجر: ${cart?["store"]?["name"] ?? ""}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...items.map<Widget>((item) => itemCard(item)).toList(),
                  const SizedBox(height: 12),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                customerLat != null && customerLng != null
                                    ? Icons.location_on
                                    : Icons.location_off,
                                color: const Color(0xffffc107),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  customerLat != null && customerLng != null
                                      ? 'موقع التوصيل محدد'
                                      : 'لم يتم تحديد موقع GPS',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await getCustomerLocation();
                                  await calculateDeliveryFee();
                                },
                                icon: const Icon(Icons.my_location),
                                label: const Text('تحديث موقعي'),
                              ),
                              OutlinedButton.icon(
                                onPressed: openMapPickerFromCart,
                                icon: const Icon(Icons.map),
                                label: const Text('تحديد على الخريطة'),
                              ),
                              OutlinedButton.icon(
                                onPressed: openManualAddressDialog,
                                icon: const Icon(Icons.edit_location_alt),
                                label: const Text('عنوان يدوي'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: "عنوان التوصيل",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xfffffbeb),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: const Color(0xffffc107).withValues(alpha: .35),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.local_offer, color: Color(0xffffc107)),
                              SizedBox(width: 8),
                              Text(
                                'كوبون الخصم',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: couponController,
                                  enabled: appliedCouponCode == null,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'مثال: FOODX10',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: applyingCoupon
                                      ? null
                                      : appliedCouponCode == null
                                      ? applyCoupon
                                      : () {
                                          couponController.clear();
                                          clearCoupon();
                                        },
                                  child: applyingCoupon
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          appliedCouponCode == null
                                              ? 'تطبيق'
                                              : 'إزالة',
                                        ),
                                ),
                              ),
                            ],
                          ),
                          if (appliedCouponCode != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'تم تطبيق كوبون $appliedCouponCode',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          if (calculatingDelivery)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: LinearProgressIndicator(),
                            ),
                          priceRow("مجموع المنتجات", "${money(subtotal)} د.ع"),
                          priceRow("المسافة", "$distanceKm كم"),
                          priceRow("رسوم التوصيل", "${money(deliveryFee)} د.ع"),
                          if (couponDiscount > 0)
                            priceRow(
                              "خصم الكوبون",
                              "-${money(couponDiscount)} د.ع",
                            ),
                          if (deliveryDiscount > 0)
                            priceRow(
                              "خصم التوصيل",
                              "-${money(deliveryDiscount)} د.ع",
                            ),
                          const Divider(),
                          priceRow(
                            "الإجمالي قبل الخصم",
                            "${money(totalBeforeDiscount)} د.ع",
                          ),
                          priceRow(
                            "الإجمالي النهائي",
                            "${money(finalTotal < 0 ? 0 : finalTotal)} د.ع",
                            bold: true,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: checkout,
                              icon: const Icon(Icons.check_circle),
                              label: const Text(
                                "إتمام الطلب",
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class CustomerOrdersPage extends StatefulWidget {
  const CustomerOrdersPage({super.key});

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  bool loading = true;
  List orders = [];

  @override
  void initState() {
    super.initState();
    loadOrders();
  }

  Future<void> loadOrders() async {
    setState(() => loading = true);

    final token = await getSavedToken();
    final result = await ApiService.customerOrders(token);

    if (!mounted) return;

    setState(() {
      orders = result["orders"] ?? [];
      loading = false;
    });
  }

  String statusText(String status) {
    switch (status) {
      case "pending":
        return "بانتظار قبول التاجر";
      case "accepted":
        return "تم قبول الطلب";
      case "preparing":
        return "قيد التجهيز";
      case "ready":
        return "جاهز للمندوب";
      case "assigned":
        return "تم تعيين مندوب";
      case "picked_up":
        return "استلمه المندوب";
      case "on_the_way":
        return "المندوب في الطريق";
      case "delivered":
        return "تم التسليم";
      case "cancelled":
        return "ملغي";
      default:
        return status;
    }
  }

  Widget orderCard(dynamic order) {
    final store = order["store"];
    final driver = order["driver"];
    final status = order["status"] ?? "";

    final canTrack =
        status == "assigned" ||
        status == "picked_up" ||
        status == "on_the_way" ||
        status == "delivered";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "طلب رقم #${order["id"]}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("المتجر: ${store?["name"] ?? "غير معروف"}"),
            Text("المندوب: ${driver?["name"] ?? "لم يتم تعيين مندوب بعد"}"),
            Text("الحالة: ${statusText(status)}"),
            Text("العنوان: ${order["delivery_address"] ?? ""}"),
            Text(
              "المبلغ: ${order["total"]} د.ع",
              style: const TextStyle(
                color: Color(0xffffc107),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (canTrack)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.location_on),
                  label: const Text("تتبع المندوب"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingPage(orderId: order["id"]),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        bottomNavigationBar: const FoodxBottomNav(active: 'orders'),
        appBar: AppBar(
          title: const Text("طلباتي"),
          centerTitle: true,
          actions: [
            IconButton(onPressed: loadOrders, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : orders.isEmpty
            ? const Center(child: Text("لا توجد طلبات حالياً"))
            : RefreshIndicator(
                onRefresh: loadOrders,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return orderCard(orders[index]);
                  },
                ),
              ),
      ),
    );
  }
}

class OrderTrackingPage extends StatefulWidget {
  final int orderId;

  const OrderTrackingPage({super.key, required this.orderId});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  bool loading = true;
  bool refreshing = false;
  String? errorMessage;

  Map<String, dynamic>? order;
  Map<String, dynamic>? location;
  List trackingHistory = [];

  Timer? timer;
  final MapController mapController = MapController();
  double driverBearing = 0;

  @override
  void initState() {
    super.initState();
    loadTracking();

    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      loadTracking(showLoading: false);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  double? asDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  LatLng? latLngFrom(dynamic source) {
    if (source is! Map) return null;

    final lat = asDouble(
      source['latitude'] ??
          source['lat'] ??
          source['customer_latitude'] ??
          source['delivery_latitude'],
    );

    final lng = asDouble(
      source['longitude'] ??
          source['lng'] ??
          source['customer_longitude'] ??
          source['delivery_longitude'],
    );

    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get driverPosition => latLngFrom(location);
  LatLng? get customerPosition => latLngFrom(order);

  List<LatLng> get historyPoints {
    final points = <LatLng>[];

    for (final item in trackingHistory) {
      final point = latLngFrom(item);
      if (point == null) continue;

      if (points.isEmpty || !samePoint(points.last, point)) {
        points.add(point);
      }
    }

    final driver = driverPosition;
    if (driver != null && (points.isEmpty || !samePoint(points.last, driver))) {
      points.add(driver);
    }

    return points;
  }

  bool samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
  }

  double bearingBetween(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final dLng = (end.longitude - start.longitude) * math.pi / 180;

    final y = math.sin(dLng) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    final bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  double distanceKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return earthRadiusKm * c;
  }

  Future<void> loadTracking({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    } else if (mounted) {
      setState(() => refreshing = true);
    }

    final oldDriver = driverPosition;

    try {
      final token = await getSavedToken();
      final result = await ApiService.trackOrder(
        token,
        widget.orderId,
      ).timeout(const Duration(seconds: 12));

      List newHistory = trackingHistory;
      try {
        final historyResult = await ApiService.trackingHistory(
          token,
          widget.orderId,
        ).timeout(const Duration(seconds: 8));

        final rawHistory =
            historyResult['history'] ??
            historyResult['locations'] ??
            historyResult['tracking'] ??
            historyResult['data'];

        if (rawHistory is List) {
          newHistory = rawHistory;
        } else if (rawHistory is Map && rawHistory['data'] is List) {
          newHistory = rawHistory['data'];
        }
      } catch (_) {
        newHistory = trackingHistory;
      }

      final newOrder = result['order'] is Map<String, dynamic>
          ? result['order'] as Map<String, dynamic>
          : Map<String, dynamic>.from(result['order'] ?? {});

      final newLocation = result['location'] is Map<String, dynamic>
          ? result['location'] as Map<String, dynamic>
          : result['location'] is Map
          ? Map<String, dynamic>.from(result['location'])
          : null;

      final newDriver = latLngFrom(newLocation);
      if (oldDriver != null &&
          newDriver != null &&
          !samePoint(oldDriver, newDriver)) {
        driverBearing = bearingBetween(oldDriver, newDriver);
      } else if (newHistory.length >= 2) {
        final p1 = latLngFrom(newHistory[newHistory.length - 2]);
        final p2 = latLngFrom(newHistory[newHistory.length - 1]);
        if (p1 != null && p2 != null && !samePoint(p1, p2)) {
          driverBearing = bearingBetween(p1, p2);
        }
      }

      if (!mounted) return;
      setState(() {
        order = newOrder;
        location = newLocation;
        trackingHistory = newHistory;
        loading = false;
        refreshing = false;
        errorMessage = null;
      });

      await fitCameraToRoute();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
        errorMessage = 'تعذر تحديث موقع المندوب حالياً';
      });
    }
  }

  LatLng initialPosition() {
    return driverPosition ?? customerPosition ?? const LatLng(33.3152, 44.3661);
  }

  LatLng centerFrom(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  Future<void> fitCameraToRoute() async {
    final points = <LatLng>[];
    final driver = driverPosition;
    final customer = customerPosition;

    points.addAll(historyPoints);
    if (driver != null && points.every((p) => !samePoint(p, driver))) {
      points.add(driver);
    }
    if (customer != null && points.every((p) => !samePoint(p, customer))) {
      points.add(customer);
    }

    if (points.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 250));

    if (points.length == 1) {
      mapController.move(points.first, 16);
      return;
    }

    mapController.move(centerFrom(points), 14);
  }

  List<Marker> buildMarkers() {
    final markers = <Marker>[];
    final driver = driverPosition;
    final customer = customerPosition;

    if (driver != null) {
      markers.add(
        Marker(
          point: driver,
          width: 72,
          height: 72,
          child: Transform.rotate(
            angle: driverBearing * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: VipTheme.gold,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_car_filled,
                color: VipTheme.navy,
                size: 34,
              ),
            ),
          ),
        ),
      );
    }

    if (customer != null) {
      markers.add(
        Marker(
          point: customer,
          width: 64,
          height: 64,
          child: Container(
            decoration: BoxDecoration(
              color: VipTheme.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.home_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  List<LatLng> roadRoutePoints = [];
  LatLng? lastRouteDriver;
  LatLng? lastRouteCustomer;
  bool loadingRoadRoute = false;

  bool nearPoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.0004 &&
        (a.longitude - b.longitude).abs() < 0.0004;
  }

  Future<void> loadRoadRoute() async {
    final driver = driverPosition;
    final customer = customerPosition;

    if (driver == null || customer == null || samePoint(driver, customer)) {
      return;
    }

    if (loadingRoadRoute) return;

    if (lastRouteDriver != null &&
        lastRouteCustomer != null &&
        roadRoutePoints.length >= 2 &&
        nearPoint(lastRouteDriver!, driver) &&
        nearPoint(lastRouteCustomer!, customer)) {
      return;
    }

    loadingRoadRoute = true;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${driver.longitude},${driver.latitude};'
        '${customer.longitude},${customer.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;

        if (routes != null && routes.isNotEmpty) {
          final coordinates = routes.first['geometry']['coordinates'] as List;

          final points = coordinates.map<LatLng>((point) {
            return LatLng(
              (point[1] as num).toDouble(),
              (point[0] as num).toDouble(),
            );
          }).toList();

          if (mounted && points.length >= 2) {
            setState(() {
              roadRoutePoints = points;
              lastRouteDriver = driver;
              lastRouteCustomer = customer;
            });
          }
        }
      }
    } catch (_) {
      // إذا فشل جلب الطريق، يبقى الخط المستقيم احتياطياً
    } finally {
      loadingRoadRoute = false;
    }
  }

  List<Polyline> buildPolylines() {
    final polylines = <Polyline>[];
    final driver = driverPosition;
    final customer = customerPosition;
    final path = historyPoints;

    if (path.length >= 2) {
      polylines.add(
        Polyline(points: path, color: VipTheme.gold, strokeWidth: 7),
      );
    }

    if (driver != null && customer != null && !samePoint(driver, customer)) {
      final needsRoadRoute =
          roadRoutePoints.length < 2 ||
          lastRouteDriver == null ||
          lastRouteCustomer == null ||
          !nearPoint(lastRouteDriver!, driver) ||
          !nearPoint(lastRouteCustomer!, customer);

      if (needsRoadRoute) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            loadRoadRoute();
          }
        });
      }

      polylines.add(
        Polyline(
          points: needsRoadRoute ? [driver, customer] : roadRoutePoints,
          color: VipTheme.blue.withValues(alpha: 0.75),
          strokeWidth: 5,
        ),
      );
    }

    return polylines;
  }

  String statusText(String status) {
    switch (status) {
      case 'pending':
        return 'بانتظار قبول التاجر';
      case 'accepted':
        return 'تم قبول الطلب';
      case 'preparing':
        return 'قيد التجهيز';
      case 'ready':
        return 'جاهز للمندوب';
      case 'assigned':
        return 'تم تعيين مندوب';
      case 'picked_up':
        return 'استلمه المندوب';
      case 'on_the_way':
        return 'المندوب في الطريق';
      case 'delivered':
        return 'تم التسليم';
      case 'cancelled':
        return 'ملغي';
      default:
        return status.isEmpty ? 'غير معروف' : status;
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return 'غير متوفر';
    try {
      final date = DateTime.parse(value.toString()).toLocal();
      final y = date.year.toString();
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      final h = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '$y-$m-$d  $h:$min';
    } catch (_) {
      return value.toString();
    }
  }

  String distanceText() {
    final driver = driverPosition;
    final customer = customerPosition;
    if (driver == null || customer == null) return 'غير متوفر';

    final km = distanceKm(driver, customer);
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} متر تقريباً';
    }
    return '${km.toStringAsFixed(2)} كم تقريباً';
  }

  Widget topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        child: Row(
          children: [
            circleButton(
              icon: Icons.arrow_forward,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'تتبع الطلب #${widget.orderId}',
                    style: const TextStyle(
                      color: VipTheme.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            circleButton(icon: Icons.my_location, onTap: fitCameraToRoute),
            const SizedBox(width: 8),
            circleButton(
              icon: Icons.refresh,
              onTap: () => loadTracking(showLoading: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 6,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: VipTheme.navy),
        ),
      ),
    );
  }

  Widget vipStatusChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [VipTheme.gold, VipTheme.goldLight],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VipTheme.navy,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String? trackingTextValue(dynamic data, List<String> keys) {
    if (data is! Map) return null;

    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return null;
  }

  String? driverWhatsappPhone() {
    final driver = order?['driver'];

    final phone = trackingTextValue(driver, [
      'phone',
      'mobile',
      'whatsapp',
      'whatsapp_number',
      'driver_phone',
    ]);

    if (phone != null) return phone;

    final userPhone = trackingTextValue(driver?['user'], [
      'phone',
      'mobile',
      'whatsapp',
    ]);

    if (userPhone != null) return userPhone;

    return trackingTextValue(order, [
      'driver_phone',
      'driver_mobile',
      'driver_whatsapp',
    ]);
  }

  String normalizeWhatsappPhone(String phone) {
    var p = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (p.startsWith('+')) {
      p = p.substring(1);
    }

    if (p.startsWith('00')) {
      p = p.substring(2);
    }

    if (p.startsWith('0')) {
      p = '964${p.substring(1)}';
    }

    return p;
  }

  Future<void> openDriverWhatsapp() async {
    final rawPhone = driverWhatsappPhone();

    if (rawPhone == null || rawPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('رقم واتساب المندوب غير متوفر')),
      );
      return;
    }

    final phone = normalizeWhatsappPhone(rawPhone);
    final appUrl = Uri.parse('whatsapp://send?phone=$phone');
    final webUrl = Uri.parse('https://wa.me/$phone');

    if (await canLaunchUrl(appUrl)) {
      await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      return;
    }

    await launchUrl(webUrl, mode: LaunchMode.externalApplication);
  }

  Future<void> openWazeToDriver() async {
    final driver = driverPosition;

    if (driver == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('موقع المندوب غير متوفر حالياً')),
      );
      return;
    }

    final wazeUrl = Uri.parse(
      'https://waze.com/ul?ll=${driver.latitude},${driver.longitude}&navigate=yes&utm_source=foodx_customer',
    );

    final ok = await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق Waze')));
    }
  }

  Widget trackingBottomSheet() {
    final driver = order?['driver'];
    final store = order?['store'];
    final status = statusText((order?['status'] ?? '').toString());
    final updatedAt = location?['created_at'] ?? location?['updated_at'];
    final hasDriver = driverPosition != null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [VipTheme.navy, VipTheme.royal],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled,
                      color: VipTheme.gold,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasDriver
                              ? 'المندوب يتحرك على الخريطة'
                              : 'بانتظار إرسال موقع المندوب',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: VipTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المندوب: ${driver?['name'] ?? 'غير معروف'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VipTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  vipStatusChip(status),
                  InkWell(
                    onTap: openDriverWhatsapp,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF25D366,
                            ).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: openWazeToDriver,
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D9CDB),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2D9CDB,
                            ).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  infoBox(
                    icon: Icons.storefront,
                    title: 'المتجر',
                    value: store?['name']?.toString() ?? 'غير معروف',
                  ),
                  const SizedBox(width: 10),
                  infoBox(
                    icon: Icons.route,
                    title: 'المسافة',
                    value: distanceText(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  infoBox(
                    icon: Icons.update,
                    title: 'آخر تحديث',
                    value: formatDate(updatedAt),
                  ),
                  const SizedBox(width: 10),
                  infoBox(
                    icon: Icons.timeline,
                    title: 'نقاط الحركة',
                    value: '${historyPoints.length} نقطة',
                  ),
                ],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (!hasDriver) ...[
                const SizedBox(height: 10),
                const Text(
                  '   اطلب من المندوب تحديث موقعه.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (refreshing) ...[
                const SizedBox(height: 10),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget infoBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfff4f7fb),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe5e7eb)),
        ),
        child: Row(
          children: [
            Icon(icon, color: VipTheme.blue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: VipTheme.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VipTheme.navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget mapErrorCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'لا توجد إحداثيات كافية لعرض التتبع على الخريطة. تأكد من أن الطلب يحتوي على موقع الزبون وأن المندوب يرسل موقعه.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyPoint = driverPosition != null || customerPosition != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: VipTheme.page,
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: hasAnyPoint
                        ? FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: initialPosition(),
                              initialZoom: 15,
                              interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.all,
                              ),
                              onMapReady: fitCameraToRoute,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'com.example.foodx_customer_app',
                              ),
                              PolylineLayer(polylines: buildPolylines()),
                              MarkerLayer(markers: buildMarkers()),
                            ],
                          )
                        : mapErrorCard(),
                  ),
                  Positioned(top: 0, left: 0, right: 0, child: topBar()),
                  trackingBottomSheet(),
                ],
              ),
      ),
    );
  }
}
