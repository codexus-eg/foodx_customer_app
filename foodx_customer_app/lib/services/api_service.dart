import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static String baseUrl = "http://51.241.184.58/api";
  static const String storageUrl = "http://51.241.184.58/storage";

  static Map<String, String> jsonHeaders({String? token}) {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  static Map<String, String> authHeaders(String token) {
    return {
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  static Map<String, dynamic> decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        decoded["_status_code"] = response.statusCode;
        return decoded;
      }
      return {
        "_status_code": response.statusCode,
        "data": decoded,
      };
    } catch (_) {
      return {
        "_status_code": response.statusCode,
        "message": "استجابة غير مفهومة من الخادم",
        "raw": response.body,
      };
    }
  }


  static Future<Map<String, dynamic>> appSettings() async {
    final response = await http.get(
      Uri.parse("$baseUrl/app-settings"),
      headers: {"Accept": "application/json"},
    );

    return decodeResponse(response);
  }

  static Future<Map<String, dynamic>> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: jsonHeaders(),
      body: jsonEncode({
        "username": phone,
        "password": password,
        "app_type": "customer",
      }),
    );

    return decodeResponse(response);
  }

  static Future<Map<String, dynamic>> login(String phone) async {
    return loginWithPassword(phone: phone, password: "123456");
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    String password = "123456",
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: jsonHeaders(),
      body: jsonEncode({
        "name": name,
        "phone": phone,
        "password": password,
        "role": "customer",
      }),
    );

    return decodeResponse(response);
  }

  static Future<Map<String, dynamic>> sendOtp(
    String phone, {
    String purpose = "register",
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/otp/send"),
      headers: jsonHeaders(),
      body: jsonEncode({
        "phone": phone,
        "purpose": purpose,
      }),
    );

    return decodeResponse(response);
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    String purpose = "register",
    String? name,
    String? password,
  }) async {
    final body = <String, dynamic>{
      "phone": phone,
      "otp": code,
      "purpose": purpose,
      "app_type": "customer",
    };

    if (name != null && name.trim().isNotEmpty) {
      body["name"] = name.trim();
    }

    if (password != null && password.trim().isNotEmpty) {
      body["password"] = password.trim();
    }

    final response = await http.post(
      Uri.parse("$baseUrl/otp/verify"),
      headers: jsonHeaders(),
      body: jsonEncode(body),
    );

    return decodeResponse(response);
  }

  static Future<Map<String, dynamic>> home() async {
    final response = await http.get(
      Uri.parse("$baseUrl/customer/home"),
      headers: {"Accept": "application/json"},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> storeDetails(int storeId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/customer/store/$storeId"),
      headers: {"Accept": "application/json"},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCart(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/store/customer/cart"),
      headers: authHeaders(token),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addToCart(
    String token, {
    required int storeId,
    required int productId,
    int? productVariantId,
    required int quantity,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/store/customer/cart/add"),
      headers: jsonHeaders(token: token),
      body: jsonEncode({
        "store_id": storeId,
        "product_id": productId,
        "product_variant_id": productVariantId,
        "quantity": quantity,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateCartItem(
    String token, {
    required int itemId,
    required int quantity,
  }) async {
    final response = await http.put(
      Uri.parse("$baseUrl/store/customer/cart/items/$itemId"),
      headers: jsonHeaders(token: token),
      body: jsonEncode({"quantity": quantity}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> removeCartItem(
    String token, {
    required int itemId,
  }) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/store/customer/cart/items/$itemId"),
      headers: authHeaders(token),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> checkout(
    String token, {
    required String deliveryAddress,
    double? latitude,
    double? longitude,
    String? couponCode,
  }) async {
    final body = <String, dynamic>{
      "delivery_address": deliveryAddress,
      "latitude": latitude,
      "longitude": longitude,
    };

    if (couponCode != null && couponCode.trim().isNotEmpty) {
      body["coupon_code"] = couponCode.trim();
    }

    final response = await http.post(
      Uri.parse("$baseUrl/store/customer/cart/checkout"),
      headers: jsonHeaders(token: token),
      body: jsonEncode(body),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> applyCoupon(
    String token, {
    required String code,
    double? latitude,
    double? longitude,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/store/customer/cart/apply-coupon"),
      headers: jsonHeaders(token: token),
      body: jsonEncode({
        "code": code,
        "latitude": latitude,
        "longitude": longitude,
      }),
    );

    return decodeResponse(response);
  }

  static Future<Map<String, dynamic>> customerOrders(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/customer/orders"),
      headers: authHeaders(token),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> trackOrder(
    String token,
    int orderId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/customer/orders/$orderId/tracking"),
      headers: authHeaders(token),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> calculateDelivery(
    String token, {
    required double latitude,
    required double longitude,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/store/customer/cart/calculate-delivery"),
      headers: jsonHeaders(token: token),
      body: jsonEncode({
        "latitude": latitude,
        "longitude": longitude,
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> trackingHistory(
    String token,
    int orderId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/customer/orders/$orderId/tracking/history"),
      headers: authHeaders(token),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> saveDeviceToken(
    String token,
    String fcmToken, {
    String deviceType = "android",
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/customer/device-token"),
      headers: jsonHeaders(token: token),
      body: jsonEncode({
        "token": fcmToken,
        "app_type": "customer",
        "device_type": deviceType,
        "device_name": "Foodx Customer App",
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> customerNotifications(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/customer/notifications"),
      headers: authHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteCustomerNotification(
    String token,
    dynamic notificationId,
  ) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/customer/notifications/$notificationId"),
      headers: authHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> supportMessages(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/customer/support/messages"),
      headers: authHeaders(token),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> sendSupportMessage(
    String token,
    String message,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/customer/support/messages"),
      headers: jsonHeaders(token: token),
      body: jsonEncode({"message": message}),
    );

    return jsonDecode(response.body);
  }
}
