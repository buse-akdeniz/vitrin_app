import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CommentsScreen extends StatefulWidget {
  final int productId;
  final String productTitle;

  const CommentsScreen({
    super.key,
    required this.productId,
    required this.productTitle,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  List<dynamic> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.getComments(widget.productId);
      if (!mounted) return;
      setState(() => _comments = (result['comments'] as List?) ?? []);
    } catch (_) {
      // sessiz
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    try {
      final result = await ApiService.addComment(productId: widget.productId, content: text);
      if (!mounted) return;
      if (result['success'] == true) {
        _commentController.clear();
        _loadComments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text((result['message'] ?? 'Yorum eklenemedi').toString())),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sunucuya bağlanılamadı.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Yorumlar • ${widget.productTitle}',
          style: const TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D2D2D)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _comments.length,
                    itemBuilder: (_, i) {
                      final c = _comments[i] as Map<String, dynamic>;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((c['user_name'] ?? 'Kullanıcı').toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text((c['content'] ?? '').toString()),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Yorum yaz...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _sending ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D2D2D),
                      foregroundColor: Colors.white,
                    ),
                    child: _sending ? const Text('...') : const Text('Gönder'),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
