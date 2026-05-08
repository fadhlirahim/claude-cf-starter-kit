---
name: test
description: Write or run vitest tests for server functions, schemas, components, or workflows
user-invocable: true
argument-hint: file or feature to test
---

Write or run tests for: $ARGUMENTS

## Conventions

- Test files: `[name].test.ts` next to source files
- Framework: vitest. Worker-bound code uses `@cloudflare/vitest-pool-workers` (Miniflare-backed bindings); pure helpers use the default pool with `cloudflare:workers` aliased to `src/test-utils/cloudflare-workers-stub.ts`.
- @testing-library/react for components.
- No snapshot tests — they rot.
- Don't mock internals. Mock at boundaries: external HTTP, AI Gateway calls, email send.
- Test behavior, not implementation.

## Test Patterns

### Server Function (with D1)

```typescript
import { describe, it, expect, beforeEach } from 'vitest'
import { env } from 'cloudflare:test'
import { getPost } from './get-post.server'

describe('getPost', () => {
  beforeEach(async () => {
    await env.DB.prepare('DELETE FROM post').run()
    await env.DB.prepare('INSERT INTO post (id, title) VALUES (?, ?)').bind('p1', 'Hello').run()
  })

  it('returns the post when it exists', async () => {
    const result = await getPost({ data: { id: 'p1' } })
    expect(result?.title).toBe('Hello')
  })
})
```

### Zod Schema

```typescript
describe('CreatePostSchema', () => {
  it('accepts valid input', () => {
    const result = CreatePostSchema.safeParse({ title: 'Hello' })
    expect(result.success).toBe(true)
  })
  it('rejects empty title', () => {
    const result = CreatePostSchema.safeParse({ title: '' })
    expect(result.success).toBe(false)
  })
})
```

### Workflow

```typescript
import { describe, it, expect, vi } from 'vitest'
import { MyWorkflow } from './my.workflow'

describe('MyWorkflow', () => {
  it('runs steps in order', async () => {
    const step = {
      do: vi.fn(async (_n, _o, fn) => fn()),
      sleep: vi.fn(),
    }
    const wf = new MyWorkflow({} as never, { DB: env.DB } as Env)
    await wf.run({ payload: { orgId: 'o1' } } as never, step as never)
    expect(step.do).toHaveBeenCalledWith('fetch-data', expect.anything(), expect.any(Function))
  })
})
```

### Component

```typescript
import { render, screen } from '@testing-library/react'
import { PostList } from './post-list'

it('renders titles', () => {
  render(<PostList posts={[{ id: '1', title: 'Hello' }]} />)
  expect(screen.getByText('Hello')).toBeInTheDocument()
})
```

## Running

```bash
bun test                  # all
bun test src/path         # one file
bun test:watch            # watch
```
