# Gerenciamento Dinâmico de Produtos - Guia de Uso

## 📋 Overview

O sistema foi atualizado para suportar gerenciamento dinâmico de produtos através do contexto global de plataforma. Agora você pode criar, atualizar e deletar produtos em tempo real.

## 🔧 Componentes Principais

### 1. **PlatformContext** (`contexts/platform-context.tsx`)
Contexto global que gerencia:
- ✅ Empresas
- ✅ Produtos (NOVO)
- ✅ Estados de loading e erro

#### Novas Funcionalidades:
```typescript
// Interface atualizada
interface PlatformContextType {
  companies: Company[];
  products: Product[];  // NOVO
  isLoading: boolean;
  error: PlatformError | null;
  
  // Funções existentes
  createCompany: (data: CreateCompanyPayload) => Promise<Company>;
  deleteCompany: (id: string) => Promise<void>;
  
  // NOVAS funções de produto
  createProduct: (data: CreateProductPayload) => Promise<Product>;
  updateProduct: (id: string, data: Partial<CreateProductPayload>) => Promise<Product>;
  deleteProduct: (id: string) => Promise<void>;
  refreshProducts: () => Promise<void>;
}
```

### 2. **useProducts Hook** (`hooks/useProducts.ts`)
Hook customizado que simplifica o uso de produtos:

```typescript
interface UseProductsReturn {
  products: Product[];
  isLoading: boolean;
  error: string | null;
  addProduct: (data: ProductData) => Promise<Product>;
  updateProduct: (id: string, data: any) => Promise<Product>;
  removeProduct: (id: string) => Promise<void>;
  clearError: () => void;
  refreshProducts: () => Promise<void>;
}
```

### 3. **AddProductDialog** (`components/product/add-product-dialog.tsx`)
Componente UI pronto para adicionar produtos:
- Form com validação
- Tratamento de erros
- Loading state
- Dialog modal

## 🚀 Como Usar

### Opção 1: Usando o Hook (Recomendado)

```typescript
import { useProducts } from "@/hooks/useProducts";

export function MyComponent() {
  const { 
    products, 
    isLoading, 
    error,
    addProduct,
    updateProduct,
    removeProduct 
  } = useProducts();

  // Adicionar um novo produto
  const handleAdd = async () => {
    try {
      const newProduct = await addProduct({
        name: "My Product",
        description: "Product description",
        category: "AI",
        tags: ["tag1", "tag2"],
        website: "https://example.com"
      });
      console.log("✅ Produto adicionado:", newProduct.id);
    } catch (error) {
      console.error("❌ Erro:", error);
    }
  };

  // Atualizar produto
  const handleUpdate = async (productId: string) => {
    try {
      const updated = await updateProduct(productId, {
        name: "Updated Name",
        status: "ACTIVE"
      });
      console.log("✅ Produto atualizado");
    } catch (error) {
      console.error("❌ Erro:", error);
    }
  };

  // Deletar produto
  const handleDelete = async (productId: string) => {
    try {
      await removeProduct(productId);
      console.log("✅ Produto deletado");
    } catch (error) {
      console.error("❌ Erro:", error);
    }
  };

  return (
    <div>
      {products.map(product => (
        <div key={product.id}>
          {product.name}
        </div>
      ))}
    </div>
  );
}
```

### Opção 2: Usando o Componente AddProductDialog

```typescript
import { AddProductDialog } from "@/components/product/add-product-dialog";

export function MyPage() {
  return (
    <div>
      <h1>My Products</h1>
      <AddProductDialog 
        onSuccess={() => {
          // Callback quando produto for criado com sucesso
          console.log("Product added!");
        }}
      />
    </div>
  );
}
```

### Opção 3: Usando o Contexto Diretamente

```typescript
import { usePlatform } from "@/contexts/platform-context";

export function AdvancedComponent() {
  const { 
    products,
    createProduct,
    updateProduct,
    deleteProduct,
    refreshProducts
  } = usePlatform();

  const handleCreateProduct = async () => {
    try {
      const product = await createProduct({
        name: "AI Platform",
        description: "Advanced AI Platform",
        visibility: "PRIVATE",
        status: "DRAFT"
      });
      console.log("✅ Criado:", product);
    } catch (error) {
      console.error("❌ Erro:", error);
    }
  };

  return (
    <div>
      <button onClick={handleCreateProduct}>Add Product</button>
      <ul>
        {products.map(p => <li key={p.id}>{p.name}</li>)}
      </ul>
    </div>
  );
}
```

## 📝 Estrutura de Dados

### CreateProductPayload
```typescript
interface CreateProductPayload {
  name: string;                          // Obrigatório
  description?: string;
  category?: string;
  tags?: string[];
  visibility?: 'PRIVATE' | 'PUBLIC' | 'MATCHED';
  status?: 'DRAFT' | 'ACTIVE' | 'INACTIVE' | 'ARCHIVED';
  logo?: string;
  website?: string;
  version?: string;
}
```

### Product (Response)
```typescript
interface Product {
  id: string;
  name: string;
  description?: string;
  logo?: string;
  visibility: ProductVisibility;
  status: ProductStatus;
  ownerId: string;
  owner: {
    id: string;
    name: string;
    logo?: string;
    type: 'ENTERPRISE' | 'STARTUP';
  };
  category?: string;
  tags?: string[];
  version?: string;
  website?: string;
  createdAt: string;
  updatedAt: string;
  isFollowing?: boolean;
  followRequestStatus?: 'PENDING' | 'APPROVED' | 'REJECTED';
  canRequestAccess?: boolean;
  pocCount?: number;
}
```

## 🐛 Correções Realizadas

### 1. Erro "me" (404 Not Found)
**Problema**: O endpoint `/api/startup-profiles/me` retornava 404 quando o usuário não tinha perfil.

**Solução**:
- ✅ Backend: Adicionado `@HttpCode(HttpStatus.OK)` ao endpoint
- ✅ Frontend: Adicionado tratamento de 404 no `api-client.ts`
- ✅ Usuários novos recebem perfil vazio em vez de erro

**Arquivo**: `openpoc-backend/src/startup/startup-profiles.controller.ts`

```typescript
@Get('me')
@HttpCode(HttpStatus.OK)  // ← Adicionado
@ApiResponse({ status: 200, description: '...' })
async getMyProfile(@Request() req: any) {
  // ... returns 200 com success: false se não encontrado
}
```

**Arquivo**: `openpoc-frontend/v0-open-po-c-dashboard-design-2/lib/api-client.ts`

```typescript
if (status === 404 || status === 401 || status === 403) {
  // ✅ Agora trata 404 como resultado esperado
  console.log(`ℹ️ Profile returned ${status} - expected for new users`);
  return { /* empty profile */ };
}
```

## 📁 Arquivos Alterados/Criados

### Alterados:
- ✏️ `contexts/platform-context.tsx` - Adicionado gerenciamento de produtos
- ✏️ `lib/api-client.ts` - Adicionado tratamento de 404

### Criados:
- ✨ `hooks/useProducts.ts` - Hook para gerenciar produtos
- ✨ `components/product/add-product-dialog.tsx` - Componente de diálogo
- ✨ `app/dashboard/products/page.tsx` - Página de exemplo

## 🔄 Fluxo de Dados

```
[Componente UI]
    ↓
[useProducts Hook]
    ↓
[usePlatform Context]
    ↓
[API Client]
    ↓
[Backend Endpoints]

Produtos são sincronizados automaticamente em:
- Criação (POST /api/products)
- Atualização (PUT /api/products/:id)
- Deleção (DELETE /api/products/:id)
```

## ⚙️ Endpoints Disponíveis

```
GET    /api/products              - Listar todos os produtos
POST   /api/products              - Criar novo produto
GET    /api/products/:id          - Obter detalhes do produto
PUT    /api/products/:id          - Atualizar produto
DELETE /api/products/:id          - Deletar produto
```

## 💡 Exemplo Completo

Veja a página de exemplo em: `app/dashboard/products/page.tsx`

```bash
npm run dev
# Abra http://localhost:3000/dashboard/products
```

## 🎯 Próximos Passos

1. ✅ Implementar página de produtos
2. ✅ Adicionar modal de criação
3. ⏳ Implementar edição de produtos
4. ⏳ Adicionar filtros e busca
5. ⏳ Integrar com sistema de POCs

---

**Última atualização**: 21 de Janeiro de 2026
**Status**: ✅ Em funcionamento
