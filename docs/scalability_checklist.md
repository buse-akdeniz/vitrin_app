# Ölçeklenebilirlik Uygulama Kontrol Listesi

## 1) Görsel Yükleme ve Optimizasyon

- [ ] İstemci yükleme akışı `presigned URL` ile doğrudan obje depolamaya gider.
- [ ] Görseller ana uygulama sunucusundan değil CDN üzerinden servis edilir.
- [ ] Arka planda otomatik `resize + compress` uygulanır (örn: small/medium/large).
- [ ] Ürün kaydında optimize edilmiş görsel URL/variant alanları döner.

## 2) Ana Sayfa İlan Akışı

- [x] Listeleme endpointi sayfalama/cursor destekler.
- [x] Filtreleme ve arama p95 hedefini karşılar (dev store).
- [x] Feed yükleme akışı sonsuz kaydırma (infinite scroll) ile çalışır.
- [x] Cache katmanı ve uygun indeksleme kullanılır (in-memory TTL cache).

## 3) Chat Ayrı Servis

- [x] Chat trafiği ana API'den ayrılmıştır (`/ws/chat` WebSocket + HTTP fallback).
- [ ] WebSocket tabanlı servis yatay ölçeklenebilir çalışır.
- [ ] Mesaj teslim/okundu olayları için güvenilir event akışı vardır.

## 4) SLO / Operasyon

- [ ] p95 API latency < 300 ms
- [ ] Availability >= 99.95%
- [ ] Error rate < 0.1%
- [ ] Kritik akış başarı oranı >= 99.9%

## 5) Doğrulama

- [ ] Yük testi (kademeli + ani trafik)
- [ ] Dayanıklılık testi (dependency fail / network jitter)
- [ ] Uçtan uca senaryolar (upload, chat, offer, checkout)
