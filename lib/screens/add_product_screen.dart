import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();
  final _sizeController = TextEditingController();
  final _fabricTypeController = TextEditingController();
  final _shoeSizeController = TextEditingController();
  final _colorController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sosDiscountController = TextEditingController();

  String _gender = 'Unisex';
  String _condition = 'Yeni Gibi';
  String _shippingType = 'seller';
  String _packageSize = 'medium';
  bool _isSos = false;
  bool _isSaving = false;
  bool _isLoadingInsights = false;
  Map<String, dynamic>? _priceInsights;

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    int sosDiscount = 0;
    if (_isSos) {
      final discount = int.tryParse(_sosDiscountController.text.trim());
      if (discount == null || discount < 0 || discount > 99) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS indirim 0-99 arasında olmalıdır!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }
      sosDiscount = discount;
    }

    setState(() => _isSaving = true);
    try {
      final result = await ApiService.createProduct(
        title: _titleController.text.trim(),
        price: double.parse(_priceController.text.trim().replaceAll(',', '.')),
        category: _categoryController.text.trim(),
        brand: _brandController.text.trim(),
        size: _sizeController.text.trim(),
        fabricType: _fabricTypeController.text.trim(),
        shoeSize: _shoeSizeController.text.trim(),
        gender: _gender,
        condition: _condition,
        shippingType: _shippingType,
        packageSize: _packageSize,
        color: _colorController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        description: _descriptionController.text.trim(),
        isSos: _isSos,
        sosDiscountPercent: sosDiscount,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Ürün eklendi.'),
            backgroundColor: const Color(0xFF2D2D2D),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Hata!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı hatası'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadPriceInsights() async {
    setState(() => _isLoadingInsights = true);
    try {
      final result = await ApiService.getPriceInsights(
        title: _titleController.text.trim(),
        category: _categoryController.text.trim(),
        brand: _brandController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _priceInsights = result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Benzer fiyatlar alınamadı.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingInsights = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _sizeController.dispose();
    _fabricTypeController.dispose();
    _shoeSizeController.dispose();
    _colorController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    _sosDiscountController.dispose();
    super.dispose();
  }

  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        title: const Text('Ürün Ekle'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: _input('Ürün Başlığı *'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Başlık zorunlu' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _input('Fiyat (₺) *'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Fiyat zorunlu';
                  }
                  final p = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (p == null || p <= 0) return 'Geçerli fiyat gir';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flash_on,
                            color: Colors.red.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text('SOS Modu',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Switch(
                          value: _isSos,
                          onChanged: (val) => setState(() => _isSos = val),
                          activeColor: Colors.red.shade700,
                        ),
                      ],
                    ),
                    if (_isSos) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _sosDiscountController,
                        keyboardType: TextInputType.number,
                        decoration: _input('İndirim (0-99)'),
                        validator: (v) {
                          if (!_isSos) {
                            return null;
                          }
                          if (v == null || v.trim().isEmpty) {
                            return 'Zorunlu';
                          }
                          final d = int.tryParse(v.trim());
                          if (d == null || d < 0 || d > 99) {
                            return 'Yanlış!';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '⚡ Son 24 saat öne çıkacak!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _categoryController,
                  decoration: _input('Kategori')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _brandController,
                  decoration: _input('Marka')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                        controller: _sizeController,
                        decoration: _input('Beden')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                        controller: _shoeSizeController,
                        decoration: _input('Ayakkabı')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _fabricTypeController,
                  decoration: _input('Kumaş')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _colorController,
                  decoration: _input('Renk')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 'Kadın', child: Text('Kadın')),
                  DropdownMenuItem(value: 'Erkek', child: Text('Erkek')),
                  DropdownMenuItem(value: 'Unisex', child: Text('Unisex')),
                  DropdownMenuItem(value: 'Çocuk', child: Text('Çocuk')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'Unisex'),
                decoration: _input('Cinsiyet'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _condition,
                items: const [
                  DropdownMenuItem(
                      value: 'Yeni Etiketli', child: Text('Yeni')),
                  DropdownMenuItem(value: 'Yeni Gibi', child: Text('Gibi Yeni')),
                  DropdownMenuItem(value: 'İyi', child: Text('İyi')),
                  DropdownMenuItem(value: 'Orta', child: Text('Orta')),
                ],
                onChanged: (v) => setState(() => _condition = v ?? 'Yeni Gibi'),
                decoration: _input('Durumu'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _shippingType,
                items: const [
                  DropdownMenuItem(value: 'seller', child: Text('Satıcı')),
                  DropdownMenuItem(value: 'buyer', child: Text('Alıcı')),
                ],
                onChanged: (v) => setState(() => _shippingType = v ?? 'seller'),
                decoration: _input('Kargo'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _imageUrlController,
                  decoration: _input('Resim URL')),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                decoration: _input('Açıklama'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Açıklama zorunlu' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _packageSize,
                items: const [
                  DropdownMenuItem(value: 'small', child: Text('Küçük Paket')),
                  DropdownMenuItem(value: 'medium', child: Text('Orta Paket')),
                  DropdownMenuItem(value: 'large', child: Text('Büyük Paket')),
                ],
                onChanged: (v) => setState(() => _packageSize = v ?? 'medium'),
                decoration: _input('Paket Boyutu'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingInsights ? null : _loadPriceInsights,
                  icon: _isLoadingInsights
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.query_stats),
                  label: const Text('Benzer Ürün Fiyatlarını Gör'),
                ),
              ),
              if (_priceInsights != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Benzer Ürün Fiyat Bilgisi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('Adet: ${_priceInsights?['count'] ?? 0}'),
                      Text('Ortalama: ₺${_priceInsights?['avgPrice'] ?? '-'}'),
                      Text('Min: ₺${_priceInsights?['minPrice'] ?? '-'}'),
                      Text('Max: ₺${_priceInsights?['maxPrice'] ?? '-'}'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2D2D),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}