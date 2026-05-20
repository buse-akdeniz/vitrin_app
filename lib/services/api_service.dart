import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Backend sunucu adresi (production için --dart-define ile verilir)
  // Örnek: --dart-define=API_BASE_URL=https://YOUR-RAILWAY-DOMAIN.up.railway.app/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  // ─── Token Yönetimi ──────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ─── Ortak Header Oluşturucu ─────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Kayıt (Register) ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(response.body);
  }

  // ─── Giriş (Login) ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      await saveToken(data['token']);
    }
    return data;
  }

  static Future<Map<String, dynamic>> verifyToken() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/verify'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ─── Profil Görüntüle ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ─── Profil Güncelle ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> updateProfile(
      {String? name, String? bio}) async {
    final response = await http.put(
      Uri.parse('$baseUrl/profile'),
      headers: await _authHeaders(),
      body: jsonEncode({'name': name, 'bio': bio}),
    );
    return jsonDecode(response.body);
  }

  // ─── Ürün Listeleme ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getProducts(
      {Map<String, dynamic>? filters}) async {
    final query = <String, String>{};
    if (filters != null) {
      filters.forEach((key, value) {
        if (value == null) return;
        final text = value.toString().trim();
        if (text.isNotEmpty) query[key] = text;
      });
    }

    final response = await http.get(
      Uri.parse('$baseUrl/products').replace(
        queryParameters: query.isEmpty ? null : query,
      ),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  // ─── Ürün Ekleme ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createProduct({
    required String title,
    required double price,
    String? category,
    String? brand,
    String? size,
    String? fabricType,
    String? shoeSize,
    String? gender,
    String? condition,
    String? shippingType,
    String? packageSize,
    String? color,
    String? imageUrl,
    String? description,
    bool isSos = false,
    int sosDiscountPercent = 0,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'title': title,
        'price': price,
        'category': category ?? '',
        'brand': brand ?? '',
        'size': size ?? '',
        'fabricType': fabricType ?? '',
        'shoeSize': shoeSize ?? '',
        'gender': gender ?? '',
        'condition': condition ?? '',
        'shippingType': shippingType ?? 'seller',
        'packageSize': packageSize ?? 'medium',
        'color': color ?? '',
        'imageUrl': imageUrl ?? '',
        'description': description ?? '',
        'isSos': isSos,
        'sosDiscountPercent': sosDiscountPercent,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createProductWithImage({
    required String title,
    required double price,
    required String imagePath,
    String? category,
    String? brand,
    String? size,
    String? fabricType,
    String? shoeSize,
    String? gender,
    String? condition,
    String? shippingType,
    String? packageSize,
    String? color,
    String? description,
    bool isSos = false,
    int sosDiscountPercent = 0,
  }) async {
    final token = await getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/products/upload'),
    );

    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['title'] = title;
    request.fields['price'] = price.toString();
    request.fields['category'] = category ?? '';
    request.fields['brand'] = brand ?? '';
    request.fields['size'] = size ?? '';
    request.fields['fabricType'] = fabricType ?? '';
    request.fields['shoeSize'] = shoeSize ?? '';
    request.fields['gender'] = gender ?? '';
    request.fields['condition'] = condition ?? '';
    request.fields['shippingType'] = shippingType ?? 'seller';
    request.fields['packageSize'] = packageSize ?? 'medium';
    request.fields['color'] = color ?? '';
    request.fields['description'] = description ?? '';
    request.fields['isSos'] = isSos ? 'true' : 'false';
    request.fields['sosDiscountPercent'] = sosDiscountPercent.toString();

    request.files.add(
      await http.MultipartFile.fromPath('image', File(imagePath).path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getPriceInsights({
    String? title,
    String? category,
    String? brand,
  }) async {
    final query = <String, String>{
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (brand != null && brand.trim().isNotEmpty) 'brand': brand.trim(),
    };

    final response = await http.get(
      Uri.parse('$baseUrl/products/price-insights').replace(
        queryParameters: query.isEmpty ? null : query,
      ),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  // ─── Destek Asistanı (AI Chat) ───────────────────────────────────────────

  static Future<Map<String, dynamic>> supportChat({
    required String message,
    List<Map<String, String>> history = const [],
    String? orderNo,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/support/chat'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'message': message,
        'history': history,
        if (orderNo != null && orderNo.trim().isNotEmpty)
          'orderNo': orderNo.trim(),
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> stylistChat({
    required String message,
    List<Map<String, String>> history = const [],
    String? occasion,
    String? weather,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/stylist/chat'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'message': message,
        'history': history,
        if (occasion != null && occasion.trim().isNotEmpty)
          'occasion': occasion.trim(),
        if (weather != null && weather.trim().isNotEmpty) 'weather': weather.trim(),
      }),
    );

    return jsonDecode(response.body);
  }

  // ─── Teklifler ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getOfferQuota() async {
    final response = await http.get(
      Uri.parse('$baseUrl/offers/quota'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createOffer({
    required int productId,
    required double amount,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/offers'),
      headers: await _authHeaders(),
      body: jsonEncode({'productId': productId, 'amount': amount}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getSentOffers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/offers/sent'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getReceivedOffers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/offers/received'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> respondOffer({
    required int offerId,
    required String action,
    double? counterAmount,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/offers/$offerId/respond'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'action': action,
        if (counterAmount != null) 'counterAmount': counterAmount,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getOfferHistory(int offerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/offers/$offerId/history'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ─── Yorumlar ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getComments(int productId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products/$productId/comments'),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addComment({
    required int productId,
    required String content,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products/$productId/comments'),
      headers: await _authHeaders(),
      body: jsonEncode({'content': content}),
    );
    return jsonDecode(response.body);
  }

  // ─── Favoriler ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFavorites() async {
    final response = await http.get(
      Uri.parse('$baseUrl/favorites'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addFavorite(int productId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/favorites/$productId'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> removeFavorite(int productId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/favorites/$productId'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ─── Takip (Satıcı) ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFollowedSellers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/follows'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> followSeller(int sellerId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/follows/$sellerId'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> unfollowSeller(int sellerId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/follows/$sellerId'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getRecommendedProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/products/recommended'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ─── Satıcı Paneli ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSellerPanel() async {
    final response = await http.get(
      Uri.parse('$baseUrl/seller/panel'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getSellerProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/seller/products'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateSellerProduct({
    required int productId,
    String? title,
    String? description,
    double? price,
    String? shippingType,
    String? packageSize,
    String? saleStatus,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/seller/products/$productId'),
      headers: await _authHeaders(),
      body: jsonEncode({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (price != null) 'price': price,
        if (shippingType != null) 'shippingType': shippingType,
        if (packageSize != null) 'packageSize': packageSize,
        if (saleStatus != null) 'saleStatus': saleStatus,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getSellerOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/seller/orders'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> shipOrder({
    required int orderId,
    String trackingNo = '',
    String shipmentStatus = 'shipped',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seller/orders/$orderId/ship'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'trackingNo': trackingNo,
        'shipmentStatus': shipmentStatus,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> markOrderDelivered(int orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seller/orders/$orderId/deliver'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ─── Alıcı Paneli ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getBuyerOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/buyer/orders'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getBuyerOrderBadges() async {
    final response = await http.get(
      Uri.parse('$baseUrl/buyer/orders/badges'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> requestCancel(int orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/buyer/orders/$orderId/cancel-request'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> requestReturn(int orderId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/buyer/orders/$orderId/return-request'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getOrderTracking(int orderId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId/tracking'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  // ─── Bildirimler ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/unread-count'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> markNotificationRead(int notificationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/read-all'),
      headers: await _authHeaders(),
    );
    return jsonDecode(response.body);
  }
}
