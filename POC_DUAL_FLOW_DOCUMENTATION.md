# POC Dual-Flow Feature Documentation

## Overview

Bu belge POC (Proof of Concept) dual-flow özelliğinin kullanım, API, ve test senaryolarını detaylı olarak açıklar.

## Feature Description

POC dual-flow, Proof of Concept sürecini iki farklı workflow'a ayırır:

### 1. **Ön PoC (Preliminary PoC)** - Hızlı Excel Tabanlı Validasyon
- **Amaç**: Ürünün temel uyumluluğunu hızlı bir şekilde kontrol etmek
- **Süreç**: 
  1. Excel şablonu indir
  2. Şirket bilgileri, ürün detayları ve temel puanları doldur
  3. Dosyayı sisteme yükle
  4. Veriler otomatik olarak işlenir ve doğrulanır
  5. PDF rapor oluştur
  6. Kapsamlı PoC'ye dönüştür (opsiyonel)
- **Süre**: 5-15 dakika

### 2. **Kapsamlı PoC (Comprehensive PoC)** - Detaylı Değerlendirme
- **Amaç**: Ürünün tüm yönlerini kapsamlı olarak değerlendirmek
- **Özellikler**: Tüm mevcut PoC özellikleri devam eder
- **Süre**: 30-60 dakika

## API Endpoints

### 1. POC Başlat - POST /pocs/flow/start

**Request:**
```json
{
  "flowType": "PRELIMINARY" | "COMPREHENSIVE",
  "productId": "uuid",
  "title": "Optional POC Title",
  "description": "Optional description",
  "notes": "Optional notes"
}
```

**Response (200 OK):**
```json
{
  "id": "poc-uuid",
  "flowType": "PRELIMINARY",
  "status": "DRAFT",
  "excelTemplateUrl": "template-filename.xlsx",
  "message": "Ön PoC başlatıldı. Excel şablonunu indirin."
}
```

**Error Responses:**
- `400 Bad Request`: Ürün veya kullanıcı bulunamadı
- `401 Unauthorized`: Kimlik doğrulaması başarısız
- `500 Internal Server Error`: Sunucu hatası

### 2. Excel Template İndir - GET /pocs/preliminary/:id/template

**Response:** Excel dosyası (.xlsx)

**Template Şemasında Şu Alanlar Vardır:**
- **PoC Bilgileri**: Şirket Adı, E-posta, Sektör, Web Sitesi
- **Ürün Bilgileri**: Ürün Adı, Kategori, Teknik Uyum (0-5), İş Uyum (0-5)
- **Değerlendirme**: Güvenlik (0-5), Esneklik (0-5), Ölçeklenebilirlik (0-5)

### 3. Excel Veri Yükle - POST /pocs/preliminary/:id/upload

**Request:** multipart/form-data
- `file`: Excel dosyası (.xlsx)

**Response (200 OK):**
```json
{
  "id": "poc-uuid",
  "status": "PENDING",
  "message": "Excel dosyası başarıyla yüklendi ve işlendi",
  "data": {
    "companyInfo": {
      "Şirket Adı": "Örnek Ltd.",
      "E-posta": "info@example.com",
      "Sektör": "Teknoloji"
    },
    "productInfo": {
      "Ürün Adı": "Ürün X",
      "Kategori": "B2B"
    },
    "evaluationData": {
      "Teknik Uyum": 4,
      "İş Uyum": 5,
      "Güvenlik": 4
    }
  },
  "warnings": [
    "Row 3: Eksik kritik veri"
  ]
}
```

**Validation Rules:**
- Excel dosyası formatı: .xlsx
- Gerekli sheet: "PoC Bilgileri"
- Gerekli sütunlar: "Şirket Adı", "E-posta", "Sektör"
- E-posta formatı: valid@email.com
- Puanlar: 0-5 arasında sayı

**Error Response:**
```json
{
  "statusCode": 400,
  "message": {
    "message": "Excel dosyası doğrulaması başarısız",
    "errors": [
      "Gerekli sheet 'PoC Bilgileri' bulunamadı",
      "Row 5: Geçersiz e-posta adresi: invalid-email"
    ],
    "warnings": [
      "Row 3: Eksik kritik veri"
    ]
  }
}
```

### 4. PDF Rapor Oluştur - GET /pocs/preliminary/:id/report

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Rapor başarıyla oluşturuldu",
  "reportPath": "/uploads/reports/poc-report-uuid.pdf",
  "filename": "poc-report-uuid.pdf"
}
```

### 5. POC Detaylarını Getir - GET /pocs/:id

**Response (200 OK):**
```json
{
  "id": "poc-uuid",
  "productId": "product-uuid",
  "enterpriseId": "enterprise-uuid",
  "status": "PENDING",
  "pocType": "CUSTOM",
  "flowType": "PRELIMINARY",
  "results": {
    "companyInfo": {...},
    "productInfo": {...},
    "evaluationData": {...}
  },
  "notes": "İlk gözlemler",
  "createdAt": "2024-01-15T10:00:00Z"
}
```

### 6. Kullanıcı POC'lerini Listele - GET /pocs

**Query Parameters:**
- `status` (optional): DRAFT, PENDING, APPROVED, REJECTED
- `flowType` (optional): PRELIMINARY, COMPREHENSIVE

**Response (200 OK):**
```json
[
  {
    "id": "poc-uuid",
    "title": "POC Title",
    "status": "PENDING",
    "flowType": "PRELIMINARY",
    "productId": "product-uuid",
    "createdAt": "2024-01-15T10:00:00Z"
  }
]
```

## Frontend Components

### 1. PoCTypeSelector Modal

**Props:**
```typescript
interface PoCTypeSelectorProps {
  isOpen: boolean;
  onClose: () => void;
  onSelect: (flowType: 'PRELIMINARY' | 'COMPREHENSIVE') => Promise<void>;
  productId: string;
  isLoading?: boolean;
}
```

**Özellikler:**
- İki POC türü arasında seçim yapılabilir
- Visual cards ile clear açıklama
- Loading state'i göster
- Error handling

### 2. PreliminaryPoCPage

**Özellikler:**
- 3 adımlı workflow
  1. Template indirme
  2. Dosya yükleme
  3. Yüklenen verileri gösterme
- Validation warnings gösterimi
- PDF rapor oluşturma
- Kapsamlı PoC'ye dönüştürme seçeneği

### 3. API Route Handlers

```
/api/pocs/flow/start
/api/pocs/[id]
/api/pocs/preliminary/[id]/template
/api/pocs/preliminary/[id]/upload
/api/pocs/preliminary/[id]/report
```

## Test Scenarios

### Scenario 1: Başarılı Ön PoC Akışı

**Adımlar:**
1. Dashboard'da "Yeni PoC Başlat" düğmesine tıkla
2. "Ön PoC (Preliminary)" seçeneğini seç
3. Excel template'i indir
4. Template'i tümüyle doldur
5. Dosyayı sisteme yükle
6. Yüklenen verileri kontrol et
7. PDF rapor oluştur
8. Kapsamlı PoC'ye dönüştür

**Beklenen Sonuç:**
- ✅ Tüm adımlar başarıyla tamamlanır
- ✅ Veriler sisteme kaydedilir
- ✅ PDF rapor oluşturulur
- ✅ Hiç hata mesajı gösterilmez

### Scenario 2: Excel Validasyon Hataları

**Adımlar:**
1. Template'i kısmi doldur (zorunlu alanları eksik bırak)
2. E-posta alanına geçersiz değer yaz (örn: "not-an-email")
3. Puan alanına 0-5 aralığı dışında değer yaz (örn: 10)
4. Dosyayı yükle

**Beklenen Sonuç:**
- ✅ Validasyon hataları gösterilir
- ✅ Hatalar açık ve anlaşılır şekilde açıklanır
- ✅ Dosya işlenmez
- ✅ Kullanıcı hatayı düzeltme talimatı alır

**Örnek Hatalar:**
- "Gerekli alan 'E-posta' başlık satırında bulunamadı"
- "Row 5: Geçersiz e-posta adresi: invalid-email"
- "Row 3, Column 7: Puan 0-5 arasında olmalıdır (10)"

### Scenario 3: Validasyon Uyarıları

**Adımlar:**
1. Template'i doldur (zorunlu alanları koy, opsiyonel alanları boş bırak)
2. Dosyayı yükle

**Beklenen Sonuç:**
- ✅ Dosya yüklenir ve işlenir
- ✅ Uyarılar gösterilir (kritik olmayan)
- ✅ Veriler sisteme kaydedilir

**Örnek Uyarılar:**
- "Row 3: Eksik kritik veri"
- "Web Sitesi alanı boş"

### Scenario 4: Kapsamlı PoC'ye Dönüştürme

**Adımlar:**
1. Ön PoC'yi tamamla
2. PDF rapor oluştur
3. "Rapor Oluştur & Kapsamlı PoC'ye Dönüştür" düğmesine tıkla

**Beklenen Sonuç:**
- ✅ PDF rapor oluşturulur
- ✅ PoC Kapsamlı sürece dönüştürülür
- ✅ Verileri kapsamlı sayfaya aktarılır
- ✅ Kullanıcı yeni sayfaya yönlendirilir

### Scenario 5: API Error Handling

**Adımlar:**
1. Var olmayan PoC ID'si ile template indir
2. Boş file ile upload et
3. Geçersiz kullanıcı token'ı ile istek yap

**Beklenen Sonuç:**
- ✅ 404 hatası: "PoC bulunamadı"
- ✅ 400 hatası: "Dosya yükleniniz"
- ✅ 401 hatası: "Unauthorized"

## Backend Services

### PoCDualFlowService

**Sorumluluklar:**
- POC başlatma (Preliminary/Comprehensive)
- Excel veri yükleme ve işleme
- POC detaylarını getirme
- Kullanıcı POC'lerini listeleme

**Önemli Metodlar:**
```typescript
startPreliminaryPoC(userId, productId, enterpriseId): Promise<any>
startComprehensivePoC(userId, productId, enterpriseId): Promise<any>
uploadPreliminaryData(pocId, fileBuffer): Promise<any>
generatePreliminaryReport(pocId): Promise<any>
getPoC(pocId): Promise<any>
listUserPocs(enterpriseId): Promise<any>
```

### ExcelService

**Sorumluluklar:**
- Excel template oluşturma
- Excel dosyası parsing
- Dosya I/O işlemleri

### EnhancedExcelService

**Sorumluluklar:**
- Excel dosyası validasyonu
- E-posta ve puan validation
- Hata ve uyarı raporlama

### PdfReportService

**Sorumluluklar:**
- PDF rapor oluşturma
- Sayfa styling ve formatting
- Puan görselleri

## Security Considerations

1. **Authentication**: Tüm uç noktalar JWT token gerektiriyor
2. **Authorization**: Kullanıcılar sadece kendi POC'lerini görebiliyor
3. **File Validation**: Dosya türü ve içeriği doğrulanıyor
4. **Data Validation**: Tüm giriş verileri validate ediliyor

## Performance Considerations

1. **Excel Processing**: Buffer'da işlenir, disk yazma minimize edilir
2. **PDF Generation**: Async işlem, blocking yok
3. **File Cleanup**: Eski dosyalar 48 saatte silinir
4. **Database**: POC'ler lazy loading ile yüklenir

## Error Handling Strategy

1. **Validation Errors**: 400 Bad Request + detaylı hata listesi
2. **Authorization Errors**: 401 Unauthorized
3. **Not Found Errors**: 404 Not Found
4. **Server Errors**: 500 Internal Server Error + log

## Future Enhancements

1. **Multi-language Support**: İngilizce/Türkçe seçim
2. **Template Customization**: Kuruluşa özel template'ler
3. **Advanced Reporting**: Grafik ve trend analizi
4. **Integration**: CRM ve ERP sistemlerine entegrasyon
5. **Collaboration**: Takım üyeleriyle ortak çalışma
6. **Automation**: Otomatik veri çekme ve doldurma

## Testing Checklist

- [ ] POC Başlatma Endpoints
  - [ ] Ön PoC başlatma
  - [ ] Kapsamlı PoC başlatma
  - [ ] Geçersiz product ID hatası
  - [ ] Kimlik doğrulaması hatası

- [ ] Excel İşlemleri
  - [ ] Template indirme
  - [ ] Geçerli dosya yükleme
  - [ ] Geçersiz format hatası
  - [ ] Missing zorunlu alanlar
  - [ ] E-posta validasyonu
  - [ ] Puan range validasyonu

- [ ] Rapor Oluşturma
  - [ ] PDF oluşturma başarısı
  - [ ] Sayfa formatting
  - [ ] Görsel puan gösterimi

- [ ] API Response
  - [ ] Status codes
  - [ ] Error messages
  - [ ] Response headers

- [ ] Frontend
  - [ ] Modal açılıp kapanması
  - [ ] File input işlevi
  - [ ] Error/warning gösterimi
  - [ ] Loading states
  - [ ] Navigation

## Support

Sorular veya sorunlar için:
- Backend Issues: openpoc-backend repository
- Frontend Issues: v0-open-po-c-dashboard-design-2 repository
- API Documentation: /api/docs (Swagger)
