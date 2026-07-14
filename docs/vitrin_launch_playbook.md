# Vitrin Launch Playbook (Türkiye)

## Amaç
- Ücretsiz, hızlı ve güvenilir ikinci el moda pazaryeri.
- İlk hedef: "ilan hızında" ve "satışa dönüşümde" rakiplerden ayrışmak.

## Konumlandırma
- **Ücretsiz ilan + düşük komisyon + hızlı satış modu + AI kombin önerisi**.
- Tek cümle değer önerisi: "30 saniyede ilan ver, aynı gün teklif al."

## Ürün Farkları (Basit ama Etkili)
1. **Acil Satış Modu**
   - 24-72 saat öne çıkan ilan.
   - Feed'de aktif acil ilanlar önde.
2. **Kombin Önerisi**
   - Ürün detayında tamamlayıcı parçalar.
   - Kural tabanlı başlayıp davranış verisi ile iyileştirme.
3. **Net Kazanç Hesaplayıcı**
   - Satıcıya satış öncesi net eline geçecek tutarı göster.
4. **AI İlan Asistanı**
   - Başlık/açıklama/fiyat bandı önerisi.

## 0-90 Gün Pazar Planı

### 0-30 Gün: Kapalı Beta (tek şehir + tek kategori)
- Şehir: İstanbul
- Kategori: Kadın giyim
- Hedef: 1.000 satıcı ilanı, 10.000 ilan görüntülenmesi
- KPI:
  - İlan yayın süresi < 30 sn
  - İlk 24 saatte teklif alma oranı > %25

### 31-60 Gün: Açık Beta ve güven katmanı
- Kargo akışı, satıcı güven sinyalleri, anlaşmazlık süreçleri.
- KPI:
  - 7 günde satışa dönüşüm > %12
  - İade/şikayet oranı < %3

### 61-90 Gün: Büyüme motoru
- Referans programı + içerik üretici iş birlikleri.
- KPI:
  - CAC geri dönüşü < 60 gün
  - 30 gün tekrar alış > %18

## Ölçüm ve Deney Çerçevesi
- Olaylar:
  - `listing_created`, `listing_marked_urgent`, `offer_created`, `offer_accepted`, `checkout_completed`
  - `outfit_reco_impression`, `outfit_reco_click`, `fee_quote_view`
- Haftalık 1 A/B testi:
  - Acil etiket görünümü
  - Kombin kart sıralaması
  - Net kazanç CTA metni

## Teknik Backlog (Uygulanabilir)

### Sprint 1 (tamamlandı)
- Acil satış alanları (`urgentSale`, `urgentHours`) ve feed boost.
- Launch boost alanları (`launchBoost`, `launchBoostHours`) ve feed önceliği.
- Satıcı panelinden launch boost düzenleme.
- Kombin önerisi endpointi.
- Komisyon/net ödeme quote endpointi.

### Sprint 2
- Ürün detay ekranında "Kombini Tamamla" yatay kartlar.
- İlan oluşturma ekranına "Acil Satış" toggle + saat seçimi.
- Ürün formunda "Net Kazanç" canlı hesaplayıcı.

### Sprint 3
- Basit AI fiyat önerisi (kategori+marka+benzer ürün ortalaması).
- Acil satış performans paneli (görüntüleme, teklif, dönüşüm).

## Türkiye’de 1 Numara İçin Disiplin
- Tek odak metric: **7 günde satışa dönüşüm**.
- Her sprintte yalnızca dönüşüm ve güvene etki eden iş.
- Coğrafi ve kategori genişlemesi sadece likidite eşiği geçilince.
