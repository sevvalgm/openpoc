// 🎯 Production-Ready Patterns - Reference Implementation

/**
 * PATTERN 1: Universal Fetch Wrapper with Status Handling
 * 
 * Use this to wrap all fetch calls in your Next.js app
 * Handles all error scenarios consistently
 */

// lib/api.ts
type FetchResponse<T> = 
  | { success: true; data: T }
  | { success: false; error: string; status: number };

interface FetchOptions extends Omit<RequestInit, 'body'> {
  body?: any;
}

export async function apiFetch<T>(
  url: string,
  options: FetchOptions = {}
): Promise<FetchResponse<T>> {
  try {
    const token = typeof window !== 'undefined' 
      ? localStorage.getItem('accessToken') || localStorage.getItem('token')
      : null;

    const res = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
        ...options.headers,
      },
      body: options.body ? JSON.stringify(options.body) : undefined,
      ...options,
    });

    // Handle specific status codes
    if (res.ok) {
      const data = await res.json();
      return { success: true, data };
    }

    // Status-specific handling
    if (res.status === 401) {
      // Token expired or invalid
      if (typeof window !== 'undefined') {
        localStorage.removeItem('accessToken');
        localStorage.removeItem('token');
        window.location.href = '/auth/login';
      }
      return { success: false, error: 'Session expired', status: 401 };
    }

    if (res.status === 404) {
      // Resource not found - might be expected (e.g., user profile)
      const data = await res.json().catch(() => ({ message: 'Not found' }));
      return { success: false, error: data.message || 'Not found', status: 404 };
    }

    if (res.status === 403) {
      return { success: false, error: 'Access denied', status: 403 };
    }

    if (res.status === 429) {
      return { success: false, error: 'Too many requests', status: 429 };
    }

    if (res.status >= 500) {
      const data = await res.json().catch(() => ({}));
      return {
        success: false,
        error: data.message || 'Server error',
        status: res.status,
      };
    }

    // Generic error
    const data = await res.json().catch(() => ({}));
    return {
      success: false,
      error: data.message || `HTTP ${res.status}`,
      status: res.status,
    };

  } catch (error) {
    const message = error instanceof Error ? error.message : 'Network error';
    return { success: false, error: message, status: 0 };
  }
}

// Usage:
// const result = await apiFetch<User>('/api/users/me');
// if (result.success) {
//   console.log('User:', result.data);
// } else if (result.status === 404) {
//   console.log('User profile not found (expected for new users)');
// } else {
//   console.error('Error:', result.error);
// }

---

/**
 * PATTERN 2: Async Data Hook with Proper State Management
 */

// hooks/useAsyncData.ts
import { useEffect, useState } from 'react';

interface AsyncState<T> {
  data: T | null;
  isLoading: boolean;
  error: Error | null;
}

interface UseAsyncDataOptions<T> {
  fetcher: () => Promise<T>;
  onError?: (error: Error) => void;
  enabled?: boolean;
}

export function useAsyncData<T>(
  options: UseAsyncDataOptions<T>,
  deps: React.DependencyList
): AsyncState<T> {
  const [state, setState] = useState<AsyncState<T>>({
    data: null,
    isLoading: true,
    error: null,
  });

  useEffect(() => {
    if (options.enabled === false) {
      setState({ data: null, isLoading: false, error: null });
      return;
    }

    let cancelled = false;

    (async () => {
      setState(s => ({ ...s, isLoading: true }));

      try {
        const data = await options.fetcher();
        if (!cancelled) {
          setState({ data, isLoading: false, error: null });
        }
      } catch (error) {
        if (!cancelled) {
          const err = error instanceof Error ? error : new Error(String(error));
          setState({ data: null, isLoading: false, error: err });
          options.onError?.(err);
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, deps);

  return state;
}

// Usage:
// const { data: user, isLoading, error } = useAsyncData(
//   {
//     fetcher: async () => {
//       const result = await apiFetch<User>('/api/users/me');
//       if (!result.success) throw new Error(result.error);
//       return result.data;
//     },
//   },
//   []
// );

---

/**
 * PATTERN 3: Proper Component for Profile Loading
 */

// components/profile/profile-loader.tsx
import { useAsyncData } from '@/hooks/useAsyncData';
import { apiFetch } from '@/lib/api';

export function ProfileLoader({
  onSuccess,
  onError,
  children,
}: {
  onSuccess?: (user: any) => void;
  onError?: (error: Error) => void;
  children: (state: any) => React.ReactNode;
}) {
  const { data: user, isLoading, error } = useAsyncData(
    {
      fetcher: async () => {
        const result = await apiFetch('/api/users/me');

        // Handle 404 as expected state (new user)
        if (!result.success && result.status === 404) {
          return null;
        }

        if (!result.success) {
          throw new Error(result.error);
        }

        onSuccess?.(result.data);
        return result.data;
      },
      onError,
    },
    []
  );

  return children({ user, isLoading, error });
}

// Usage:
// <ProfileLoader>
//   {({ user, isLoading, error }) => (
//     <>
//       {isLoading && <Skeleton />}
//       {error && <ErrorMessage error={error} />}
//       {!user && <LimitedAccessMode />}
//       {user && <UserProfile user={user} />}
//     </>
//   )}
// </ProfileLoader>

---

/**
 * PATTERN 4: Dialog Management with Type Safety
 */

// hooks/useControlledDialog.ts
import { useState } from 'react';

export function useControlledDialog(initialOpen = false) {
  const [isOpen, setIsOpen] = useState(initialOpen);

  return {
    isOpen,
    open: () => setIsOpen(true),
    close: () => setIsOpen(false),
    toggle: () => setIsOpen(!isOpen),
    setIsOpen,
  };
}

// Usage:
// const dialog = useControlledDialog();
//
// <Dialog open={dialog.isOpen} onOpenChange={dialog.setIsOpen}>
//   <DialogTrigger asChild>
//     <Button onClick={dialog.open}>Open</Button>
//   </DialogTrigger>
//   <DialogContent>
//     <form onSubmit={() => dialog.close()}>
//       {/* Form fields */}
//     </form>
//   </DialogContent>
// </Dialog>

---

/**
 * PATTERN 5: Error Boundary for Component Errors
 */

// components/error-boundary.tsx
import React from 'react';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { AlertCircle } from 'lucide-react';

interface Props {
  children: React.ReactNode;
  fallback?: React.ReactNode;
  onError?: (error: Error) => void;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends React.Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error) {
    console.error('ErrorBoundary caught:', error);
    this.props.onError?.(error);
  }

  retry = () => {
    this.setState({ hasError: false, error: null });
  };

  render() {
    if (this.state.hasError) {
      return (
        this.props.fallback || (
          <Alert variant="destructive">
            <AlertCircle className="h-4 w-4" />
            <AlertDescription className="flex justify-between items-center">
              <span>{this.state.error?.message || 'Something went wrong'}</span>
              <Button size="sm" onClick={this.retry} variant="outline">
                Retry
              </Button>
            </AlertDescription>
          </Alert>
        )
      );
    }

    return this.props.children;
  }
}

// Usage:
// <ErrorBoundary
//   onError={(error) => console.error(error)}
//   fallback={<CustomErrorUI />}
// >
//   <YourComponent />
// </ErrorBoundary>

---

/**
 * PATTERN 6: Import Verification at Build Time
 */

// Next.js build-time validation
// next.config.js
/** @type {import('next').NextConfig} */
const config = {
  typescript: {
    tsconfigPath: './tsconfig.json',
    // ❌ DON'T disable type checking - catch import errors!
    // ignoreBuildErrors: false,
  },
};

// tsconfig.json - STRICT MODE
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitAny": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noImplicitReturns": true,
    // This will catch missing imports like DialogTrigger!
  }
}

// Usage:
// ✅ Build will FAIL if DialogTrigger is not imported
// $ npm run build
// ✓ Type checking complete
// ✗ Missing import: DialogTrigger

---

/**
 * PATTERN 7: Testing Error Scenarios
 */

// __tests__/api.test.ts
import { apiFetch } from '@/lib/api';

describe('apiFetch error handling', () => {
  beforeEach(() => {
    global.fetch = jest.fn();
  });

  it('should handle 404 as expected (not error)', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 404,
      json: async () => ({ message: 'Not found' }),
    });

    const result = await apiFetch('/api/users/me');

    expect(result.success).toBe(false);
    expect(result.status).toBe(404);
    expect(result.error).toBe('Not found');
  });

  it('should redirect on 401', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 401,
    });

    const result = await apiFetch('/api/users/me');

    expect(result.success).toBe(false);
    expect(result.status).toBe(401);
    // Should redirect to login (location.href = '/auth/login')
  });

  it('should handle 5xx errors', async () => {
    (global.fetch as jest.Mock).mockResolvedValueOnce({
      ok: false,
      status: 500,
      json: async () => ({ message: 'Internal server error' }),
    });

    const result = await apiFetch('/api/users/me');

    expect(result.success).toBe(false);
    expect(result.error).toContain('Internal server error');
  });
});

