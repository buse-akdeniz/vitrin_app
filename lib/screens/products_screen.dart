import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'add_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool _isLoading = true;
  List<dynamic> _products = [];
  Map<String, dynamic> _facets = {};
  String? _error;

  final TextEditingController _quickSearchController = TextEditingController();
  Map<String, dynamic> _filters = {'smartMode': '1', 'sosOnly': '0'};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _quickSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.getProducts(filters: _filters);
      if (result['success'] == true) {
        setState(() {
          _products = (result['products'] as List?) ?? [];
          _facets = (result['facets'] as Map<String, dynamic>?) ?? {};
        });
      } else {
        setState(() => _error = result['message'] ?? 'Ürünler alınamadı.');
      }
    } catch (_) {
      setState(() => _error = 'Sunucuya bağlanılamadı.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openFilters() async {
    final brandController = TextEditingController(text: _filters['brand']?.toString() ?? '');
    final sizeController = TextEditingController(text: _filters['size']?.toString() ?? '');
    final fabricController = TextEditingController(text: _filters['fabricType']?.toString() ?? '');
    final shoeSizeController = TextEditingController(text: _filters['shoeSize']?.toString() ?? '');
    final colorController = TextEditingController(text: _filters['color']?.toString() ?? '');
    final minController = TextEditingController(text: _filters['minPrice']?.toString() ?? '');
    final maxController = TextEditingController(text: _filters['maxPrice']?.toString() ?? '');

    String gender = _filters['gender']?.toString() ?? '';
    String condition = _filters['condition']?.toString() ?? '';
    String shippingType = _filters['shippingType']?.toString() ?? '';
    bool bestSellers = _filters['bestSellers'] == '1';
    bool starSellers = _filters['starSellers'] == '1';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: brandController, decoration: const InputDecoration(labelText: 'Marka')),
                    TextField(controller: sizeController, decoration: const InputDecoration(labelText: 'Beden')),
                    TextField(controller: fabricController, decoration: const InputDecoration(labelText: 'Kumaş Türü')),
                    TextField(controller: shoeSizeController, decoration: const InputDecoration(labelText: 'Ayak Numarası')),
                    TextField(controller: colorController, decoration: const InputDecoration(labelText: 'Renk')),
                    DropdownButtonFormField<String>(
                      value: gender.isEmpty ? null : gender,
                      decoration: const InputDecoration(labelText: 'Cinsiyet'),
                      items: const [
                        DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
                        DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                        DropdownMenuItem(value: 'Unisex', child: Text('Unisex')),
                        DropdownMenuItem(value: 'Çocuk', child: Text('Çocuk')),
                      ],
                      onChanged: (v) => setModalState(() => gender = v ?? ''),
                    ),
                    DropdownButtonFormField<String>(
                      value: condition.isEmpty ? null : condition,
                      decoration: const InputDecoration(labelText: 'Kullanım Durumu'),
                      items: const [
                        DropdownMenuItem(value: 'Yeni Etiketli', child: Text('Yeni Etiketli')),
                        DropdownMenuItem(value: 'Yeni Gibi', child: Text('Yeni Gibi')),
                        DropdownMenuItem(value: 'İyi', child: Text('İyi')),
                        DropdownMenuItem(value: 'Orta', child: Text('Orta')),
                      ],
                      onChanged: (v) => setModalState(() => condition = v ?? ''),
                    ),
                    DropdownButtonFormField<String>(
                      value: shippingType.isEmpty ? null : shippingType,
                      decoration: const InputDecoration(labelText: 'Kargo Tipi'),
                      items: const [
                        DropdownMenuItem(value: 'buyer', child: Text('Kargo Alıcıya Ait')),
                        DropdownMenuItem(value: 'seller', child: Text('Kargo Satıcıya Ait')),
                      ],
                      onChanged: (v) => setModalState(() => shippingType = v ?? ''),
                    ),
                    TextField(controller: minController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Fiyat')),
                    TextField(controller: maxController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Fiyat')),
                    SwitchListTile(
                      value: bestSellers,
                      onChanged: (v) => setModalState(() => bestSellers = v),
                      title: const Text('En İyi Satıcılar'),
                    ),
                    SwitchListTile(
                      value: starSellers,
                      onChanged: (v) => setModalState(() => starSellers = v),
                      title: const Text('Yıldızlı Satıcılar'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() => _filters = {'smartMode': '1'});
                              Navigator.pop(context);
                              _loadProducts();
                            },
                            child: const Text('Temizle'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _filters = {
                                  'smartMode': '1',
                                  if (brandController.text.trim().isNotEmpty) 'brand': brandController.text.trim(),
                                  if (sizeController.text.trim().isNotEmpty) 'size': sizeController.text.trim(),
                                  if (fabricController.text.trim().isNotEmpty) 'fabricType': fabricController.text.trim(),
                                  if (shoeSizeController.text.trim().isNotEmpty) 'shoeSize': shoeSizeController.text.trim(),
                                  if (colorController.text.trim().isNotEmpty) 'color': colorController.text.trim(),
                                  if (gender.isNotEmpty) 'gender': gender,
                                  if (condition.isNotEmpty) 'condition': condition,
                                  if (shippingType.isNotEmpty) 'shippingType': shippingType,
                                  if (minController.text.trim().isNotEmpty) 'minPrice': minController.text.trim(),
                                  if (maxController.text.trim().isNotEmpty) 'maxPrice': maxController.text.trim(),
                                  if (bestSellers) 'bestSellers': '1',
                                  if (starSellers) 'starSellers': '1',
                                };
                              });
                              Navigator.pop(context);
                              _loadProducts();
                            },
                            child: const Text('Uygula'),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _facetChips(String title, String key, String queryKey) {
    final list = (_facets[key] as List?) ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, i) {
              final item = list[i] as Map<String, dynamic>;
              final value = (item['value'] ?? '').toString();
              return ActionChip(
                label: Text(value),
                onPressed: () {
                  setState(() => _filters[queryKey] = value);
                  _loadProducts();
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: list.length,
          ),
        ),
      ],
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
          'Ürün Akışı',
          style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _openFilters,
            icon: const Icon(Icons.tune, color: Color(0xFF2D2D2D)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const AddProductScreen()),
          );
          if (created == true) _loadProducts();
        },
        icon: const Icon(Icons.add),
        label: const Text('Ürün Ekle'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D2D2D)))
            : _error != null
                ? ListView(children: [const SizedBox(height: 120), Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))])
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _quickSearchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (value) {
                                setState(() {
                                  if (value.trim().isEmpty) {
                                    _filters.remove('q');
                                  } else {
                                    _filters['q'] = value.trim();
                                  }
                                  _filters['smartMode'] = '1';
                                });
                                _loadProducts();
                              },
                              decoration: InputDecoration(
                                hintText: 'Hızlı bul: marka, kumaş, renk...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _facetChips('Popüler Markalar', 'brands', 'brand'),
                            const SizedBox(height: 8),
                            _facetChips('Trend Renkler', 'colors', 'color'),
                          ],
                        );
                      }

                      final item = _products[index - 1] as Map<String, dynamic>;
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F1F1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.checkroom, color: Color(0xFF2D2D2D)),
                          ),
                          title: Text(
                            (item['title'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item['brand'] ?? ''} ${item['size'] ?? ''} • ${item['item_condition'] ?? ''} • ${(item['shipping_type'] ?? '') == 'buyer' ? 'Kargo Alıcı' : 'Kargo Satıcı'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF888888)),
                          ),
                          trailing: Text(
                            '₺${item['price']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D2D2D)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
