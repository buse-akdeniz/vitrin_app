import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'products_screen.dart';
import 'support_chat_screen.dart';
import 'product_detail_screen.dart';
import '../widgets/product_image.dart';
import 'notifications_screen.dart';
import 'buyer_panel_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _sosProducts = [];
  List<dynamic> _followedSellers = [];
  List<dynamic> _recommendedProducts = [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _badgeTimer;
  int _unreadNotificationCount = 0;
  int _activeOrderBadgeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
    _loadBadges();
    _badgeTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadBadges(),
    );
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    try {
      final results = await Future.wait([
        ApiService.getUnreadNotificationCount(),
        ApiService.getBuyerOrderBadges(),
      ]);

      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = (results[0]['unreadCount'] ?? 0) as int;
        _activeOrderBadgeCount =
            ((results[1]['badges'] as Map<String, dynamic>?)?['activeShipmentCount'] ?? 0) as int;
      });
    } catch (_) {
      // sessiz
    }
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: const Color(0xFF2D2D2D)),
        if (count > 0)
          Positioned(
            right: -6,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadHomeData() async {
    await Future.wait([
      _loadSosProducts(),
      _loadFollowedSellers(),
      _loadRecommendedProducts(),
    ]);
  }

  Future<void> _loadSosProducts() async {
    try {
      final result = await ApiService.getProducts(filters: {'sosOnly': '1'});
      if (!mounted) return;
      setState(() {
        _sosProducts = result['products'] ?? [];
      });
    } catch (_) {
      // Hata sessiz geç
    }
  }

  Future<void> _loadFollowedSellers() async {
    try {
      final result = await ApiService.getFollowedSellers();
      if (!mounted) return;
      setState(() {
        _followedSellers = (result['sellers'] as List?) ?? [];
      });
    } catch (_) {
      // sessiz
    }
  }

  Future<void> _loadRecommendedProducts() async {
    try {
      final result = await ApiService.getRecommendedProducts();
      if (!mounted) return;
      setState(() {
        _recommendedProducts = (result['products'] as List?) ?? [];
      });
    } catch (_) {
      // sessiz
    }
  }

  Future<void> _logout(BuildContext context) async {
    await ApiService.deleteToken();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openSearchResults() {
    final query = _searchController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(initialQuery: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Vitrin',
          style: TextStyle(
            color: Color(0xFF2D2D2D),
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: _buildBadgeIcon(Icons.shopping_bag_outlined, _activeOrderBadgeCount),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuyerPanelScreen()),
              );
              _loadBadges();
            },
          ),
          IconButton(
            icon: _buildBadgeIcon(Icons.notifications_none, _unreadNotificationCount),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
              _loadBadges();
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF2D2D2D)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF2D2D2D)),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D2D),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.checkroom,
                        color: Colors.white, size: 42),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Hoş geldin! 🎉',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Yeni ürünleri keşfetmeye başla',
                    style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _openSearchResults(),
                    decoration: InputDecoration(
                      hintText: 'Ürün, marka veya açıklama ara...',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _openSearchResults,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductsScreen()),
                    ),
                    icon: const Icon(Icons.storefront),
                    label: const Text('Ürün Akışını Aç'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2D2D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
            // SOS Carousel
            if (_sosProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Son 24 Saat / Acil Satılıklar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_sosProducts.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _sosProducts.take(5).map((p) {
                          final discountPercent = p['sos_discount_percent'] ?? 0;
                          final originalPrice = p['price'] ?? 0;
                          final discountedPrice = originalPrice * (1 - discountPercent / 100);
                          
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                  product: Map<String, dynamic>.from(p),
                                ),
                              ),
                            ),
                            child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 160,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade300, width: 2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      height: 120,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF0F0F0),
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(12)),
                                      ),
                                      child: ProductImage(
                                        imageUrl: (p['image_url'] ?? '').toString(),
                                        width: 160,
                                        height: 120,
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '-%$discountPercent',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['title'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2D2D2D),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '₺${discountedPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '₺${originalPrice.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                              color: Color(0xFF888888),
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
                          ),
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            if (_followedSellers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Takip Ettiklerin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _followedSellers.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final s = _followedSellers[i] as Map<String, dynamic>;
                          final sellerName = (s['seller_name'] ?? 'Satıcı').toString();
                          return ActionChip(
                            label: Text(sellerName),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductsScreen(initialQuery: sellerName),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (_recommendedProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Senin İçin Öneriler',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _recommendedProducts.take(6).length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final p = _recommendedProducts[i] as Map<String, dynamic>;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                product: Map<String, dynamic>.from(p),
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE8E8E8)),
                            ),
                            child: Row(
                              children: [
                                ProductImage(
                                  imageUrl: (p['image_url'] ?? '').toString(),
                                  width: 58,
                                  height: 58,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (p['title'] ?? '').toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        (p['seller_name'] ?? '').toString(),
                                        style: const TextStyle(
                                          color: Color(0xFF888888),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₺${p['price']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportChatScreen()),
          );
        },
        backgroundColor: const Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.support_agent),
        label: const Text('AI Destek'),
      ),
    );
  }
}