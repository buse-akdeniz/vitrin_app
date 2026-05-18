import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'add_product_screen.dart';
import 'offers_screen.dart';
import 'favorites_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isEditing = false;

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getProfile();
      if (result['success'] == true) {
        setState(() {
          _user = result['user'];
          _nameController.text = _user?['name'] ?? '';
          _bioController.text = _user?['bio'] ?? '';
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (result['success'] == true) {
        setState(() {
          _user = result['user'];
          _isEditing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profil güncellendi ✓'),
              backgroundColor: const Color(0xFF2D2D2D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profilim',
            style: TextStyle(
                color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2D2D2D)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text('Düzenle',
                  style: TextStyle(
                      color: Color(0xFF2D2D2D), fontWeight: FontWeight.w600)),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Kaydet',
                  style: TextStyle(
                      color: Color(0xFF2D2D2D), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D2D2D)))
          : _user == null
              ? const Center(child: Text('Profil yüklenemedi'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D2D2D),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Center(
                          child: Text(
                            (_user?['name'] as String?)?.isNotEmpty == true
                                ? (_user!['name'] as String)
                                    .substring(0, 1)
                                    .toUpperCase()
                                : (_user?['email'] as String?)
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // E-posta
                      Text(
                        _user?['email'] ?? '',
                        style: const TextStyle(
                            color: Color(0xFF888888), fontSize: 14),
                      ),
                      const SizedBox(height: 32),

                      // Ad Alanı
                      _buildField(
                        label: 'Ad Soyad',
                        controller: _nameController,
                        icon: Icons.person_outline,
                        enabled: _isEditing,
                        hint: 'Adını gir',
                      ),
                      const SizedBox(height: 16),

                      // Bio Alanı
                      _buildField(
                        label: 'Hakkımda',
                        controller: _bioController,
                        icon: Icons.info_outline,
                        enabled: _isEditing,
                        hint: 'Kendinden bahset...',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: _quickAction(
                              icon: Icons.add_box_outlined,
                              label: 'Ürün Yükle',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AddProductScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _quickAction(
                              icon: Icons.local_offer_outlined,
                              label: 'Tekliflerim',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const OffersScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _quickAction(
                              icon: Icons.favorite_border,
                              label: 'Favoriler',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const FavoritesScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Üyelik tarihi
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                color: Color(0xFF888888), size: 18),
                            const SizedBox(width: 10),
                            const Text('Üyelik tarihi: ',
                                style: TextStyle(
                                    color: Color(0xFF888888), fontSize: 13)),
                            Text(
                              (_user?['created_at'] as String?)
                                      ?.split(' ')
                                      .first ??
                                  '-',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF888888)),
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: Color(0xFF888888)),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2D2D2D), width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF2D2D2D), size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF2D2D2D)),
            ),
          ],
        ),
      ),
    );
  }
}
