/// Resolves the best display URL from product API payloads (snake_case / camelCase).
String resolveProductImageUrl(Map<String, dynamic> item, {bool preferLarge = false}) {
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
    final preferred = preferLarge
        ? [
            variants['large'],
            variants['medium'],
            variants['small'],
            variants['original'],
          ]
        : [
            variants['medium'],
            variants['small'],
            variants['large'],
            variants['original'],
          ];
    for (final v in preferred) {
      final text = (v ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
  }

  return '';
}
