# 📦 Palet Takip Sistemi - Teknik Dokümantasyon

Bu doküman, "Palet Takip Sistemi" projesinin tüm teknik detaylarını, şifrelerini, API uç noktalarını ve işleyiş mantığını içerir. İleride sisteme müdahale edilmesi gerektiğinde bu rehber kullanılmalıdır.

---

## 🏗️ 1. Sistem Mimarisi ve Deployment Kuralı (ÖNEMLİ ⚠️)

**Bu proje Raspberry Pi 5 üzerinde Coolify ile çalışır.** 
*   **Geliştirme:** Windows PC'de yapılır.
*   **Deploy:** Kod GitHub'a pushlanır -> Coolify otomatik çeker ve sunucuyu günceller.
*   **KURAL:** Windows'ta `node server.js` veya script çalıştırmak **SADECE LOCALİ ETKİLER**. Pi üzerindeki sunucuya müdahale etmek için **API Endpoints** kullanılmalı veya Coolify paneline gidilmelidir.

Sistem üç ana parçadan oluşur:
1.  **Backend (Sunucu):** Raspberry Pi üzerinde çalışan Node.js sunucusu.
2.  **Frontend (Web Paneli):** Tarayıcı erişimi.
3.  **Mobil Uygulama (Flutter):** Android APK.

### 🌐 Erişim Bilgileri
*   **Web Paneli Adresi:** [https://paletsayim.atilimgida.com](https://paletsayim.atilimgida.com) (Local Ağ: `http://192.168.1.104:3000`)
*   **Sunucu IP:** `192.168.1.104`
*   **Sunucu Port:** `3000`

---

## 🔑 2. Şifreler ve Yetkili Girişleri

Sistemde kullanılan kritik şifreler aşağıdadır:

| Alan | Kullanıcı Adı | Şifre | Açıklama |
| :--- | :--- | :--- | :--- |
| **Mobil Ayarlar Menüsü** | - | **1234** | Uygulama içindeki "Ayarlar" ve "Veritabanını Sıfırla" menüsüne giriş için. |
| **Web Panel Girişi** | admin | **1234** | (Eğer giriş ekranı aktif edilirse) Yönetici girişi. |
| **Raspberry Pi SSH** | user | *(Bilinmiyor)* | Sunucuya terminal erişimi gerekirse. (Genelde SSH anahtarı ile girilir). |

---

## ⚙️ 3. Mobil Uygulama İşleyişi

### Senkronizasyon (Sync)
*   **Çalışma Mantığı:** Uygulama hem çevrimdışı (offline) hem çevrimiçi çalışır.
*   **Otomatik Sync:** Uygulama her **10 saniyede bir** arka planda sunucuyla haberleşir.
*   **Veri Akışı:**
    *   Telefondaki yeni kayıtlar -> Sunucuya gönderilir.
    *   Sunucudaki yeni kayıtlar -> Telefona çekilir.
    *   Webden silinen kayıtlar -> Telefondan da silinir.

### "Son İşlemler" Listesi
*   **24 Saat Kuralı:** Ana ekrandaki "Son İşlemler" listesi **SADECE BUGÜN** yapılan işlemleri gösterir.
*   **Sıfırlama:** Gece 00:00'dan sonra liste otomatik olarak temizlenir (eski kayıtlar raporda kalır, ana ekrandan kalkar).
*   **Sıralama:** Kayıtlar `entry_time` (İşlem Saati) parametresine göre sıralanır, böylece karışıklık olmaz.

---

## 🔌 4. API Endpoints (Sunucu Servisleri)

Mobil uygulama ve Web paneli aşağıdaki adreslerle haberleşir.

### 🟢 Genel
*   `GET /api/status`: Sunucunun çalışıp çalışmadığını kontrol eder. IP adresini ve çalışma süresini döner.

### 📦 Stok & Veri
*   `GET /api/pallets`: Tüm aktif palet stok listesini getirir.
*   `POST /api/sync`: **(Ana Damar)** Senkronizasyon servisidir. Mobil, elindeki veriyi buraya gönderir.
    *   *Özellik:* Eğer gelen veri "İADE" (RETURNED) ise ve tarihi varsa, veritabanına `return_date` olarak işler.

### 🔙 İade İşlemleri
*   `POST /api/return`: Web veya Mobilden iade yapıldığında çalışır.
    *   *Parametreler:* `firm_name`, `pallet_type`, `count`, `note`
    *   *İşlev:* Belirtilen firmadan, belirtilen sayıda ve tipteki paleti "IN_STOCK" durumundan "RETURNED" durumuna çeker ve o günün tarihini atar.

### ⚠️ Admin / Temizlik (Tehlikeli)
*   `GET /api/admin/clear-today`: Sadece **BUGÜN** girilen verileri siler ve bugün yapılan iadeleri geri alır.
### 3. API Endpoints
Base URL: `http://192.168.1.104:3000` (veya `http://paletsayim.atilimgida.com`)

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | `/api/status` | Sunucu durumu (Health check) |
| GET | `/api/sync` | Son senkronizasyondan sonra değişen/eklenen kayıtları çeker (`?last_sync=...`) |
| GET | `/api/sync-all` | Tüm kayıtları çeker (Full sync) |
| POST | `/api/entry` | Palet girişi yapar (Entry) - *Artık kullanılmıyor, sync ile yapılıyor* |
| POST | `/api/return` | Palet çıkışı yapar (Legacy - FIFO bazlı) |
| POST | `/api/return-batch` | **[YENİ]** Palet çıkışı yapar (ID bazlı - Kesin Eşleşme) |
| GET | `/api/pallets` | Web dashboard için tüm kayıtları listeler |
| GET | `/api/admin/clear-all`| Veritabanını tamamen temizler |

---

## 🗄️ 5. Veritabanı Yapısı (SQLite)

Veritabanı dosyası: `backend/palet_v2.db`

**Tablo: `pallets`**
| Sütun | Tip | Açıklama |
| :--- | :--- | :--- |
| `local_id` | TEXT (PK) | Benzersiz Takip Kodu (UUID). Her palet/işlem için özeldir. |
| `firm_name` | TEXT | Firma Adı (BEYPILIC, METRO vb.) |
| `pallet_type` | TEXT | 'Plastik' veya 'Tahta' |
| `entry_date` | TEXT | Giriş Tarihi (YYYY-MM-DD) |
| `return_date` | TEXT | **İade Tarihi (YYYY-MM-DD).** İade raporları buna göre çalışır. |
| `status` | TEXT | 'IN_STOCK' (Stokta) veya 'RETURNED' (İade Edildi) |
| `note` | TEXT | Açıklama / Not |

---

## 🛠️ 6. Sorun Giderme (Troubleshooting)

**Soru: Mobilde iadeler raporlarda görünmüyor.**
*   *Çözüm:* Uygulamanın güncel olduğundan emin olun. Yeni sistemde "return_date" sütunu kullanılıyor. Eski sürümler bunu desteklemez.

**Soru: "Son İşlemler" listesi çok karışık.**
*   *Çözüm:* Liste otomatik olarak sadece bugünü gösterir. Telefonun tarih/saat ayarını kontrol edin.

**Soru: Sunucu hatası (502) alıyorum.**
*   *Çözüm:* Web, sunucuya ulaşamıyor olabilir. `server.js` dosyasının çalıştığından ve veritabanı şemasının (`return_date` sütunu ekli mi?) doğru olduğundan emin olun. Coolify üzerinden "Restart" etmeyi deneyin.

**Soru: Verileri tamamen sıfırlamak istiyorum.**
1.  Tarayıcıdan `http://192.168.1.104:3000/api/admin/clear-all` adresine git (Sunucuyu siler).
2.  Mobilden `Ayarlar > Şifre: 1234 > Veritabanını Sıfırla` yap (Telefonu siler).

---
*Hazırlayan: Antigravity AI - 06.01.2026*
