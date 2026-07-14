import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'comments_screen.dart';
import '../utils/product_image_url.dart';
import '../widgets/product_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool initiallyFavorite;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.initiallyFavorite = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isFavorite = false;
  bool _isFollowingSeller = false;
  Map<String, dynamic>? _insights;
  bool _loadingInsights = true;
  List<Map<String, dynamic>> _outfitRecommendations = const [];
  bool _loadingOutfitRecommendations = true;

  String _resolveProductImage(Map<String, dynamic> item) {
    final direct = [
      item['image_cdn_url'],
      item['image_url'],
      item['imageUrl'],
      item['thumbnail_url'],
      item['thumbnailUrl'],
    ];

    for (final v in direct) {
      final text = (v ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }

    final variants = item['image_variants'] ?? item['imageVariants'];
    if (variants is Map<String, dynamic>) {
      final preferred = [
        variants['large'],
        variants['medium'],
        variants['small'],
        variants['original'],
      ];
      for (final v in preferred) {
        final text = (v ?? '').toString().trim();
        if (text.isNotEmpty) return text;
      }
    }

    return '';
  }

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initiallyFavorite;
    _loadInsights();
    _loadFollowStatus();
    _loadOutfitRecommendations();
  }

  Future<void> _loadFollowStatus() async {
    final sellerId = (widget.product['seller_id'] ?? widget.product['user_id'] ?? 0) as int;
    if (sellerId <= 0) return;
    try {
      final result = await ApiService.getFollowedSellers();
      final sellers = (result['sellers'] as List?) ?? [];
      final followed = sellers.any((s) => (s as Map<String, dynamic>)['seller_id'] == sellerId);
      if (!mounted) return;
      setState(() => _isFollowingSeller = followed);
    } catch (_) {
      // sessiz
    }
  }

  Future<void> _toggleFollowSeller() async {
    final sellerId = (widget.product['seller_id'] ?? widget.product['user_id'] ?? 0) as int;
    if (sellerId <= 0) return;
    final result = _isFollowingSeller
        ? await ApiService.unfollowSeller(sellerId)
        : await ApiService.followSeller(sellerId);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _isFollowingSeller = !_isFollowingSeller);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((result['message'] ?? 'İşlem tamamlandı').toString())),
      );
    }
  }

  Future<void> _loadInsights() async {
    try {
      final result = await ApiService.getPriceInsights(
        title: (widget.product['title'] ?? '').toString(),
        category: (widget.product['category'] ?? '').toString(),
        brand: (widget.product['brand'] ?? '').toString(),
      );
      if (!mounted) return;
      setState(() => _insights = result);
    } catch (_) {
      // sessiz
    } finally {
      if (mounted) setState(() => _loadingInsights = false);
    }
  }

  Future<void> _loadOutfitRecommendations() async {
    final productId = (widget.product['id'] ?? 0) as int;
    if (productId <= 0) {
      if (mounted) setState(() => _loadingOutfitRecommendations = false);
      return;
    }

    try {
      final result = await ApiService.getOutfitRecommendations(productId: productId);
      final items = (result['recommendations'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
      if (!mounted) return;
      setState(() => _outfitRecommendations = items);
    } catch (_) {
      // sessiz
    } finally {
      if (mounted) setState(() => _loadingOutfitRecommendations = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final productId = (widget.product['id'] ?? 0) as int;
    final result = _isFavorite
        ? await ApiService.removeFavorite(productId)
        : await ApiService.addFavorite(productId);

    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((result['message'] ?? 'İşlem tamamlandı').toString())),
      );
    }
  }

  Future<void> _openOfferDialog() async {
    final controller = TextEditingController();
    final productId = (widget.product['id'] ?? 0) as int;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Teklif Ver'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Teklif Tutarı (₺)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(controller.text.trim());
                if (amount == null || amount <= 0) return;
                final result = await ApiService.createOffer(
                  productId: productId,
                  amount: amount,
                );
                if (!mounted) return;
                Navigator.pop(this.context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text((result['message'] ?? 'İşlem tamamlandı').toString())),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D2D2D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Gönder'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final packageSize = (p['package_size'] ?? 'medium').toString();
    final packageLabel = packageSize == 'small'
        ? 'Küçük Paket'
        : packageSize == 'large'
            ? 'Büyük Paket'
            : 'Orta Paket';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Ürün Detayı',
          style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: _toggleFollowSeller,
            icon: Icon(_isFollowingSeller ? Icons.person_remove_alt_1 : Icons.person_add_alt_1),
            label: Text(_isFollowingSeller ? 'Takiptesin' : 'Takip Et'),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          ProductImage(
            imageUrl: _resolveProductImage(p),
            width: double.infinity,
            height: 240,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 12),
          Text(
            (p['title'] ?? '').toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '₺${p['price']}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('${p['brand'] ?? ''}'),
              _chip('${p['size'] ?? ''}'),
              _chip('${p['item_condition'] ?? ''}'),
              _chip(packageLabel),
              _chip((p['shipping_type'] ?? 'seller') == 'buyer'
                  ? 'Kargo Alıcı'
                  : 'Kargo Satıcı'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Column(
              if (_loadingOutfitRecommendations || _outfitRecommendations.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: _loadingOutfitRecommendations
                      ? const SizedBox(
                          height: 72,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2D2D2D),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kombini Tamamla',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Bu parçaya uyacak öneriler',
                              style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 208,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _outfitRecommendations.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final item = _outfitRecommendations[index];
                                  return _outfitCard(item);
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ],
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ürün Açıklaması',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text((p['description'] ?? 'Açıklama girilmemiş.').toString()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: _loadingInsights
                ? const SizedBox(
                    height: 38,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Benzer Ürün Fiyatları',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Adet: ${_insights?['count'] ?? 0}'),
                      Text('Ortalama: ₺${_insights?['avgPrice'] ?? '-'}'),
                      Text('Min: ₺${_insights?['minPrice'] ?? '-'}'),
                      Text('Max: ₺${_insights?['maxPrice'] ?? '-'}'),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? Colors.red : const Color(0xFF2D2D2D),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommentsScreen(
                        productId: (p['id'] ?? 0) as int,
                        productTitle: (p['title'] ?? '').toString(),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Yorumlar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openOfferDialog,
                  icon: const Icon(Icons.local_offer_outlined),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2D2D),
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Teklif Ver'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _outfitCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final brand = (item['brand'] ?? '').toString();
    final price = (item['price'] ?? '').toString();
    final imageUrl = _resolveProductImage(item);
    final isUrgent = item['is_urgent_active'] == true;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: item),
          ),
        );
      },
      child: SizedBox(
        width: 142,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ProductImage(
                  imageUrl: imageUrl,
                  width: 142,
                  height: 142,
                  borderRadius: BorderRadius.circular(14),
                ),
                if (isUrgent)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Acil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              brand.isNotEmpty ? '$brand • $title' : title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '₺$price',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D2D2D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
