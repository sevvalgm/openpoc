# 🎓 Next.js + React Best Practices

## API Error Handling Pattern

### Pattern 1: Universal Fetch Wrapper

```typescript
// lib/api-fetch.ts
type FetchResponse<T> = 
  | { ok: true; data: T }
  | { ok: false; error: string; status: number };

async function safeFetch<T>(
  url: string,
  options?: RequestInit
): Promise<FetchResponse<T>> {
  try {
    const res = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...options?.headers,
      },
      ...options,
    });

    // Map HTTP status to business logic
    if (res.ok) {
      return { ok: true, data: await res.json() };
    }

    // Handle specific error statuses
    switch (res.status) {
      case 401:
        // Token expired - refresh or redirect
        localStorage.removeItem('accessToken');
        window.location.href = '/auth/login';
        return { ok: false, error: 'Unauthorized', status: 401 };

      case 403:
        return { ok: false, error: 'Forbidden', status: 403 };

      case 404:
        // 404 could be expected (e.g., user profile not found)
        return { ok: false, error: 'Not found', status: 404 };

      case 429:
        return { ok: false, error: 'Rate limited', status: 429 };

      case 500:
        return { ok: false, error: 'Server error', status: 500 };

      default:
        const errorData = await res.json().catch(() => ({}));
        return {
          ok: false,
          error: errorData.message || `HTTP ${res.status}`,
          status: res.status,
        };
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    return { ok: false, error: message, status: 0 };
  }
}

// Kullanım:
const result = await safeFetch<User>('/api/users/me', {
  headers: { Authorization: `Bearer ${token}` },
});

if (result.ok) {
  console.log('User:', result.data);
} else {
  console.error('Error:', result.error);
}
```

---

## UI Component Import Best Practices

### Pattern 2: Verify Imports at Compile Time

```typescript
// ✅ DOĞRU - TypeScript strict mode ile catch edilir
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,  // ← TypeScript check eder
} from "@/components/ui/dialog";

// ❌ YANLIŞ - DialogTrigger kullanıldı ama import yok
import { Dialog, DialogContent } from "@/components/ui/dialog";
// → TypeScript error: 'DialogTrigger' not found
```

### Pattern 3: Component Registry Pattern

```typescript
// components/ui/index.ts - Central export
export { Button } from './button';
export { Dialog, DialogTrigger, DialogContent } from './dialog';
export { Input } from './input';
export { Card, CardContent, CardHeader } from './card';

// ✅ Single import point
import { Button, Dialog, DialogTrigger, Input } from '@/components/ui';

// ✅ TypeScript auto-complete works
// ✅ Easy to track missing components
```

---

## State Management: Async Loading

### Pattern 4: Proper Loading State Management

```typescript
// hooks/useAsyncData.ts
interface UseAsyncDataOptions<T> {
  fetcher: () => Promise<T>;
  onError?: (error: Error) => void;
}

function useAsyncData<T>(
  options: UseAsyncDataOptions<T>,
  dependencies: React.DependencyList
) {
  const [state, setState] = useState<{
    data: T | null;
    isLoading: boolean;
    error: Error | null;
  }>({
    data: null,
    isLoading: true,
    error: null,
  });

  useEffect(() => {
    let isMounted = true;

    (async () => {
      try {
        setState(s => ({ ...s, isLoading: true }));
        const data = await options.fetcher();
        
        if (isMounted) {
          setState({ data, isLoading: false, error: null });
        }
      } catch (error) {
        if (isMounted) {
          const err = error instanceof Error ? error : new Error(String(error));
          setState({ data: null, isLoading: false, error: err });
          options.onError?.(err);
        }
      }
    })();

    return () => {
      isMounted = false;
    };
  }, dependencies);

  return state;
}

// Kullanım:
const { data: user, isLoading, error } = useAsyncData(
  {
    fetcher: () => fetch('/api/users/me').then(r => r.json()),
    onError: (err) => console.error('Failed to load user:', err),
  },
  []
);

if (isLoading) return <Skeleton />;
if (error) return <Error message={error.message} />;
if (!user) return <LimitedAccessMode />;
return <UserProfile user={user} />;
```

---

## Dialog Management Pattern

### Pattern 5: Controlled Dialog with Type Safety

```typescript
// components/dialog/controlled-dialog.tsx
interface ControlledDialogProps<T> {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: string;
  content: React.ReactNode;
  onConfirm?: (data: T) => Promise<void>;
  isLoading?: boolean;
}

export function ControlledDialog<T>({
  open,
  onOpenChange,
  title,
  description,
  content,
  onConfirm,
  isLoading = false,
}: ControlledDialogProps<T>) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          {description && (
            <DialogDescription>{description}</DialogDescription>
          )}
        </DialogHeader>

        <div className="py-4">
          {content}
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={isLoading}
          >
            Cancel
          </Button>
          {onConfirm && (
            <Button
              onClick={() => onConfirm({} as T)}
              disabled={isLoading}
              isLoading={isLoading}
            >
              Confirm
            </Button>
          )}
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// Kullanım:
export function MyPage() {
  const [dialogOpen, setDialogOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleConfirm = async (data: CompanyData) => {
    setIsSubmitting(true);
    try {
      await createCompany(data);
      setDialogOpen(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <>
      <Button onClick={() => setDialogOpen(true)}>
        Open Dialog
      </Button>

      <ControlledDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        title="Create Company"
        content={<CompanyForm />}
        onConfirm={handleConfirm}
        isLoading={isSubmitting}
      />
    </>
  );
}
```

---

## Error Boundary Best Practice

### Pattern 6: Granular Error Boundaries

```typescript
// components/error-boundary.tsx
interface ErrorBoundaryProps {
  children: React.ReactNode;
  fallback?: (error: Error, retry: () => void) => React.ReactNode;
  onError?: (error: Error) => void;
}

export class ErrorBoundary extends React.Component<
  ErrorBoundaryProps,
  { hasError: boolean; error: Error | null }
> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error) {
    this.props.onError?.(error);
  }

  retry = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError && this.state.error) {
      return (
        this.props.fallback?.(this.state.error, this.retry) || (
          <div className="p-4 bg-destructive/10 text-destructive rounded-lg">
            <h2>Something went wrong</h2>
            <p>{this.state.error.message}</p>
            <Button onClick={this.retry}>Try again</Button>
          </div>
        )
      );
    }

    return this.props.children;
  }
}

// Kullanım:
<ErrorBoundary onError={(error) => console.error(error)}>
  <ProfilePage />
</ErrorBoundary>
```

---

## Profile + Companies Sync Pattern

### Pattern 7: Unified Context for Related Data

```typescript
// components/profile-context.tsx
interface ProfileContextType {
  user: User | null;
  userLoading: boolean;
  userError: Error | null;
  companies: Company[];
  companiesLoading: boolean;
  companiesError: Error | null;
  isReady: boolean; // Both user and companies loaded
}

export const ProfileContext = createContext<ProfileContextType>({
  user: null,
  userLoading: true,
  userError: null,
  companies: [],
  companiesLoading: true,
  companiesError: null,
  isReady: false,
});

export function ProfileProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [userLoading, setUserLoading] = useState(true);
  const [userError, setUserError] = useState<Error | null>(null);

  const { companies, isLoading: companiesLoading, error: companiesError } =
    usePlatform();

  // Both are ready when both finish loading (even if error)
  const isReady = !userLoading && !companiesLoading;

  useEffect(() => {
    loadUserProfile();
  }, []);

  const loadUserProfile = async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        setUser(null);
        setUserLoading(false);
        return;
      }

      const res = await fetch('/api/users/me', {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (res.ok) {
        setUser(await res.json());
      } else if (res.status !== 404) {
        throw new Error(`Failed to load user: ${res.status}`);
      }
    } catch (error) {
      setUserError(error instanceof Error ? error : new Error('Unknown error'));
    } finally {
      setUserLoading(false);
    }
  };

  return (
    <ProfileContext.Provider
      value={{
        user,
        userLoading,
        userError,
        companies,
        companiesLoading,
        companiesError,
        isReady,
      }}
    >
      {children}
    </ProfileContext.Provider>
  );
}

export function useProfile() {
  const context = useContext(ProfileContext);
  if (!context) {
    throw new Error('useProfile must be used within ProfileProvider');
  }
  return context;
}
```

---

## TypeScript Configuration Best Practice

### tsconfig.json - Production Ready

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "preserve",

    // ✅ STRICT MODE - Tüm kontroller açık
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitAny": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "noImplicitThis": true,
    "strictNullChecks": true,
    "strictPropertyInitialization": true,
    "strictFunctionTypes": true,

    // Module resolution
    "module": "ESNext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "allowSyntheticDefaultImports": true,
    "esModuleInterop": true,
    "isolatedModules": true,

    // Path aliases
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
```

---

## Testing Pattern

### Pattern 8: Error Scenario Testing

```typescript
// app/dashboard/__tests__/profile.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import ProfilePage from '../profile/page';

describe('ProfilePage', () => {
  it('should handle 404 gracefully (new user)', async () => {
    // Mock fetch to return 404
    global.fetch = jest.fn()
      .mockResolvedValueOnce({
        ok: false,
        status: 404,
        json: async () => ({ message: 'Not found' }),
      });

    render(<ProfilePage />);

    await waitFor(() => {
      // Should show Limited Access Mode, NOT an error
      expect(screen.getByText(/complete your profile/i)).toBeInTheDocument();
      expect(screen.queryByText(/error/i)).not.toBeInTheDocument();
    });
  });

  it('should redirect on 401', async () => {
    global.fetch = jest.fn()
      .mockResolvedValueOnce({
        ok: false,
        status: 401,
      });

    render(<ProfilePage />);

    await waitFor(() => {
      expect(window.location.href).toBe('/auth/login');
    });
  });

  it('should show error message on 5xx', async () => {
    global.fetch = jest.fn()
      .mockResolvedValueOnce({
        ok: false,
        status: 500,
        json: async () => ({ message: 'Internal server error' }),
      });

    render(<ProfilePage />);

    await waitFor(() => {
      expect(screen.getByText(/internal server error/i)).toBeInTheDocument();
    });
  });
});
```

---

## Summary Checklist

- ✅ Use `safeFetch` wrapper for consistent error handling
- ✅ Map HTTP status codes to business logic
- ✅ 404 ≠ Error (can be expected state)
- ✅ Verify all UI component imports at compile time
- ✅ Use TypeScript strict mode
- ✅ Unify loading states for related data
- ✅ Test error scenarios, not just happy path
- ✅ Use Error Boundaries for runtime error recovery
- ✅ Provide user-friendly error messages
- ✅ Never trust API responses without validation

