---
name: add-route
description: Add a TanStack Router file-based route (page) with optional loader and component
user-invocable: true
argument-hint: route-path [authed|public]
---

Add a route: **$ARGUMENTS**

## Process

1. **Pick the path**:
   - Public: `src/routes/_public/<name>.tsx` (login, signup, etc.)
   - Protected: `src/routes/_authed/<name>.tsx` (uses the `_authed` layout's `beforeLoad` for session)
   - Top-level: `src/routes/<name>.tsx`
   - Dynamic param: `src/routes/<path>/$<param>.tsx` (e.g., `src/routes/posts/$id.tsx`)
   - API endpoint: see `/add-server-fn` instead

2. **Skeleton**:

```tsx
import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod/v4'
import { fallback, zodValidator } from '@tanstack/zod-adapter'

// (Optional) typed search params
const searchSchema = z.object({
  page: fallback(z.number(), 1).default(1),
})

export const Route = createFileRoute('/<route-path>')({
  validateSearch: zodValidator(searchSchema),
  // (Optional) prefetch data for SSR
  loader: async ({ context }) => {
    // context.queryClient.ensureQueryData({ queryKey: [...], queryFn: () => myServerFn(...) })
  },
  component: PageComponent,
})

function PageComponent() {
  const { page } = Route.useSearch()
  return <main>...</main>
}
```

3. **Loader vs `beforeLoad`**:
   - `beforeLoad`: auth guards, context augmentation, redirects.
   - `loader`: data prefetching for SSR. Use `queryClient.ensureQueryData()` so the data participates in streaming.
   - Plain `useQuery` does NOT participate in SSR — use `useSuspenseQuery` if SSR matters.

4. **For protected routes**, the `_authed.tsx` layout handles `beforeLoad`. You don't need to duplicate the session check.

5. **Verify**:

```bash
bun typecheck
```

The TanStack Router Vite plugin regenerates `routeTree.gen.ts` automatically on file create. Don't edit the generated tree.

## Conventions

- File names: kebab-case for static segments (`my-page.tsx`), `$param` for dynamic, `_layout.tsx` for pathless layouts, `(group)/` for grouping without affecting the URL.
- Component name: PascalCase, named export `PageComponent` or domain-specific.
- Keep the route file thin: import components from `src/components/<feature>/` and call server functions from `src/server/<domain>/`.
