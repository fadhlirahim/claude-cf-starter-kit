---
name: add-ai-route
description: Add a Workers AI or AI SDK server function routed through AI Gateway
user-invocable: true
argument-hint: route-name [workers-ai|openai|google]
---

Add an AI-powered server function: **$ARGUMENTS**

Two flavors:
- **Workers AI** — Cloudflare's hosted models via `env.AI.run(model, input, { gateway: { id } })`
- **AI SDK** — `@ai-sdk/openai` or `@ai-sdk/google` with `baseURL` pointed at AI Gateway (so caching/logs/cost still apply)

ALL AI calls in this stack go through AI Gateway. No direct provider URLs in code.

## Workers AI flavor

Use this for Cloudflare-hosted models: `@cf/meta/llama-3.1-8b-instruct`, `@cf/black-forest-labs/flux-1-schnell`, `@cf/baai/bge-base-en-v1.5`, etc.

```ts
// src/server/ai/<route-name>.server.ts
import { createServerFn } from '@tanstack/react-start'
import { env } from 'cloudflare:workers'
import { z } from 'zod/v4'

const Input = z.object({
  prompt: z.string().min(1).max(4000),
})

export const <routeName> = createServerFn({ method: 'POST' })
  .inputValidator(Input)
  .handler(async ({ data }) => {
    const response = await env.AI.run(
      '@cf/meta/llama-3.1-8b-instruct',
      { messages: [{ role: 'user', content: data.prompt }] },
      { gateway: { id: env.AI_GATEWAY_ID } },
    )
    if (typeof response === 'object' && 'response' in response) {
      return { reply: response.response }
    }
    throw new Error('Unexpected Workers AI response shape')
  })
```

For streaming (text generation only), set `stream: true` and return the stream:

```ts
const stream = await env.AI.run(
  '@cf/meta/llama-3.1-8b-instruct',
  { messages, stream: true },
  { gateway: { id: env.AI_GATEWAY_ID } },
)
return new Response(stream as ReadableStream, {
  headers: { 'content-type': 'text/event-stream' },
})
```

## AI SDK flavor (OpenAI / Google through AI Gateway)

```ts
// src/server/ai/<route-name>.server.ts
import { createServerFn } from '@tanstack/react-start'
import { generateText } from 'ai'
import { createOpenAI } from '@ai-sdk/openai'
import { env } from 'cloudflare:workers'
import { z } from 'zod/v4'

const Input = z.object({
  prompt: z.string().min(1).max(4000),
})

export const <routeName> = createServerFn({ method: 'POST' })
  .inputValidator(Input)
  .handler(async ({ data }) => {
    const accountId = (env as unknown as Record<string, string>).CLOUDFLARE_ACCOUNT_ID
    const openai = createOpenAI({
      apiKey: (env as unknown as Record<string, string>).OPENAI_API_KEY,
      baseURL: `https://gateway.ai.cloudflare.com/v1/${accountId}/${env.AI_GATEWAY_ID}/openai`,
    })

    const { text } = await generateText({
      model: openai('gpt-4o-mini'),
      prompt: data.prompt,
    })
    return { reply: text }
  })
```

For Google (`@ai-sdk/google`), use `createGoogleGenerativeAI({ baseURL: '.../google-ai-studio', ... })` — see Cloudflare's AI Gateway provider list for the path segment per provider.

## Common: secrets

- `OPENAI_API_KEY`, `GOOGLE_GENERATIVE_AI_API_KEY` are SECRETS — set with `wrangler secret put NAME`. Don't put them in `wrangler.jsonc` `vars`.
- `CLOUDFLARE_ACCOUNT_ID`, `AI_GATEWAY_ID` can live in `vars` (they're not secret).

## Verify

```bash
bun typecheck
bun check:fix
bun dev
# Hit the route from the demo page or curl it
```

Then check the AI Gateway dashboard → **Logs** → confirm your request appears. If the request executed but no log appears, you bypassed the gateway — fix the routing.

## Conventions

- One file per AI route under `src/server/ai/`. Name: `<route-name>.server.ts`.
- Always validate input with Zod 4 — AI prompts are user input.
- Cap input length aggressively (`z.string().max(N)`). AI calls cost real money.
- For images, audio, embeddings: use `env.AI.run` with the model-specific input shape (see Cloudflare's Workers AI docs via `/docs cloudflare workers-ai`).
- Don't put the AI Gateway slug in code as a string literal — use `env.AI_GATEWAY_ID`. Slugs change between staging/prod.
