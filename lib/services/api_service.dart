import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Backend sunucumuzun adresi — fiziksel cihazda kendi IP'nle değiştir
  static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emülatör
  // static const String baseUrl = 'http://localhost:3000/api'; // iOS simülatör

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
        'color': color ?? '',
        'imageUrl': imageUrl ?? '',
        'description': description ?? '',
        'isSos': isSos,
        'sosDiscountPercent': sosDiscountPercent,
      }),
    );
    return jsonDecode(response.body);
  }
}
