# OpenPoC Platform

Açık kaynaklı Proof of Concept (PoC) yönetim platformu. Enterprise ve Startup şirketleri arasında ürün değerlendirme ve test süreçlerini otomatikleştirir.

## 🚀 Özellikler

- **İntegre Geliştirme Ortamı**: Backend (NestJS) ve Frontend (Next.js) birlikte çalışır
- **WebSocket Desteği**: Gerçek zamanlı PoC workflow güncellemeleri
- **JWT Kimlik Doğrulama**: Güvenli token tabanlı yetkilendirme
- **PostgreSQL Database**: Prisma ORM ile yönetilen veritabanı
- **Dinamik Workflow**: 7 aşamalı PoC yaşam döngüsü (PROPOSAL → CONTRACT_REVIEW → KICKOFF → TESTING → EVALUATION → REPORTING → COMPLETED)
- **Unified API Client**: Otomatik token injection ve hata yönetimi

## 📋 Teknoloji Stack

### Backend
- **Framework**: NestJS v10.4.22
- **Database**: PostgreSQL + Prisma ORM
- **Real-time**: Socket.io v4.6.1
- **Auth**: JWT (7-day access, 1-hour refresh)
- **API**: REST + WebSocket

### Frontend
- **Framework**: Next.js v16.0.0 (Turbopack)
- **HTTP Client**: Axios with interceptors
- **State Management**: React Context API
- **Real-time**: Socket.io-client
- **UI**: Responsive React Components

## 🛠️ Kurulum

### Gereksinimler
- Node.js v20+
- PostgreSQL 12+
- npm veya pnpm

### Başlangıç

```bash
# Tüm bağımlılıkları yükle
npm run install:all

# Geliştirme sunucularını başlat
npm run dev

# Backend: http://127.0.0.1:4041/api
# Frontend: http://localhost:3000
```

### Diğer Komutlar

```bash
# Uygulamayı oluştur
npm run build:all

# Temizle (node_modules, dist)
npm run clean

# Docker konteynerini başlat
docker-compose up
```

## 📁 Proje Yapısı

```
projects/
├── openpoc-backend/           # NestJS API sunucusu
│   ├── src/
│   │   ├── app.module.ts
│   │   ├── main.ts
│   │   ├── pocs/              # PoC yönetimi
│   │   ├── products/          # Ürün yönetimi
│   │   ├── companies/         # Şirket profilleri
│   │   ├── auth/              # JWT kimlik doğrulama
│   │   └── ...
│   └── prisma/                # Database schema
│
├── openpoc-frontend/          # Next.js dashboard
│   └── v0-open-po-c-dashboard-design-2/
│       ├── app/
│       │   ├── layout.tsx
│       │   ├── dashboard/
│       │   └── ...
│       ├── components/
│       │   ├── account-context.tsx
│       │   ├── platform-context.tsx
│       │   └── ...
│       └── lib/
│           └── api-client.ts
│
├── package.json               # Root npm scripts
├── docker-compose.yml         # Docker konfigürasyonu
└── dev-setup.ps1             # PowerShell dev script

```

## 🔌 API Endpoints

### Health Check
- `GET /api/health` - Sunucu durumu

### Accounts
- `GET /api/accounts` - Kullanıcı hesapları
- `POST /api/accounts/enterprise` - Kurumsal hesap oluştur

### PoCs
- `GET /api/pocs` - Tüm PoC'ler
- `POST /api/pocs` - Yeni PoC oluştur
- `POST /api/pocs/:pocId/advance-stage` - PoC aşamasını ilerlet
- `WebSocket /pocs` - Gerçek zamanlı güncellemeler

### Companies
- `GET /api/api/companies` - Şirketler
- `POST /api/api/companies` - Yeni şirket

### Products
- `GET /api/api/products` - Ürünler
- `POST /api/api/products` - Yeni ürün

## 🔐 Kimlik Doğrulama

JWT token kullanılır. Request header'ında:

```
Authorization: Bearer {access_token}
```

## 🐛 Sorun Giderme

### Backend port zaten kullanımda
```bash
# Eski process'leri sonlandır
Get-Process node | Stop-Process -Force

# Tekrar başlat
npm run dev
```

### Frontend build hatası
```bash
# node_modules temizle
npm run clean

# Yeniden yükle
npm install
npm run dev
```

### Database bağlantısı başarısız
```bash
# .env dosyasını kontrol et
# DATABASE_URL değerinin doğru olduğundan emin ol
# PostgreSQL sunucusu çalışıyor mu kontrol et
```

## 📝 Commit Konvansiyonları

```
feat: Yeni özellik
fix: Hata düzeltmesi
refactor: Kod yeniden düzenlenmesi
docs: Dokümantasyon
style: Kod stilinde değişiklik
test: Test eklenmesi
chore: Dış bağımlılık güncellemesi
```

## 🚀 Deployment

### Docker ile
```bash
docker-compose up -d
```

### Manual
```bash
# Backend
cd openpoc-backend
npm install
npm run build
NODE_ENV=production npm start

# Frontend
cd openpoc-frontend/v0-open-po-c-dashboard-design-2
npm install
npm run build
npm start
```

## 📞 İletişim

- **GitHub Issues**: Hata bildir ve özellik iste
- **Email**: dev@openpoc.local

## 📄 Lisans

MIT
