import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SellerPanelScreen extends StatefulWidget {
  const SellerPanelScreen({super.key});

  @override
  State<SellerPanelScreen> createState() => _SellerPanelScreenState();
}

class _SellerPanelScreenState extends State<SellerPanelScreen> {
  bool _loading = true;
  Map<String, dynamic>? _panel;
  List<dynamic> _products = [];
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getSellerPanel(),
        ApiService.getSellerProducts(),
        ApiService.getSellerOrders(),
      ]);
      if (!mounted) return;
      setState(() {
        _panel = results[0];
        _products = (results[1]['products'] as List?) ?? [];
        _orders = (results[2]['orders'] as List?) ?? [];
      });
    } catch (_) {
      // sessiz
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final title = TextEditingController(text: (product['title'] ?? '').toString());
    final price = TextEditingController(text: (product['price'] ?? '').toString());
    final description = TextEditingController(text: (product['description'] ?? '').toString());
    String saleStatus = (product['sale_status'] ?? 'available').toString();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ürün Düzenle'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Başlık')),
                TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Fiyat')),
                TextField(controller: description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Açıklama')),
                DropdownButtonFormField<String>(
                  value: saleStatus,
                  items: const [
                    DropdownMenuItem(value: 'available', child: Text('Satışta')),
                    DropdownMenuItem(value: 'reserved', child: Text('Rezerve')),
                    DropdownMenuItem(value: 'sold', child: Text('Satıldı')),
                  ],
                  onChanged: (v) => saleStatus = v ?? 'available',
                  decoration: const InputDecoration(labelText: 'Satış Durumu'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                await ApiService.updateSellerProduct(
                  productId: (product['id'] ?? 0) as int,
                  title: title.text.trim(),
                  description: description.text.trim(),
                  price: double.tryParse(price.text.trim()),
                  saleStatus: saleStatus,
                );
                if (!mounted) return;
                Navigator.pop(context);
                _load();
              },
              child: const Text('Kaydet'),
            )
          ],
        );
      },
    );
  }

  Future<void> _updateShipment(Map<String, dynamic> order) async {
    final tracking = TextEditingController(text: (order['tracking_no'] ?? '').toString());
    String status = (order['order_status'] ?? 'shipped').toString();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kargo Güncelle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tracking, decoration: const InputDecoration(labelText: 'Takip No')),
              DropdownButtonFormField<String>(
                value: ['packed', 'shipped', 'in_transit'].contains(status) ? status : 'shipped',
                items: const [
                  DropdownMenuItem(value: 'packed', child: Text('Hazırlandı')),
                  DropdownMenuItem(value: 'shipped', child: Text('Kargoya Verildi')),
                  DropdownMenuItem(value: 'in_transit', child: Text('Yolda')),
                ],
                onChanged: (v) => status = v ?? 'shipped',
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                await ApiService.shipOrder(
                  orderId: (order['id'] ?? 0) as int,
                  trackingNo: tracking.text.trim(),
                  shipmentStatus: status,
                );
                if (!mounted) return;
                Navigator.pop(context);
                _load();
              },
              child: const Text('Güncelle'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trust = (_panel?['trust'] as Map<String, dynamic>?) ?? {};
    final stats = (_panel?['stats'] as Map<String, dynamic>?) ?? {};

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Satıcı Paneli', style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D2D2D)))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8E8))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rozet: ${trust['badge'] ?? '-'}'),
                      Text('Puan: ${trust['rating'] ?? 0}'),
                      Text('Doğrulama: ${(trust['isVerified'] ?? false) ? 'Onaylı' : 'Bekliyor'}'),
                      const SizedBox(height: 6),
                      Text('Aktif ürün: ${stats['activeProducts'] ?? 0}'),
                      Text('Bekleyen kargo: ${stats['pendingShipments'] ?? 0}'),
                      Text('Toplam satış: ${stats['totalSales'] ?? 0}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Ürünlerim', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._products.map((p) {
                  final item = p as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8E8))),
                    child: ListTile(
                      title: Text((item['title'] ?? '').toString()),
                      subtitle: Text('₺${item['price']} • ${item['sale_status']}'),
                      trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editProduct(item)),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Text('Satış / Kargo Durumu', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._orders.map((o) {
                  final item = o as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8E8))),
                    child: ListTile(
                      title: Text((item['product_title'] ?? '').toString()),
                      subtitle: Text('Durum: ${item['order_status']} • Takip: ${((item['tracking_no'] ?? '').toString().isEmpty) ? '-' : item['tracking_no']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.local_shipping_outlined),
                            onPressed: () => _updateShipment(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () async {
                              await ApiService.markOrderDelivered((item['id'] ?? 0) as int);
                              _load();
                            },
                          )
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
