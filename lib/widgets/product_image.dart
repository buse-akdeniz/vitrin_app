import 'dart:io';
import 'package:flutter/material.dart';

class ProductImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final int retryMaxAttempts;
  final int retryBaseDelayMs;
  final bool showProcessingHint;

  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius,
    this.retryMaxAttempts = 5,
    this.retryBaseDelayMs = 450,
    this.showProcessingHint = true,
  });

  @override
  State<ProductImage> createState() => _ProductImageState();
}

class _ProductImageState extends State<ProductImage> {
  int _attempt = 0;
  int _cacheBust = 0;

  int _delayMsForAttempt(int attempt) {
    final ms = widget.retryBaseDelayMs * (1 << (attempt - 1));
    return ms.clamp(350, 2500);
  }

  void _scheduleRetry() {
    if (!mounted) return;
    if (_attempt >= widget.retryMaxAttempts) return;

    final nextAttempt = _attempt + 1;
    final delay = Duration(milliseconds: _delayMsForAttempt(nextAttempt));
    Future.delayed(delay, () {
      if (!mounted) return;
      setState(() {
        _attempt = nextAttempt;
        _cacheBust += 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.imageUrl.trim();

    Widget child;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.parse(trimmed);
      final cacheBusted = uri.replace(
        queryParameters: <String, String>{
          ...uri.queryParameters,
          if (_cacheBust > 0) '_cb': '$_cacheBust',
        },
      );

      child = Image.network(
        cacheBusted.toString(),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        loadingBuilder: (context, w, progress) {
          if (progress == null) return w;
          return _placeholder(
            showHint: widget.showProcessingHint,
            hint: 'Yükleniyor…',
          );
        },
        errorBuilder: (_, __, ___) {
          _scheduleRetry();
          final hint = _attempt < widget.retryMaxAttempts
              ? 'Görsel işleniyor…'
              : 'Görsel yüklenemedi';
          return _placeholder(showHint: widget.showProcessingHint, hint: hint);
        },
      );
    } else if (trimmed.isNotEmpty) {
      child = Image.file(
        File(trimmed),
        width: widget.width,
        height: widget.height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _placeholder(showHint: false, hint: 'Görsel bulunamadı'),
      );
    } else {
      child = _placeholder(showHint: false, hint: 'Görsel yok');
    }

    if (widget.borderRadius == null) return child;
    return ClipRRect(borderRadius: widget.borderRadius!, child: child);
  }

  Widget _placeholder({required bool showHint, required String hint}) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFF1F1F1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image, color: Color(0xFFBDBDBD)),
            if (showHint) ...[
              const SizedBox(height: 6),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8A8A8A),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
