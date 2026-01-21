# 🔴 BACKEND CREATECOMPANY - ROOT CAUSE ANALYSIS

**Tarih:** 21 Ocak 2026  
**Sistem:** Next.js 16 + NestJS  
**Issue:** 500 Internal Server Error + Empty Response

---

## ❌ HATA 1: 500 Internal Server Error

### 🔍 Root Cause Analysis

#### Sorun 1: DTO Field Mismatch
```typescript
// Frontend gönderdiği:
{
  name: "Şirket Adı",        ✅ Eşleşir
  type: "STARTUP",            ✅ Eşleşir
  industry: "Teknoloji",       ✅ Eşleşir → (dto.industry)
  description: "...",          ✅ Eşleşir
  logo: "...",                 ✅ Eşleşir
  website: "...",              ✅ Eşleşir
  size: "10-50",               ✅ Eşleşir
}

// Backend DTO beklentisi (company.dto.ts):
export class CreateCompanyDto {
  @IsString() @IsNotEmpty()
  name: string;                // ✅ Field var
  
  @IsEnum(CompanyType) @IsOptional()
  type?: CompanyType;          // ✅ Optional, aynı enum
  
  // ... diğer alanlar
}
```

**Result:** ✅ DTO tamamen eşleşiyor, sorun değil

---

#### Sorun 2: Request Body Validation Hatası (CLASS-VALIDATOR)
```typescript
// Backend'de şu middleware çalışıyor:
// @UseGlobalPipes(new ValidationPipe())

// Eğer body validation başarısız olursa:
// 400 Bad Request gelmeli (500 değil!)
```

**Result:** ✅ Validation'ın 400 döndürmesi gerekir

---

#### Sorun 3: Transaction İçinde Null/Missing Field
```typescript
// companies.service.ts satır 60-72:
const company = await tx.company.create({
  data: {
    name: dto.name,
    logo: dto.logo,                    // null olabilir (optional)
    description: dto.description,      // null olabilir (optional)
    website: dto.website,              // null olabilir (optional)
    industry: dto.industry,            // null olabilir (optional)
    size: dto.size,                    // null olabilir (optional)
    createdByUserId: userId,           // 🚨 Bu null olabilir!
    enterpriseId: dto.enterpriseId,    // null olabilir (optional)
    startupId: dto.startupId,          // null olabilir (optional)
  },
});
```

**Problem:** 
- Eğer `userId` null veya undefined ise → DB constraint error
- Eğer `createdByUserId` NOT NULL constraint varsa → 500 error

---

#### Sorun 4: CompanyMember Creation Hatası
```typescript
// satır 95-100
await tx.companyMember.create({
  data: {
    userId,                    // 🚨 Null olabilir
    companyId: company.id,     // ✅ Company az önce create oldu
    role: CompanyMemberRole.OWNER,
  },
});
```

**Problem:** userId null ise FK constraint violated → 500

---

#### Sorun 5: JwtAuthGuard'dan userId Değeri Gelmediği
```typescript
// @UseGuards(JwtAuthGuard)
// async createCompany(@Body() dto, @Request() req) {
//   req.user.sub  // 🚨 Bu undefined olabilir!
// }
```

**Problem:** JWT payload'unda `sub` claim yoksa → userId = undefined

---

### ✅ ÇÖZÜM 1: Backend Error Handling Güçlendirme

```typescript
// companies.service.ts - createCompany methodu

async createCompany(dto: CreateCompanyDto, userId: string) {
  this.logger.log(`Creating company for user: ${userId}`);
  
  // 🔍 STEP 1: Validation
  if (!userId) {
    this.logger.error('❌ userId is missing from JWT');
    throw new BadRequestException('User not authenticated');
  }
  
  if (!dto.name || dto.name.trim().length === 0) {
    this.logger.warn('❌ Company name is empty');
    throw new BadRequestException('Company name is required');
  }

  try {
    return await this.prisma.$transaction(async (tx) => {
      // 🔍 STEP 2: Check if user exists
      const user = await tx.user.findUnique({
        where: { id: userId },
        select: { id: true, email: true },
      });
      
      if (!user) {
        this.logger.error(`❌ User not found: ${userId}`);
        throw new NotFoundException('User not found');
      }

      this.logger.debug(`✅ User found: ${user.email}`);

      // 🔍 STEP 3: Check duplicate company name
      const existingCompany = await tx.company.findFirst({
        where: { name: dto.name },
        select: { id: true },
      });

      if (existingCompany) {
        this.logger.warn(`❌ Company name already exists: ${dto.name}`);
        throw new ConflictException('Company name already exists');
      }

      // 🔍 STEP 4: Create company
      const company = await tx.company.create({
        data: {
          name: dto.name.trim(),
          logo: dto.logo || null,
          description: dto.description || null,
          website: dto.website || null,
          industry: dto.industry || null,
          size: dto.size || null,
          type: dto.type || 'STARTUP',
          createdByUserId: userId,  // 🔒 Safe - checked earlier
          enterpriseId: dto.enterpriseId || null,
          startupId: dto.startupId || null,
        },
        include: {
          members: {
            include: {
              user: {
                select: {
                  id: true,
                  firstName: true,
                  lastName: true,
                  email: true,
                },
              },
            },
          },
        },
      });

      this.logger.debug(`✅ Company created: ${company.id}`);

      // 🔍 STEP 5: Add creator as OWNER
      const membership = await tx.companyMember.create({
        data: {
          userId,  // 🔒 Safe - checked earlier
          companyId: company.id,
          role: CompanyMemberRole.OWNER,
        },
      });

      this.logger.debug(`✅ Creator added as OWNER: ${membership.id}`);

      return {
        ...company,
        members: [...(company.members || []), 
          { 
            userId,
            role: CompanyMemberRole.OWNER,
            user: user,
          }
        ],
      };
      
    }, {
      // Transaction isolation level
      isolationLevel: 'Serializable',
    });

  } catch (error) {
    // 🔍 STEP 6: Specific error handling
    if (error instanceof ConflictException || 
        error instanceof BadRequestException || 
        error instanceof NotFoundException) {
      throw error;  // Re-throw known errors
    }

    // DB errors
    if (error.code === 'P2014') {
      this.logger.error('❌ FK Constraint failed - invalid userId or companyId');
      throw new BadRequestException('Invalid user or company reference');
    }

    if (error.code === 'P2002') {
      this.logger.error('❌ Unique constraint failed');
      throw new ConflictException('Duplicate entry');
    }

    // Unknown error
    this.logger.error(`❌ Unexpected error creating company: ${error.message}`, error);
    throw new Error('Failed to create company');
  }
}
```

---

## ❌ HATA 2: Empty Response Body ({})

### 🔍 Neden Boş Response?

```typescript
// Frontend receives:
if (!response.ok) {
  const errorText = await response.text();  // "" (boş string!)
  // Parse hatası olabilir
}
```

**Sebepleri:**
1. Backend exception sonrası body dönmüyor
2. NestJS GlobalExceptionFilter body boş bırakıyor
3. Response stream'i iki kez oku (first readableStream consumed)

### ✅ ÇÖZÜM 2: Exception Filter Kodu

```typescript
// common/http-exception.filter.ts
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let code = 'INTERNAL_SERVER_ERROR';

    // Log detayları
    this.logger.error(`❌ Exception on ${request.method} ${request.url}`, {
      exception: exception instanceof Error ? exception.message : String(exception),
      stack: exception instanceof Error ? exception.stack : undefined,
    });

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const errorResponse = exception.getResponse();
      
      if (typeof errorResponse === 'object') {
        message = errorResponse['message'] || message;
        code = errorResponse['code'] || code;
      } else {
        message = errorResponse as string;
      }
    }

    // 🔑 ALWAYS return structured response
    response.status(status).json({
      statusCode: status,
      code: code,
      message: message,
      timestamp: new Date().toISOString(),
      path: request.url,
    });
  }
}

// main.ts
app.useGlobalFilters(new HttpExceptionFilter());
```

---

## ❌ HATA 3: Frontend Error Parsing Zayıf

### ✅ ÇÖZÜM 3: Güçlü Frontend Error Handler

```typescript
// components/platform-context.tsx

const createCompany = async (data: CreateCompanyDto): Promise<CreateCompanyResponse> => {
  const token = getToken();
  if (!token) throw new Error('No auth token');

  try {
    console.log('🏢 Creating company:', data);
    
    const endpoint = `${API_BASE_URL}/api${API_ENDPOINTS.company.create}`;
    console.log('📍 Using endpoint:', endpoint);
    
    const response = await fetch(endpoint, {
      method: 'POST',
      mode: 'cors',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({
        name: data.companyName,
        type: data.type || 'STARTUP',
        industry: data.sector,
        description: data.description,
        logo: data.companyLogo,
        website: data.website,
        size: data.employees ? String(data.employees) : undefined,
      }),
    });

    // 🔍 STEP 1: Parse response safely
    let errorData: any = {};
    
    try {
      const contentType = response.headers.get('content-type');
      
      if (contentType?.includes('application/json')) {
        errorData = await response.json();
      } else {
        const text = await response.text();
        errorData = {
          message: text || 'Unknown error',
          code: 'PARSE_ERROR',
        };
      }
    } catch (parseError) {
      console.error('❌ Failed to parse response:', parseError);
      errorData = {
        message: 'Failed to parse server response',
        code: 'PARSE_ERROR',
      };
    }

    // 🔍 STEP 2: Handle different status codes
    if (!response.ok) {
      const errorMessage = errorData.message || `HTTP ${response.status}`;
      const errorCode = errorData.code || 'UNKNOWN_ERROR';

      console.error('❌ Backend creation failed:', {
        status: response.status,
        statusText: response.statusText,
        error: errorData,
      });

      // Status-specific error handling
      switch (response.status) {
        case 400:
          // Validation error
          throw new Error(
            `Validation Error: ${errorMessage}`,
            { cause: { code: 'VALIDATION_ERROR', details: errorData } }
          );

        case 401:
          // Token expired
          localStorage.removeItem('accessToken');
          window.location.href = '/auth/login';
          throw new Error('Session expired');

        case 403:
          // Permission denied
          throw new Error(
            `Permission denied: ${errorMessage}`,
            { cause: { code: 'FORBIDDEN' } }
          );

        case 409:
          // Conflict (duplicate name)
          throw new Error(
            `Conflict: ${errorMessage}`,
            { cause: { code: 'CONFLICT' } }
          );

        case 500:
          // Server error - specific message
          throw new Error(
            `Server error: ${errorMessage}. Please try again later.`,
            { cause: { code: 'SERVER_ERROR', details: errorData } }
          );

        default:
          throw new Error(
            `Request failed: ${errorMessage}`,
            { cause: { code: errorCode, status: response.status } }
          );
      }
    }

    // 🔍 STEP 3: Parse success response
    let result: any = {};
    try {
      const contentType = response.headers.get('content-type');
      
      if (contentType?.includes('application/json')) {
        result = await response.json();
      } else {
        const text = await response.text();
        result = { id: Date.now(), name: data.companyName };
        console.warn('⚠️ Non-JSON response received');
      }
    } catch (parseError) {
      console.error('❌ Failed to parse success response:', parseError);
      result = { id: Date.now(), name: data.companyName };
    }

    console.log('✅ Backend creation successful:', result);
    
    // 🔍 STEP 4: Refresh companies
    await fetchCompanies();
    
    return {
      company: {
        id: result.id || Date.now(),
        name: result.name || data.companyName,
        type: result.type || data.type,
      },
      message: 'Şirket başarıyla oluşturuldu!',
    };

  } catch (error) {
    // Final error handling
    const errorMsg = error instanceof Error ? error.message : 'Bilinmeyen hata';
    const errorCode = (error as any)?.cause?.code || 'UNKNOWN';

    console.error('🔴 Company creation failed:', {
      message: errorMsg,
      code: errorCode,
      originalError: error,
    });

    throw new Error(errorMsg);
  }
};
```

---

## 📋 Backend DTO - Type Safety Kontrolü

```typescript
// companies/dto/company.dto.ts

import { IsString, IsNotEmpty, IsEnum, IsOptional, MaxLength, MinLength, IsUrl } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CompanyType } from '@prisma/client';

export class CreateCompanyDto {
  @ApiProperty({ 
    example: 'Paylisher Technologies',
    minLength: 2,
    maxLength: 255,
  })
  @IsString()
  @IsNotEmpty()
  @MinLength(2)
  @MaxLength(255)
  name: string;

  @ApiPropertyOptional({ 
    enum: CompanyType,
    default: 'STARTUP'
  })
  @IsEnum(CompanyType)
  @IsOptional()
  type?: CompanyType;

  @ApiPropertyOptional({ 
    example: 'https://example.com/logo.png',
    maxLength: 1024,
  })
  @IsOptional()
  @IsString()
  @IsUrl()
  @MaxLength(1024)
  logo?: string;

  @ApiPropertyOptional({ 
    example: 'Company description',
    maxLength: 5000,
  })
  @IsOptional()
  @IsString()
  @MaxLength(5000)
  description?: string;

  @ApiPropertyOptional({ 
    example: 'https://example.com',
    maxLength: 512,
  })
  @IsOptional()
  @IsString()
  @IsUrl()
  @MaxLength(512)
  website?: string;

  @ApiPropertyOptional({ 
    example: 'Technology',
    maxLength: 100,
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  industry?: string;

  @ApiPropertyOptional({ 
    example: '10-50',
    enum: ['1-10', '10-50', '50-100', '100-500', '500+'],
  })
  @IsOptional()
  @IsString()
  size?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  enterpriseId?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  startupId?: string;
}
```

---

## 🎯 Debug Checklist

- [ ] JWT payload'da `sub` claim var mı?
- [ ] userId null/undefined değil mi?
- [ ] Company name empty string değil mi?
- [ ] Prisma schema'da NOT NULL constraints doğru mu?
- [ ] GlobalExceptionFilter set edilmiş mi?
- [ ] ValidationPipe aktif mi?
- [ ] Backend logs'ta error mesajı var mı?
- [ ] Frontend response.text() sonucu boş mu?

---

## 🧪 Test Cases

```bash
# Backend Test: Valid Request
curl -X POST http://localhost:3001/api/companies \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Company",
    "type": "STARTUP",
    "industry": "Technology"
  }'

# Expected: 201 Created
# Response: { "id": "...", "name": "Test Company", ... }

# Backend Test: Duplicate Name
# Expected: 409 Conflict
# Response: { "statusCode": 409, "code": "CONFLICT", "message": "Company name already exists" }

# Backend Test: Missing Token
# Expected: 401 Unauthorized
```

