import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'comments_screen.dart';

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
  Map<String, dynamic>? _insights;
  bool _loadingInsights = true;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.initiallyFavorite;
    _loadInsights();
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
                Navigator.pop(context);
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.image, size: 56, color: Color(0xFFBDBDBD)),
            ),
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
}
