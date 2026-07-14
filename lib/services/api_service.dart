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

  static const String uploadPresignPath = String.fromEnvironment(
    'UPLOAD_PRESIGN_PATH',
    defaultValue: '/uploads/presign',
  );

  static const String uploadCompletePath = String.fromEnvironment(
    'UPLOAD_COMPLETE_PATH',
    defaultValue: '/uploads/complete',
  );

  static const int uploadRequestTimeoutSeconds = int.fromEnvironment(
    'UPLOAD_REQUEST_TIMEOUT_SECONDS',
    defaultValue: 25,
  );

  static const int uploadRetryMaxAttempts = int.fromEnvironment(
    'UPLOAD_RETRY_MAX_ATTEMPTS',
    defaultValue: 3,
  );

  static const int uploadRetryBaseDelayMs = int.fromEnvironment(
    'UPLOAD_RETRY_BASE_DELAY_MS',
    defaultValue: 450,
  );

  static Duration _retryDelay(int attempt) {
    // attempt: 1..N
    final ms = uploadRetryBaseDelayMs * (1 << (attempt - 1));
    return Duration(milliseconds: ms.clamp(200, 4000));
  }

  static Future<T> _withRetries<T>(
    Future<T> Function() operation, {
    int attempts = uploadRetryMaxAttempts,
    bool Function(Object error)? shouldRetry,
  }) async {
    Object? lastError;
    for (var i = 1; i <= attempts; i++) {
      try {
        return await operation();
      } catch (e) {
        lastError = e;
        final retryable = shouldRetry?.call(e) ?? true;
        if (!retryable || i == attempts) rethrow;
        await Future.delayed(_retryDelay(i));
      }
    }
    throw lastError ?? Exception('unknown_error');
  }

  static bool _isRetryableNetworkError(Object error) {
    return error is SocketException ||
        error is HttpException ||
        error is HandshakeException ||
        error is FormatException;
  }

  static Future<bool> _isUrlReady(String url) async {
    final client = http.Client();
    try {
      final res = await client
          .head(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  static Future<String> _waitForProcessedImage({
    required Map<String, dynamic> completeResponse,
    void Function(String stage)? onStage,
    int maxWaitSeconds = 25,
  }) async {
    // Backend returns imageVariants.* that may not be ready immediately (async pipeline).
    final variants = completeResponse['imageVariants'];
    String? medium;
    if (variants is Map) {
      medium = (variants['medium'] ?? '').toString().trim();
    }
    medium ??= (completeResponse['imageUrl'] ?? '').toString().trim();
    if (medium.isEmpty) {
      return '';
    }

    final deadline = DateTime.now().add(Duration(seconds: maxWaitSeconds));
    var attempt = 0;
    while (DateTime.now().isBefore(deadline)) {
      attempt += 1;
      onStage?.call('Görsel işleniyor…');
      final ok = await _isUrlReady(medium);
      if (ok) return medium;
      // small backoff
      final delayMs = (350 * (1 << (attempt - 1))).clamp(350, 2500);
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    // Not ready yet; return best guess so UI can still try to load.
    return medium;
  }

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

  static Future<Map<String, dynamic>> getProductsFeed({
    Map<String, dynamic>? filters,
    int page = 1,
    int limit = 20,
    String? cursor,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
    };

    if (filters != null) {
      filters.forEach((key, value) {
        if (value == null) return;
        final text = value.toString().trim();
        if (text.isNotEmpty) query[key] = text;
      });
    }

    Future<Map<String, dynamic>> parseAndNormalize(Uri uri) async {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );
      final raw = jsonDecode(response.body);
      return _normalizeProductsFeed(raw);
    }

    try {
      return await parseAndNormalize(
        Uri.parse('$baseUrl/products/feed').replace(
          queryParameters: query,
        ),
      );
    } catch (_) {
      return await parseAndNormalize(
        Uri.parse('$baseUrl/products').replace(
          queryParameters: query,
        ),
      );
    }
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
    Map<String, dynamic>? imageVariants,
    String? description,
    bool isSos = false,
    int sosDiscountPercent = 0,
    bool urgentSale = false,
    int? urgentHours,
    bool launchBoost = false,
    int? launchBoostHours,
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
        if (imageVariants != null && imageVariants.isNotEmpty)
          'imageVariants': imageVariants,
        'description': description ?? '',
        'isSos': isSos,
        'sosDiscountPercent': sosDiscountPercent,
        'urgentSale': urgentSale,
        if (urgentSale && urgentHours != null && urgentHours > 0)
          'urgentHours': urgentHours,
        'launchBoost': launchBoost,
        if (launchBoost && launchBoostHours != null && launchBoostHours > 0)
          'launchBoostHours': launchBoostHours,
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
    bool urgentSale = false,
    int? urgentHours,
    bool launchBoost = false,
    int? launchBoostHours,
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
    request.fields['urgentSale'] = urgentSale ? 'true' : 'false';
    if (urgentSale && urgentHours != null && urgentHours > 0) {
      request.fields['urgentHours'] = urgentHours.toString();
    }
    request.fields['launchBoost'] = launchBoost ? 'true' : 'false';
    if (launchBoost && launchBoostHours != null && launchBoostHours > 0) {
      request.fields['launchBoostHours'] = launchBoostHours.toString();
    }

    request.files.add(
      await http.MultipartFile.fromPath('image', File(imagePath).path),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createProductOptimized({
    required String title,
    required double price,
    String? imagePath,
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
    bool urgentSale = false,
    int? urgentHours,
    bool launchBoost = false,
    int? launchBoostHours,
    void Function(double progress01)? onUploadProgress,
    void Function(String stage)? onUploadStage,
  }) async {
    String resolvedImageUrl = imageUrl?.trim() ?? '';

    if (imagePath != null && imagePath.trim().isNotEmpty) {
      Map<String, dynamic>? uploadedVariants;
      try {
        onUploadStage?.call('Yükleme bileti alınıyor…');
        final uploadResult = await _uploadImageViaPresignedUrl(
          imagePath.trim(),
          onProgress: onUploadProgress,
          onStage: onUploadStage,
        );
        if (uploadResult != null) {
          final uploadedUrl = (uploadResult['url'] ?? '').toString().trim();
          if (uploadedUrl.isNotEmpty) resolvedImageUrl = uploadedUrl;
          final v = uploadResult['imageVariants'];
          if (v is Map<String, dynamic>) uploadedVariants = v;
        }
      } catch (_) {
        // Fallback akışı aşağıda devam eder.
      }

      if (resolvedImageUrl.isNotEmpty) {
        return createProduct(
          title: title,
          price: price,
          category: category,
          brand: brand,
          size: size,
          fabricType: fabricType,
          shoeSize: shoeSize,
          gender: gender,
          condition: condition,
          shippingType: shippingType,
          packageSize: packageSize,
          color: color,
          imageUrl: resolvedImageUrl,
          imageVariants: uploadedVariants,
          description: description,
          isSos: isSos,
          sosDiscountPercent: sosDiscountPercent,
          urgentSale: urgentSale,
          urgentHours: urgentHours,
          launchBoost: launchBoost,
          launchBoostHours: launchBoostHours,
        );
      }

      onUploadStage?.call('Yükleme (fallback) başlatılıyor…');
      return createProductWithImage(
        title: title,
        price: price,
        imagePath: imagePath,
        category: category,
        brand: brand,
        size: size,
        fabricType: fabricType,
        shoeSize: shoeSize,
        gender: gender,
        condition: condition,
        shippingType: shippingType,
        packageSize: packageSize,
        color: color,
        description: description,
        isSos: isSos,
        sosDiscountPercent: sosDiscountPercent,
        urgentSale: urgentSale,
        urgentHours: urgentHours,
        launchBoost: launchBoost,
        launchBoostHours: launchBoostHours,
      );
    }

    return createProduct(
      title: title,
      price: price,
      category: category,
      brand: brand,
      size: size,
      fabricType: fabricType,
      shoeSize: shoeSize,
      gender: gender,
      condition: condition,
      shippingType: shippingType,
      packageSize: packageSize,
      color: color,
      imageUrl: resolvedImageUrl,
      description: description,
      isSos: isSos,
      sosDiscountPercent: sosDiscountPercent,
      urgentSale: urgentSale,
      urgentHours: urgentHours,
      launchBoost: launchBoost,
      launchBoostHours: launchBoostHours,
    );
  }

  static Future<Map<String, dynamic>> getFeeQuote({
    required double amount,
    String? shippingType,
  }) async {
    final qp = <String, String>{
      'amount': amount.toString(),
      if (shippingType != null && shippingType.trim().isNotEmpty)
        'shippingType': shippingType.trim(),
    };
    final response = await http.get(
      Uri.parse('$baseUrl/fees/quote').replace(queryParameters: qp),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getOutfitRecommendations({
    required int productId,
    int limit = 6,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products/$productId/outfit-recommendations').replace(
        queryParameters: {'limit': limit.toString()},
      ),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>?> _uploadImageViaPresignedUrl(
    String imagePath, {
    void Function(double progress01)? onProgress,
    void Function(String stage)? onStage,
  }) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final fileName = imagePath.split('/').last;
    final contentType = _guessContentType(imagePath);
    final fileSize = await file.length();

    final ticket = await _withRetries(
      () => _requestUploadTicket(
        fileName: fileName,
        contentType: contentType,
        fileSize: fileSize,
      ),
      shouldRetry: _isRetryableNetworkError,
    );

    if (ticket == null) return null;

    final uploadUrl = (ticket['uploadUrl'] ?? ticket['url'] ?? '').toString();
    if (uploadUrl.isEmpty) return null;

    final rawHeaders = ticket['headers'];
    final uploadHeaders = <String, String>{
      'Content-Type': contentType,
      if (rawHeaders is Map)
        ...rawHeaders.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
    };

    // Büyük dosyaları RAM'e almamak için stream upload.
    final client = http.Client();
    try {
      onStage?.call('Görsel yükleniyor…');
      onProgress?.call(0);

      Future<http.Response> uploadOnce() async {
        final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
        request.headers.addAll(uploadHeaders);
        request.contentLength = fileSize;

        var sent = 0;
        final stream = file.openRead();
        stream.listen(
          (chunk) {
            sent += chunk.length;
            if (fileSize > 0) {
              final p = (sent / fileSize).clamp(0.0, 1.0);
              onProgress?.call(p);
            }
            request.sink.add(chunk);
          },
          onDone: request.sink.close,
          onError: (Object error, StackTrace st) => request.sink.addError(error, st),
          cancelOnError: true,
        );

        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: uploadRequestTimeoutSeconds));
        return http.Response.fromStream(streamed);
      }

      final uploadResponse = await _withRetries(
        () => uploadOnce(),
        shouldRetry: (e) => _isRetryableNetworkError(e),
      );

      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        return null;
      }

      onStage?.call('Yükleme tamamlandı, işleniyor…');
      final complete = await _withRetries(
        () => _completeUpload(ticket),
        shouldRetry: _isRetryableNetworkError,
      );
      final completedUrl = await _waitForProcessedImage(
        completeResponse: complete ?? const <String, dynamic>{},
        onStage: onStage,
      );
      final rawVariants = complete?['imageVariants'];
      final imageVariants =
          rawVariants is Map<String, dynamic> ? rawVariants : null;

      if (completedUrl.isNotEmpty) {
        return {'url': completedUrl, 'imageVariants': imageVariants};
      }

      final fallbackUrl = (ticket['publicUrl'] ??
              ticket['cdnUrl'] ??
              ticket['fileUrl'] ??
              ticket['imageUrl'] ??
              ticket['optimizedUrl'] ??
              ticket['assetUrl'] ??
              '')
          .toString();
      return fallbackUrl.isEmpty
          ? null
          : {'url': fallbackUrl, 'imageVariants': imageVariants};
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>?> _requestUploadTicket({
    required String fileName,
    required String contentType,
    required int fileSize,
  }) async {
    final payload = {
      'fileName': fileName,
      'contentType': contentType,
      'fileSize': fileSize,
      'folder': 'products',
    };

    final headers = await _authHeaders();
    final endpoints = <String>[
      '$baseUrl$uploadPresignPath',
      '$baseUrl/images/presign',
      '$baseUrl/products/images/presign',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: uploadRequestTimeoutSeconds));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final data = jsonDecode(response.body);
        final candidate = _extractUploadTicket(data);
        if (candidate != null) return candidate;
      } catch (_) {
        // bir sonraki endpoint denenecek
      }
    }

    return null;
  }

  static Map<String, dynamic>? _extractUploadTicket(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final candidates = <Map<String, dynamic>>[
      data,
      if (data['data'] is Map<String, dynamic>) data['data'] as Map<String, dynamic>,
      if (data['upload'] is Map<String, dynamic>) data['upload'] as Map<String, dynamic>,
      if (data['ticket'] is Map<String, dynamic>) data['ticket'] as Map<String, dynamic>,
    ];

    for (final c in candidates) {
      final url = (c['uploadUrl'] ?? c['url'] ?? '').toString();
      if (url.isNotEmpty) return c;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _completeUpload(
      Map<String, dynamic> ticket) async {
    final key = (ticket['key'] ?? ticket['objectKey'] ?? '').toString();
    if (key.isEmpty) return null;

    final headers = await _authHeaders();
    final payload = jsonEncode({'key': key, 'folder': 'products'});

    final endpoints = <String>[
      '$baseUrl$uploadCompletePath',
      '$baseUrl/images/complete',
      '$baseUrl/products/images/complete',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: headers,
          body: payload,
        ).timeout(const Duration(seconds: uploadRequestTimeoutSeconds));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['data'] is Map<String, dynamic>) {
            return data['data'] as Map<String, dynamic>;
          }
          return data;
        }
      } catch (_) {
        // bir sonraki endpoint denenecek
      }
    }
    return null;
  }

  static String _guessContentType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  static Map<String, dynamic> _normalizeProductsFeed(
      Map<String, dynamic> raw) {
    final data = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;

    final products = (data['products'] as List?) ??
        (data['items'] as List?) ??
        (raw['products'] as List?) ??
        const [];

    final facets = (data['facets'] as Map<String, dynamic>?) ??
        (raw['facets'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    final pageInfo = (data['pageInfo'] as Map<String, dynamic>?) ??
        (raw['pageInfo'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    final nextCursor = (pageInfo['nextCursor'] ??
            data['nextCursor'] ??
            raw['nextCursor'] ??
            '')
        .toString();

    final hasMore = pageInfo['hasMore'] == true ||
        data['hasMore'] == true ||
        raw['hasMore'] == true ||
        nextCursor.isNotEmpty;

    return {
      'success': raw['success'] != false,
      'products': products,
      'facets': facets,
      'nextCursor': nextCursor,
      'hasMore': hasMore,
      'total': pageInfo['total'] ?? data['total'] ?? raw['total'],
    };
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

  // ─── Destek Asistanı (AI Chat — HTTP) ────────────────────────────────────

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
    bool? launchBoost,
    int? launchBoostHours,
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
        if (launchBoost != null) 'launchBoost': launchBoost,
        if (launchBoost != null && launchBoost == true && launchBoostHours != null && launchBoostHours > 0)
          'launchBoostHours': launchBoostHours,
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
