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

2. **Pick a data-loading shape** (all three are valid — choose by whether the route needs a client cache):

   **A. Read-once, no client cache** — return data straight from the loader. Simplest, fully SSR'd.

   ```tsx
   export const Route = createFileRoute('/<route-path>')({
     loader: () => listThings(), // a server fn
     component: PageComponent,
   })

   function PageComponent() {
     const things = Route.useLoaderData()
     return <main>...</main>
   }
   ```

   **B. Cached + interactive (default)** — `ensureQueryData` in the loader, `useSuspenseQuery` in the component. Factor the shared key + fetcher into one `queryOptions` so both hit the same cache entry. Use this when the page mutates data, needs invalidation, or background refetch.

   ```tsx
   import { queryOptions, useSuspenseQuery } from '@tanstack/react-query'
   import { createFileRoute } from '@tanstack/react-router'
   import { getThing } from '@/server/services/get-thing.server'

   const thingQueryOptions = (id: string) =>
     queryOptions({ queryKey: ['thing', id], queryFn: () => getThing({ data: { id } }) })

   export const Route = createFileRoute('/things/$id')({
     loader: ({ context, params }) => context.queryClient.ensureQueryData(thingQueryOptions(params.id)),
     component: PageComponent,
   })

   function PageComponent() {
     const { id } = Route.useParams()
     const { data } = useSuspenseQuery(thingQueryOptions(id))
     return <main>...</main>
   }
   ```

   For non-blocking prefetch (component renders a loading state while data streams in), swap `ensureQueryData` for `prefetchQuery` and drop the `await`.

   Typed search params work with either shape:

   ```tsx
   import { z } from 'zod/v4'
   import { fallback, zodValidator } from '@tanstack/zod-adapter'

   const searchSchema = z.object({ page: fallback(z.number(), 1).default(1) })
   // validateSearch: zodValidator(searchSchema) inside the route options
   ```

3. **Loader vs `beforeLoad`**:
   - `beforeLoad`: auth guards, context augmentation, redirects.
   - `loader`: data fetching/prefetching for SSR.
   - IMPORTANT: plain `useQuery` does NOT execute on the server — the HTML ships with a loading state. Use `useSuspenseQuery` (shape B) or a plain loader return (shape A) for anything server-rendered. This relies on `setupRouterSsrQueryIntegration` already being wired in `src/router.tsx`.

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
