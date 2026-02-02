# OpenPoC - PoC Türü Sistemi Tasarımı

**Tarih:** 2 Şubat 2026  
**Versiyon:** 1.0  
**Durum:** Design & Implementation Plan

---

## 📋 İçindekiler

1. [Sistem Mimarisi](#sistem-mimarisi)
2. [Database Schema](#database-schema)
3. [Backend API Tasarımı](#backend-api-tasarımı)
4. [Frontend Bileşenleri](#frontend-bileşenleri)
5. [Excel Sistem](#excel-sistem)
6. [Validasyon Kuralları](#validasyon-kuralları)
7. [Lifecycle Akışları](#lifecycle-akışları)
8. [Edge Cases](#edge-cases)
9. [Implementasyon Sırası](#implementasyon-sırası)

---

## 1. Sistem Mimarisi

### 1.1 Üst Seviye Mimari

```
┌─────────────────────────────────────────────────────────┐
│                     Frontend (Next.js)                   │
├─────────────────────────────────────────────────────────┤
│  Dashboard │ PoC Selection Modal │ Pre-PoC Form │ Full-PoC Form
└─────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────┐
│              API Layer (NestJS + Express)               │
├─────────────────────────────────────────────────────────┤
│ /api/poc/create                                          │
│ /api/poc/upload-excel                                   │
│ /api/poc/download-template                              │
│ /api/poc/list                                           │
│ /api/poc/:id/status                                     │
└─────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────┐
│         Business Logic & Validation Layer               │
├─────────────────────────────────────────────────────────┤
│ PoCService │ ExcelService │ ValidationService           │
└─────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────┐
│           Database & Storage Layer                      │
├─────────────────────────────────────────────────────────┤
│ PostgreSQL (PoC, PoCItem) │ S3/MinIO (Excel Files)      │
└─────────────────────────────────────────────────────────┘
```

### 1.2 Karar Ağacı

```
Kullanıcı: "Yeni PoC Talebi" → Modal Açılır
                  ↓
        ┌─────────────────────┐
        │  PoC Türü Seç       │
        └────────┬────────────┘
           /            \
          /              \
    ÖN POC (PRE_POC)    KAPSAMLI POC (FULL_POC)
         ↓                        ↓
    Excel Upload          Form Doldur
         ↓                        ↓
    Validasyon            Validasyon
         ↓                        ↓
    Excel Uploaded        Requested
    Status                Status
         ↓                        ↓
    Kullanıcı Haberdar   Firma Haberdar
```

---

## 2. Database Schema

### 2.1 PoC Entity (Güncellenmiş)

```sql
-- Table: poc
CREATE TABLE poc (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Temel bilgiler
  pocType ENUM('PRE_POC', 'FULL_POC') NOT NULL,
  status ENUM('DRAFT', 'EXCEL_UPLOADED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 
              'REQUESTED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'DRAFT',
  
  -- İlişkiler
  requesterCompanyId UUID NOT NULL REFERENCES company(id),
  requesterUserId UUID NOT NULL REFERENCES "user"(id),
  targetCompanyId UUID NOT NULL REFERENCES company(id),
  targetProductId UUID NOT NULL REFERENCES product(id),
  
  -- Ön PoC Alanları
  excelFileUrl VARCHAR(500) NULL,  -- Pre-PoC için dosya URL
  excelFileName VARCHAR(255) NULL, -- Özgün dosya adı
  excelUploadedAt TIMESTAMP NULL,
  excelValidationErrors JSONB NULL, -- Doğrulama hataları varsa
  
  -- Kapsamlı PoC Alanları (Full-PoC için)
  title VARCHAR(255) NULL,
  description TEXT NULL,
  objectives TEXT[] NULL,
  duration INTEGER NULL, -- Gün cinsinden
  budget DECIMAL(15,2) NULL,
  technicalRequirements JSONB NULL,
  expectedOutcome TEXT NULL,
  
  -- Metrikler
  progress INTEGER DEFAULT 0,
  metrics JSONB[] NULL, -- PoC metrikleri
  evaluationCriteria JSONB[] NULL,
  
  -- Zaman bilgileri
  estimatedStartDate DATE NULL,
  estimatedEndDate DATE NULL,
  actualStartDate TIMESTAMP NULL,
  actualEndDate TIMESTAMP NULL,
  
  -- Meta
  notes TEXT NULL,
  tags VARCHAR(50)[] NULL,
  
  -- Timestamps
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  createdBy UUID NOT NULL REFERENCES "user"(id),
  
  -- İndeksler
  INDEX idx_requesterCompanyId (requesterCompanyId),
  INDEX idx_targetCompanyId (targetCompanyId),
  INDEX idx_pocType (pocType),
  INDEX idx_status (status),
  INDEX idx_createdAt (createdAt DESC)
);

-- Table: poc_pre_poc_data (Ön PoC spesifik veriler)
CREATE TABLE poc_pre_poc_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pocId UUID NOT NULL REFERENCES poc(id) ON DELETE CASCADE,
  
  -- Excel'den parse edilen veriler
  companyProfile JSONB NOT NULL, -- Şirket profil bilgileri
  currentSituation JSONB NOT NULL, -- Mevcut durum
  objectives JSONB[] NOT NULL, -- Hedefler (JSON array)
  scope JSONB NOT NULL, -- Kapsam
  timeline JSONB NOT NULL, -- Zaman çizelgesi
  
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: poc_excel_template_version (Template versiyonlama)
CREATE TABLE poc_excel_template_version (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  version VARCHAR(20) NOT NULL UNIQUE, -- v1.0, v1.1, etc
  fileUrl VARCHAR(500) NOT NULL,
  columns JSONB NOT NULL, -- Kolonların schema'sı
  description TEXT,
  isActive BOOLEAN DEFAULT true,
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 2.2 Entity Relationships

```
User (1) ──────── (M) PoC
         requester
         
Company (1) ──────── (M) PoC
          requester
          
Product (1) ──────── (M) PoC
```

---

## 3. Backend API Tasarımı

### 3.1 Endpoint Özeti

| Method | Endpoint | Açıklama | Auth |
|--------|----------|----------|------|
| GET | `/api/poc/templates` | Excel template indirme | ✅ |
| POST | `/api/poc/create` | PoC oluştur (type seç) | ✅ |
| POST | `/api/poc/:id/upload-excel` | Excel dosyası yükle | ✅ |
| POST | `/api/poc/:id/validate-excel` | Excel validasyon (batch) | ✅ |
| GET | `/api/poc/list` | PoC listesi (filtreli) | ✅ |
| GET | `/api/poc/:id` | PoC detayı | ✅ |
| PUT | `/api/poc/:id` | PoC güncelle | ✅ |
| DELETE | `/api/poc/:id` | PoC sil | ✅ |
| GET | `/api/poc/:id/excel/download` | Yüklenen Excel'i indir | ✅ |

### 3.2 Detaylı Endpoint Specs

#### 3.2.1 Excel Template İndir

```typescript
// GET /api/poc/templates?version=latest

interface ExcelTemplateResponse {
  templateId: string;
  version: string;
  downloadUrl: string;
  fileName: string;
  description: string;
  requiredColumns: string[];
  sampleData: Record<string, any>;
  createdAt: string;
}
```

#### 3.2.2 PoC Oluştur

```typescript
// POST /api/poc/create

interface CreatePoCRequest {
  pocType: 'PRE_POC' | 'FULL_POC';
  targetProductId: string;
  targetCompanyId: string;
  
  // Ön PoC için
  prePoC?: {
    // Excel zorunlu olmadan draft oluşturulabilir
  };
  
  // Kapsamlı PoC için
  fullPoC?: {
    title: string;
    description: string;
    objectives: string[];
    duration?: number;
    budget?: number;
    technicalRequirements?: Record<string, any>;
  };
}

interface CreatePoCResponse {
  id: string;
  pocType: string;
  status: string;
  createdAt: string;
  nextAction: 'UPLOAD_EXCEL' | 'FILL_FORM' | 'SUBMIT_REQUEST';
}
```

#### 3.2.3 Excel Upload & Validasyon

```typescript
// POST /api/poc/:id/upload-excel
// Content-Type: multipart/form-data

interface UploadExcelRequest {
  file: File; // .xlsx dosya
}

interface ExcelValidationError {
  row: number;
  column: string;
  error: string;
  severity: 'ERROR' | 'WARNING';
}

interface UploadExcelResponse {
  success: boolean;
  fileUrl: string;
  fileName: string;
  uploadedAt: string;
  
  // Validasyon sonuçları
  validations: {
    isValid: boolean;
    errors: ExcelValidationError[];
    warnings: ExcelValidationError[];
    summary: {
      totalRows: number;
      validRows: number;
      invalidRows: number;
    };
  };
  
  // Auto-parsed veriler (başarılıysa)
  parsedData?: {
    companyProfile: Record<string, any>;
    currentSituation: Record<string, any>;
    objectives: any[];
    scope: Record<string, any>;
    timeline: Record<string, any>;
  };
}
```

#### 3.2.4 PoC Listesi (Filtreli)

```typescript
// GET /api/poc/list?type=PRE_POC&status=EXCEL_UPLOADED&page=1&limit=20

interface ListPoCsQuery {
  type?: 'PRE_POC' | 'FULL_POC';
  status?: string[];
  requesterCompanyId?: string;
  targetCompanyId?: string;
  targetProductId?: string;
  dateFrom?: string;
  dateTo?: string;
  page?: number;
  limit?: number;
  sortBy?: 'createdAt' | 'updatedAt' | 'status';
  sortOrder?: 'ASC' | 'DESC';
}

interface PoCListItem {
  id: string;
  pocType: 'PRE_POC' | 'FULL_POC';
  status: string;
  title?: string;
  requesterCompany: {
    id: string;
    name: string;
    logo?: string;
  };
  targetCompany: {
    id: string;
    name: string;
  };
  targetProduct: {
    id: string;
    name: string;
  };
  progress?: number;
  excelFileName?: string;
  excelUploadedAt?: string;
  createdAt: string;
  updatedAt: string;
  badge: {
    type: 'PRE_POC' | 'FULL_POC';
    label: string;
    color: string;
    icon: string;
  };
}

interface ListPoCsResponse {
  items: PoCListItem[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    pages: number;
  };
  summary: {
    totalPrePoCCount: number;
    totalFullPoCCount: number;
    byStatus: Record<string, number>;
  };
}
```

### 3.3 Error Handling

```typescript
// Standart Error Response
interface ErrorResponse {
  error: {
    code: string;
    message: string;
    statusCode: number;
    details?: Record<string, any>;
    timestamp: string;
    traceId: string;
  };
}

// Error Codes
enum PoCErrorCode {
  POC_TYPE_INVALID = 'POC_TYPE_INVALID',
  EXCEL_FORMAT_INVALID = 'EXCEL_FORMAT_INVALID',
  EXCEL_MISSING_COLUMNS = 'EXCEL_MISSING_COLUMNS',
  EXCEL_VALIDATION_FAILED = 'EXCEL_VALIDATION_FAILED',
  FILE_SIZE_EXCEEDED = 'FILE_SIZE_EXCEEDED',
  MISSING_REQUIRED_FIELDS = 'MISSING_REQUIRED_FIELDS',
  POC_NOT_FOUND = 'POC_NOT_FOUND',
  INVALID_STATE_TRANSITION = 'INVALID_STATE_TRANSITION',
  UNAUTHORIZED_OPERATION = 'UNAUTHORIZED_OPERATION',
}
```

---

## 4. Frontend Bileşenleri

### 4.1 Bileşen Hiyerarşisi

```
DashboardPage
├── PoCSection
│   ├── PoCTypeSelector
│   ├── PrePoCList
│   │   └── PoCListItem (badge with PRE_POC)
│   └── FullPoCList
│       └── PoCListItem (badge with FULL_POC)
│
NewPoCModal
├── PoCTypeChoice
│   ├── PrePoCOption
│   └── FullPoCOption
│
├── PrePoCForm
│   ├── PoCBasicInfo
│   ├── ExcelUploadZone
│   ├── ExcelPreview
│   └── SubmitButton
│
└── FullPoCForm
    ├── PoCBasicInfo
    ├── PoCObjectives
    ├── TechnicalRequirements
    └── SubmitButton
```

### 4.2 Component Kodları

#### 4.2.1 PoC Türü Seçici Modal

```typescript
// components/poc/poc-type-selector.tsx

import React, { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { FileText, BookOpen } from 'lucide-react';

export type PoCType = 'PRE_POC' | 'FULL_POC';

interface PoCTypeSelectorProps {
  open: boolean;
  onClose: () => void;
  onSelectType: (type: PoCType) => void;
  isLoading?: boolean;
}

export function PoCTypeSelector({
  open,
  onClose,
  onSelectType,
  isLoading = false,
}: PoCTypeSelectorProps) {
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>Yeni PoC Talebi Oluştur</DialogTitle>
          <DialogDescription>
            PoC türünü seçerek başlayın. Her türün kendine özel akışı vardır.
          </DialogDescription>
        </DialogHeader>

        <div className="grid grid-cols-2 gap-4 py-6">
          {/* Ön PoC Seçeneği */}
          <Card
            className="p-6 cursor-pointer hover:shadow-lg hover:border-blue-500 transition-all"
            onClick={() => !isLoading && onSelectType('PRE_POC')}
          >
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <FileText className="h-8 w-8 text-yellow-500" />
                <span className="text-xs font-semibold text-yellow-600 bg-yellow-50 px-2 py-1 rounded">
                  🟡 ÖN POC
                </span>
              </div>
              <div>
                <h3 className="font-semibold text-lg mb-2">Ön PoC (Pre-PoC)</h3>
                <p className="text-sm text-muted-foreground mb-4">
                  Hızlı değerlendirme ve fizibilite kontrolü için Excel tabanlı çalışma
                </p>
              </div>
              <ul className="space-y-2 text-xs text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="text-yellow-600 mt-0.5">✓</span>
                  <span>Excel şablonu indir</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-yellow-600 mt-0.5">✓</span>
                  <span>Verilerinizi doldur</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-yellow-600 mt-0.5">✓</span>
                  <span>Sisteme yükle ve değerlendir</span>
                </li>
              </ul>
              <Button
                className="w-full mt-4 bg-yellow-600 hover:bg-yellow-700"
                onClick={() => onSelectType('PRE_POC')}
                disabled={isLoading}
              >
                Ön PoC Başlat
              </Button>
            </div>
          </Card>

          {/* Kapsamlı PoC Seçeneği */}
          <Card
            className="p-6 cursor-pointer hover:shadow-lg hover:border-blue-600 transition-all"
            onClick={() => !isLoading && onSelectType('FULL_POC')}
          >
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <BookOpen className="h-8 w-8 text-blue-500" />
                <span className="text-xs font-semibold text-blue-600 bg-blue-50 px-2 py-1 rounded">
                  🔵 KAPSAMLI
                </span>
              </div>
              <div>
                <h3 className="font-semibold text-lg mb-2">Kapsamlı PoC (Full-PoC)</h3>
                <p className="text-sm text-muted-foreground mb-4">
                  Detaylı işletme ve teknik gereksinimleriyle tam PoC süreci
                </p>
              </div>
              <ul className="space-y-2 text-xs text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="text-blue-600 mt-0.5">✓</span>
                  <span>Detaylı form doldur</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-blue-600 mt-0.5">✓</span>
                  <span>Teknik gereksinimler ekle</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="text-blue-600 mt-0.5">✓</span>
                  <span>Takip ve değerlendirme yapı</span>
                </li>
              </ul>
              <Button
                className="w-full mt-4 bg-blue-600 hover:bg-blue-700"
                onClick={() => onSelectType('FULL_POC')}
                disabled={isLoading}
              >
                Kapsamlı PoC Başlat
              </Button>
            </div>
          </Card>
        </div>

        <div className="text-xs text-center text-muted-foreground">
          Karar yapıyorsanız, <strong>Ön PoC</strong> ile başlayıp daha sonra{' '}
          <strong>Kapsamlı PoC</strong>'ye geçiş yapabilirsiniz.
        </div>
      </DialogContent>
    </Dialog>
  );
}
```

#### 4.2.2 Ön PoC Form

```typescript
// components/poc/forms/pre-poc-form.tsx

import React, { useState } from 'react';
import { useForm } from 'react-hook-form';
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { ExcelUploadZone } from '@/components/poc/excel-upload-zone';
import { ExcelPreview } from '@/components/poc/excel-preview';
import { useToast } from '@/hooks/use-toast';
import { Download, Loader2 } from 'lucide-react';

interface PrePoCFormProps {
  targetProductId: string;
  targetCompanyId: string;
  onSuccess?: (pocId: string) => void;
  onCancel?: () => void;
}

interface PrePoCFormData {
  title: string;
  description?: string;
  excelFile?: File;
}

export function PrePoCForm({
  targetProductId,
  targetCompanyId,
  onSuccess,
  onCancel,
}: PrePoCFormProps) {
  const { toast } = useToast();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [excelFile, setExcelFile] = useState<File | null>(null);
  const [excelData, setExcelData] = useState<any>(null);

  const form = useForm<PrePoCFormData>({
    defaultValues: {
      title: '',
      description: '',
    },
  });

  const onDownloadTemplate = async () => {
    try {
      const response = await fetch('/api/poc/templates?version=latest');
      if (!response.ok) throw new Error('Template indiremedi');

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'poc-template-v1.0.xlsx';
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);

      toast({
        title: 'Başarılı',
        description: 'Excel şablonu indirildi',
      });
    } catch (error) {
      toast({
        title: 'Hata',
        description: 'Şablon indirilemedi',
        variant: 'destructive',
      });
    }
  };

  const onExcelSelected = async (file: File) => {
    setExcelFile(file);
    // Excel preview fetch edecek
    // setExcelData(...);
  };

  const onSubmit = async (data: PrePoCFormData) => {
    if (!excelFile) {
      toast({
        title: 'Uyarı',
        description: 'Excel dosyası yüklemelisiniz',
        variant: 'destructive',
      });
      return;
    }

    setIsSubmitting(true);
    try {
      // 1. PoC oluştur
      const createResponse = await fetch('/api/poc/create', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          pocType: 'PRE_POC',
          targetProductId,
          targetCompanyId,
          prePoC: {
            title: data.title,
            description: data.description,
          },
        }),
      });

      if (!createResponse.ok) throw new Error('PoC oluşturulamadı');
      const pocData = await createResponse.json();

      // 2. Excel yükle
      const formData = new FormData();
      formData.append('file', excelFile);

      const uploadResponse = await fetch(
        `/api/poc/${pocData.id}/upload-excel`,
        {
          method: 'POST',
          body: formData,
        }
      );

      if (!uploadResponse.ok) throw new Error('Excel yüklenemedi');
      const uploadData = await uploadResponse.json();

      if (!uploadData.validations.isValid) {
        toast({
          title: 'Validasyon Hataları',
          description: `${uploadData.validations.errors.length} hata bulundu`,
          variant: 'destructive',
        });
        return;
      }

      toast({
        title: 'Başarılı',
        description: 'Ön PoC oluşturuldu ve Excel yüklendi',
      });

      onSuccess?.(pocData.id);
    } catch (error: any) {
      toast({
        title: 'Hata',
        description: error.message,
        variant: 'destructive',
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Adım 1: Temel Bilgiler */}
      <Card className="p-6">
        <h3 className="text-lg font-semibold mb-4">1️⃣ Temel Bilgiler</h3>
        <Form {...form}>
          <form className="space-y-4">
            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>PoC Başlığı</FormLabel>
                  <FormControl>
                    <Input placeholder="Örn: CRM Entegrasyonu Ön Değerlendirmesi" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Açıklama (İsteğe Bağlı)</FormLabel>
                  <FormControl>
                    <textarea
                      className="min-h-24 rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                      placeholder="Bu PoC hakkında ek bilgiler..."
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </form>
        </Form>
      </Card>

      {/* Adım 2: Excel İndirme */}
      <Card className="p-6 border-2 border-dashed border-yellow-300 bg-yellow-50">
        <h3 className="text-lg font-semibold mb-4">2️⃣ Excel Şablonunu İndir</h3>
        <p className="text-sm text-muted-foreground mb-4">
          Verilerinizi dolduracağınız Excel şablonunu indirin. Şablon alanların açıklamasını ve örnek
          verilerini içerir.
        </p>
        <Button
          variant="outline"
          onClick={onDownloadTemplate}
          className="gap-2"
        >
          <Download className="h-4 w-4" />
          Excel Şablonunu İndir
        </Button>
      </Card>

      {/* Adım 3: Excel Yükle */}
      <Card className="p-6">
        <h3 className="text-lg font-semibold mb-4">3️⃣ Doldurulan Excel'i Yükle</h3>
        <ExcelUploadZone
          onFileSelected={onExcelSelected}
          maxSizeMB={10}
          accept=".xlsx"
        />

        {excelFile && (
          <div className="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg">
            <p className="text-sm">
              <strong>Dosya:</strong> {excelFile.name} ({(excelFile.size / 1024).toFixed(2)} KB)
            </p>
          </div>
        )}
      </Card>

      {/* Adım 4: İşlemler */}
      <div className="flex gap-3 justify-end">
        <Button variant="outline" onClick={onCancel} disabled={isSubmitting}>
          İptal
        </Button>
        <Button
          onClick={form.handleSubmit(onSubmit)}
          disabled={isSubmitting || !form.watch('title') || !excelFile}
        >
          {isSubmitting && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
          PoC Oluştur ve Gönder
        </Button>
      </div>
    </div>
  );
}
```

#### 4.2.3 Excel Upload Zone

```typescript
// components/poc/excel-upload-zone.tsx

import React, { useCallback } from 'react';
import { Card } from '@/components/ui/card';
import { Upload, AlertCircle, CheckCircle2 } from 'lucide-react';
import { cn } from '@/lib/utils';

interface ExcelUploadZoneProps {
  onFileSelected: (file: File) => void;
  maxSizeMB?: number;
  accept?: string;
  disabled?: boolean;
  validationErrors?: any[];
}

export function ExcelUploadZone({
  onFileSelected,
  maxSizeMB = 10,
  accept = '.xlsx',
  disabled = false,
  validationErrors,
}: ExcelUploadZoneProps) {
  const [isDragging, setIsDragging] = React.useState(false);
  const [file, setFile] = React.useState<File | null>(null);
  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const handleDragEnter = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  }, []);

  const handleDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setIsDragging(false);

      const droppedFiles = e.dataTransfer.files;
      if (droppedFiles.length > 0) {
        handleFileSelect(droppedFiles[0]);
      }
    },
    []
  );

  const handleFileSelect = (selectedFile: File) => {
    // Dosya tipi kontrolü
    if (!selectedFile.name.endsWith('.xlsx')) {
      // Hata mesajı göster
      return;
    }

    // Dosya boyutu kontrolü
    const sizeMB = selectedFile.size / (1024 * 1024);
    if (sizeMB > maxSizeMB) {
      // Hata mesajı göster
      return;
    }

    setFile(selectedFile);
    onFileSelected(selectedFile);
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files?.[0]) {
      handleFileSelect(e.target.files[0]);
    }
  };

  return (
    <div className="space-y-4">
      <Card
        className={cn(
          'border-2 border-dashed p-8 transition-colors cursor-pointer',
          isDragging && 'border-blue-500 bg-blue-50',
          disabled && 'opacity-50 cursor-not-allowed',
          file && 'border-green-500 bg-green-50'
        )}
        onDragEnter={handleDragEnter}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={() => !disabled && fileInputRef.current?.click()}
      >
        <div className="flex flex-col items-center gap-2 text-center">
          {file ? (
            <>
              <CheckCircle2 className="h-8 w-8 text-green-600" />
              <div>
                <p className="font-medium text-green-900">Dosya seçildi</p>
                <p className="text-sm text-green-700">{file.name}</p>
              </div>
            </>
          ) : (
            <>
              <Upload className="h-8 w-8 text-muted-foreground" />
              <div>
                <p className="font-medium">Excel dosyasını buraya sürükleyin</p>
                <p className="text-sm text-muted-foreground">
                  veya tıklayarak seçin ({maxSizeMB}MB'a kadar)
                </p>
              </div>
            </>
          )}
        </div>
        <input
          ref={fileInputRef}
          type="file"
          accept={accept}
          className="hidden"
          onChange={handleInputChange}
          disabled={disabled}
        />
      </Card>

      {/* Validasyon Hataları */}
      {validationErrors && validationErrors.length > 0 && (
        <Card className="p-4 border-red-200 bg-red-50">
          <div className="flex gap-2 mb-2">
            <AlertCircle className="h-4 w-4 text-red-600 flex-shrink-0 mt-0.5" />
            <p className="font-medium text-red-900">Validasyon Hataları</p>
          </div>
          <ul className="space-y-1 ml-6">
            {validationErrors.map((error, idx) => (
              <li key={idx} className="text-sm text-red-700">
                • Satır {error.row}, Kolon {error.column}: {error.error}
              </li>
            ))}
          </ul>
        </Card>
      )}
    </div>
  );
}
```

#### 4.2.4 PoC Listesi İçin Badge

```typescript
// components/poc/poc-badge.tsx

import React from 'react';
import { Badge } from '@/components/ui/badge';

interface PoCBadgeProps {
  type: 'PRE_POC' | 'FULL_POC';
  className?: string;
}

export function PoCBadge({ type, className }: PoCBadgeProps) {
  const config = {
    PRE_POC: {
      label: '🟡 Ön PoC',
      color: 'bg-yellow-100 text-yellow-800 border-yellow-300',
    },
    FULL_POC: {
      label: '🔵 Kapsamlı PoC',
      color: 'bg-blue-100 text-blue-800 border-blue-300',
    },
  };

  const { label, color } = config[type];

  return (
    <Badge variant="outline" className={`${color} ${className}`}>
      {label}
    </Badge>
  );
}
```

---

## 5. Excel Sistem

### 5.1 Excel Şablonu Yapısı

**Sayfalar:**
1. **Başlangıç** - Talimatlar ve genel bilgiler
2. **Şirket Profili** - Temek şirket bilgileri
3. **Mevcut Durum** - Existing systems ve pain points
4. **Hedefler & Kapsam** - Amaçlar ve sınırlandırmalar
5. **Zaman Çizelgesi** - Planlanan tarihler
6. **Teknik Gereksinimler** (İsteğe Bağlı) - Teknik detaylar

### 5.2 Excel Validasyon Şeması

```typescript
// services/excel-validation.service.ts

interface ExcelValidationSchema {
  sheets: {
    [sheetName: string]: {
      requiredColumns: string[];
      optionalColumns?: string[];
      rowStartIndex: number;
      maxRows?: number;
      rules: ValidationRule[];
    };
  };
}

interface ValidationRule {
  column: string;
  type: 'string' | 'number' | 'date' | 'email' | 'url' | 'enum';
  required: boolean;
  minLength?: number;
  maxLength?: number;
  pattern?: string;
  allowedValues?: any[];
  customValidator?: (value: any) => boolean;
}

// Örnek schema
const PRE_POC_EXCEL_SCHEMA: ExcelValidationSchema = {
  sheets: {
    'Şirket Profili': {
      requiredColumns: [
        'Şirket Adı',
        'Endüstri',
        'Kuruluş Yılı',
        'Çalışan Sayısı',
      ],
      optionalColumns: ['Web Sitesi', 'Açıklama'],
      rowStartIndex: 1,
      maxRows: 1,
      rules: [
        {
          column: 'Şirket Adı',
          type: 'string',
          required: true,
          minLength: 2,
          maxLength: 255,
        },
        {
          column: 'Kuruluş Yılı',
          type: 'number',
          required: false,
          customValidator: (val) => !val || (val >= 1900 && val <= new Date().getFullYear()),
        },
      ],
    },
  },
};
```

### 5.3 Excel Parse İşlemi

```typescript
// services/excel-parser.service.ts

export class ExcelParserService {
  async parsePrePoCExcel(filePath: string): Promise<PrePoCData> {
    const workbook = XLSX.readFile(filePath);
    
    const result: PrePoCData = {
      companyProfile: this.parseSheet(workbook, 'Şirket Profili'),
      currentSituation: this.parseSheet(workbook, 'Mevcut Durum'),
      objectives: this.parseSheet(workbook, 'Hedefler & Kapsam', true),
      timeline: this.parseSheet(workbook, 'Zaman Çizelgesi'),
    };

    return result;
  }

  private parseSheet(workbook: XLSX.WorkBook, sheetName: string, isArray = false): any {
    const sheet = workbook.Sheets[sheetName];
    if (!sheet) throw new Error(`Sheet ${sheetName} not found`);

    const data = XLSX.utils.sheet_to_json(sheet);
    return isArray ? data : data[0];
  }
}
```

---

## 6. Validasyon Kuralları

### 6.1 PoC Türü Validasyonları

| Kural | Ön PoC | Kapsamlı PoC |
|-------|--------|-------------|
| Excel dosyası zorunlu mu? | ✅ Evet | ❌ Hayır |
| Form alanları zorunlu mu? | ❌ Opsiyonel | ✅ Evet (title, objectives) |
| Teknik gereksinimler zorunlu mu? | ❌ Hayır | 🔶 Opsiyonel |
| Bütçe girilmeli mi? | ❌ Hayır | 🔶 Opsiyonel |

### 6.2 Excel Dosyası Validasyonları

```typescript
// Dosya seviyesi validasyonlar
const FILE_VALIDATIONS = {
  FORMAT: {
    rule: 'File must be .xlsx format',
    check: (file: File) => file.name.endsWith('.xlsx'),
  },
  SIZE: {
    rule: 'File size must not exceed 10MB',
    check: (file: File) => file.size <= 10 * 1024 * 1024,
  },
  STRUCTURE: {
    rule: 'All required sheets must exist',
    check: async (workbook: XLSX.WorkBook) => {
      const requiredSheets = [
        'Şirket Profili',
        'Mevcut Durum',
        'Hedefler & Kapsam',
        'Zaman Çizelgesi',
      ];
      return requiredSheets.every(sheet => workbook.SheetNames.includes(sheet));
    },
  },
};

// Veri seviyesi validasyonlar
const DATA_VALIDATIONS = {
  NO_EMPTY_REQUIRED_FIELDS: {
    rule: 'Required fields cannot be empty',
    check: (data: any, schema: ValidationRule[]) => {
      return schema
        .filter(r => r.required)
        .every(r => data[r.column] !== null && data[r.column] !== undefined && data[r.column] !== '');
    },
  },
  DATA_TYPE_MATCH: {
    rule: 'Data types must match schema',
    check: (value: any, rule: ValidationRule) => {
      const typeChecks: Record<string, (v: any) => boolean> = {
        string: v => typeof v === 'string',
        number: v => !isNaN(Number(v)),
        date: v => !isNaN(Date.parse(v)),
        email: v => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v),
        url: v => /^https?:\/\//.test(v),
        enum: v => rule.allowedValues?.includes(v),
      };
      return typeChecks[rule.type]?.(value) ?? true;
    },
  },
};
```

### 6.3 State Transition Validasyonları

```typescript
// Müsaade edilen state geçişleri

const PRE_POC_TRANSITIONS = {
  DRAFT: ['EXCEL_UPLOADED', 'CANCELLED'],
  EXCEL_UPLOADED: ['DRAFT', 'UNDER_REVIEW', 'CANCELLED'],
  UNDER_REVIEW: ['APPROVED', 'REJECTED', 'EXCEL_UPLOADED'],
  APPROVED: ['IN_PROGRESS'],
  REJECTED: ['DRAFT', 'CANCELLED'],
  CANCELLED: [], // Terminal state
};

const FULL_POC_TRANSITIONS = {
  REQUESTED: ['IN_PROGRESS', 'CANCELLED'],
  IN_PROGRESS: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
};
```

---

## 7. Lifecycle Akışları

### 7.1 Ön PoC Lifecycle

```
                              START
                                ↓
                        ┌──────────────┐
                        │ DRAFT        │ ← Manual Creation
                        └──────┬───────┘
                               ↓
                    User İndirme Template
                               ↓
                    User Doldurma Excel
                               ↓
                    User Upload Excel
                               ↓
                        ┌──────────────┐
    Validasyon Başarısız→│ EXCEL_UPLOADED│ ← Validasyon Başarılı
                   │      └──────┬───────┘
                   │             ↓
                   │      Firma İnceleme
                   │             ↓
                   │      ┌──────────────┐
                   ├─────→│ UNDER_REVIEW │
                   │      └──────┬───────┘
                   │             ↓
                   │      ┌─────────────────┐
                   │    /─│ APPROVED        │
                   │   /  └─────────────────┘
                   │  /
        Validasyon Hata / Reddet
                   │  \
                   │   \─ REJECTED
                   │      └─────────────────┘
                   │
           CANCELLED (any time)
```

**Statü Açıklamaları:**
- **DRAFT**: Başlangıç durumu, Excel yüklenmesi bekleniyor
- **EXCEL_UPLOADED**: Excel başarıyla yüklendi, inceleme bekleniyor
- **UNDER_REVIEW**: Firma veya sistem tarafından inceleniyor
- **APPROVED**: PoC onaylandı, ön değerlendirme tamamlandı
- **REJECTED**: Ön PoC reddedildi, düzeltme için DRAFT'a dönebilir
- **CANCELLED**: İptal edildi (terminal state)

### 7.2 Kapsamlı PoC Lifecycle

```
                              START
                                ↓
                        ┌──────────────┐
                        │ REQUESTED    │ ← Form Submit
                        └──────┬───────┘
                               ↓
                      Firma İnceleme
                               ↓
                        ┌──────────────┐
                        │ IN_PROGRESS  │
                        └──────┬───────┘
                               ↓
                      Metrikler Takip
                      Evaluasyon
                               ↓
                        ┌──────────────┐
                        │ COMPLETED    │
                        └──────────────┘

        CANCELLED (any time)
                   ↓
          ┌──────────────┐
          │ CANCELLED    │
          └──────────────┘
```

---

## 8. Edge Cases

### 8.1 Ön PoC Edge Cases

| Senaryo | Çözüm |
|---------|-------|
| Kullanıcı Excel yükler, validasyon başarısız | Hatalar göster, dosya tekrar yüklemeye izin ver |
| Kullanıcı DRAFT'ta PoC'yi siler | Soft delete, recovery window 30 gün |
| Excel yüklenirken network kesintisi | Automatic retry 3 kez, timeout sonra hata |
| Kullanıcı aynı dosyayı 2 kez yükler | Version tracking, latest'i default olarak göster |
| Şirket PoC'yi onay beklemede reddeder | Status REJECTED, DRAFT'a dönüş fırsatı |

### 8.2 Kapsamlı PoC Edge Cases

| Senaryo | Çözüm |
|---------|-------|
| Kullanıcı in-progress PoC'yi sil ister | Soft delete, admin approval gerekebilir |
| Metrikler eksik girilirse | Optional fields için warning, required fields için block |
| Hedef şirket firma değilse (user) | Hata mesajı, firma seçmeye zorla |
| Ürün artık aktif değilse | Warning göster, devam etmeye izin ver |

### 8.3 Dosya İşleme Edge Cases

| Senaryo | Çözüm |
|---------|-------|
| Excel dosyası boş şeet içerirse | Hata: "X sayfası boş" |
| Tarih formatı yanlışsa (DD.MM.YYYY vs MM/DD/YYYY) | Auto-detect veya explicit format gerekli |
| Excel şifreliyse | Hata: "Dosya şifreli, çöz ve tekrar yükle" |
| Dosya birden çok kez yüklenirse | Versioning: v1, v2, v3... |

---

## 9. Implementasyon Sırası

### Phase 1: Core (Hafta 1-2)
- [ ] PoC entity güncelleme (pocType, status fields)
- [ ] Database migration
- [ ] API endpoints: create, list, details
- [ ] Type definitions (PoCType, Status enums)

### Phase 2: Excel System (Hafta 2-3)
- [ ] Excel template oluştur (.xlsx dosya)
- [ ] Upload endpoint (`/upload-excel`)
- [ ] Validasyon service
- [ ] Excel parser service
- [ ] Download template endpoint

### Phase 3: Frontend - Type Selector (Hafta 3)
- [ ] PoCTypeSelector component
- [ ] Styling ve UX
- [ ] Integration with dashboard

### Phase 4: Frontend - Forms (Hafta 4)
- [ ] PrePoCForm component
- [ ] FullPoCForm component
- [ ] ExcelUploadZone component
- [ ] Form validation

### Phase 5: Integration & Polish (Hafta 5)
- [ ] Dashboard integration
- [ ] Status badges
- [ ] List filtering by type
- [ ] Error handling refinement
- [ ] Testing & QA

---

## 10. Kodu Yapı Özeti

### Backend Klasör Yapısı

```
openpoc-backend/src/
├── poc/
│   ├── entities/
│   │   ├── poc.entity.ts
│   │   └── poc-pre-poc-data.entity.ts
│   ├── dtos/
│   │   ├── create-poc.dto.ts
│   │   ├── upload-excel.dto.ts
│   │   └── list-poc.query.ts
│   ├── services/
│   │   ├── poc.service.ts
│   │   ├── excel-parser.service.ts
│   │   ├── excel-validator.service.ts
│   │   └── excel-template.service.ts
│   ├── controllers/
│   │   └── poc.controller.ts
│   ├── guards/
│   │   └── poc-state-transition.guard.ts
│   └── poc.module.ts
├── shared/
│   ├── enums/
│   │   └── poc-types.enum.ts
│   └── constants/
│       └── poc-validation.const.ts
```

### Frontend Klasör Yapısı

```
openpoc-frontend/components/
├── poc/
│   ├── poc-type-selector.tsx
│   ├── poc-badge.tsx
│   ├── forms/
│   │   ├── pre-poc-form.tsx
│   │   └── full-poc-form.tsx
│   ├── excel-upload-zone.tsx
│   └── excel-preview.tsx
├── dashboard/
│   └── poc-section.tsx
└── hooks/
    └── use-poc-management.ts
```

---

## 11. Güvenlik Düşünceleri

- ✅ File upload tipini doğrula (.xlsx)
- ✅ File size limit uygula (10MB)
- ✅ Virus scan (optional - AWS Antivirus vs)
- ✅ Excel file'ı parse etmeden önce sandbox'ta test et
- ✅ User-uploaded dosyaları private storage'da tut
- ✅ Dosya erişimi için authentication check
- ✅ SQL injection / formula injection'a karşı korunma

---

## 12. Performance Optimizations

- 📊 Lazy load form components
- 🚀 Excel parsing worker thread'de (file size > 5MB)
- 💾 File upload progress tracking
- 🔄 Partial validation (row by row)
- 📱 Pagination for large PoC lists
- 🗂️ Database indexing on pocType, status, createdAt

---

## 13. Testing Strategy

### Unit Tests
- [ ] Excel validation rules
- [ ] State transition logic
- [ ] Enum validations

### Integration Tests
- [ ] Full workflow: Create → Upload → Parse
- [ ] Error scenarios
- [ ] Database operations

### E2E Tests
- [ ] User creates Pre-PoC
- [ ] User creates Full-PoC
- [ ] Excel upload and validation
- [ ] Status transitions

---

**Dokuman Sonu**

Bu tasarım belgesini temel alarak implementasyona başlayabilirsiniz.
Sorular için referans alanları kontrol edin.
