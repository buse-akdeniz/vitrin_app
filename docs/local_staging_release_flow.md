# Lokal/Staging -> Railway Geçiş Akışı

Bu akış Railway canlıya çıkmadan önce teknik riskleri sıralı şekilde kapatmak içindir.

## Faz 1 — Lokal/Staging geliştirme

- [x] Acil satış alanları (`urgentSale`, `urgentHours`) eklendi
- [x] Launch boost alanları (`launchBoost`, `launchBoostHours`) eklendi
- [x] Kombin önerisi endpointi eklendi
- [x] Ücret hesap (`/api/fees/quote`) endpointi eklendi
- [x] Flutter ürün oluşturma ekranına acil satış kontrolleri eklendi
- [x] Flutter ürün oluşturma ekranına launch boost kontrolleri eklendi
- [x] Satıcı paneline launch boost düzenleme eklendi
- [x] Ürün detay ekranına kombin önerileri eklendi

## Faz 2 — Akış stabilizasyonu

- [x] Sıralı smoke runner eklendi: [backend/scripts/stabilization_smoke.mjs](../backend/scripts/stabilization_smoke.mjs)
- [x] Lokal komut: `npm run smoke:local`
- [x] Staging komut: `npm run smoke:staging`

Kapsanan temel akışlar:

- Auth (register/login/unauthorized)
- İlan oluşturma ve feed sıralaması (launch boost > urgent)
- Ücret hesap başarılı + hata senaryosu
- Kombin önerisi başarılı + 404 senaryosu
- Teklif -> karşı teklif -> kabul -> sipariş oluşumu
- Upload presign/complete başarılı + hata senaryoları

## Faz 3 — Hata senaryoları ve regresyon

- [x] Unauthorized erişim doğrulaması
- [x] Geçersiz ürün/anahtar senaryoları
- [x] Upload boyut limiti senaryosu
- [ ] İsteğe bağlı: CI içinde otomatik smoke koşumu (GitHub Actions)

## Faz 4 — Railway canlıya geçiş

Canlı geçiş öncesi minimum kapı:

- [x] `smoke:local` yeşil
- [ ] `smoke:staging` yeşil
- [ ] Secret rotation tamamlandı (`UPLOAD_API_TOKEN`, `AUTH_SALT`)
- [ ] CloudFront + bucket policy doğrulandı
- [ ] Flutter prod build + smoke tamamlandı
