---
name: add-r2
description: Add a Cloudflare R2 bucket binding with helper functions and (optionally) a signed-URL upload route
user-invocable: true
argument-hint: bucket-name [binding-name]
---

Add an R2 bucket: **$ARGUMENTS**

Bucket name = the actual R2 bucket. Binding name = how it surfaces on `env`. Default binding name: `ASSETS_BUCKET`.

## Process

1. **Create the bucket** (if it doesn't exist):

```bash
wrangler r2 bucket create <bucket-name>
```

2. **Add the binding to `wrangler.jsonc`**:

```jsonc
"r2_buckets": [
  {
    "bucket_name": "<bucket-name>",
    "binding": "<BINDING_NAME>"
  }
]
```

3. **Regenerate types**:

```bash
bun cf-typegen
```

(`worker-configuration.d.ts` now exposes `env.<BINDING_NAME>: R2Bucket`.)

4. **Add helpers** at `src/server/services/r2.ts`:

```ts
export interface AssetInfo {
  key: string
  size: number
  etag: string
}

export async function uploadAsset(
  bucket: R2Bucket,
  key: string,
  data: ArrayBuffer | ReadableStream | string,
  contentType: string,
): Promise<AssetInfo> {
  const object = await bucket.put(key, data, {
    httpMetadata: { contentType },
  })
  if (!object) throw new Error(`Failed to upload: ${key}`)
  return { key: object.key, size: object.size, etag: object.etag }
}

export async function getAsset(
  bucket: R2Bucket,
  key: string,
): Promise<{ body: ReadableStream; contentType: string; size: number } | null> {
  const object = await bucket.get(key)
  if (!object) return null
  return {
    body: object.body,
    contentType: object.httpMetadata?.contentType ?? 'application/octet-stream',
    size: object.size,
  }
}

export async function deleteAsset(bucket: R2Bucket, key: string): Promise<void> {
  await bucket.delete(key)
}

export function buildKey(parts: string[]): string {
  return parts.filter(Boolean).join('/')
}
```

5. **(Optional) Signed URLs** for public reads — add to the same file:

```ts
// HMAC-signed URLs over a public origin, with TTL.
// The signing secret lives in CF: wrangler secret put ASSET_SIGNING_SECRET
export async function signAssetUrl(opts: {
  publicOrigin: string  // e.g. 'https://assets.example.com'
  key: string
  secret: string        // env.ASSET_SIGNING_SECRET (typed via wrangler types)
  ttlSeconds?: number
}): Promise<string> {
  const exp = Math.floor(Date.now() / 1000) + (opts.ttlSeconds ?? 3600)
  const payload = `${opts.key}:${exp}`
  const enc = new TextEncoder()
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    enc.encode(opts.secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, enc.encode(payload))
  const sigHex = Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('')
  return `${opts.publicOrigin}/${opts.key}?exp=${exp}&sig=${sigHex}`
}
```

Set the secret: `wrangler secret put ASSET_SIGNING_SECRET`. Add it to `.dev.vars` for local dev (the user must edit `.dev.vars` themselves — it's blocked from writes).

6. **(Optional) Upload server function** at `src/server/services/upload.server.ts`:

```ts
import { createServerFn } from '@tanstack/react-start'
import { env } from 'cloudflare:workers'
import { z } from 'zod/v4'
import { buildKey, uploadAsset } from './r2'

const Input = z.object({
  filename: z.string().min(1).max(255),
  contentType: z.string(),
  body: z.instanceof(ArrayBuffer),
})

export const upload = createServerFn({ method: 'POST' })
  .inputValidator(Input)
  .handler(async ({ data }) => {
    const key = buildKey([crypto.randomUUID(), data.filename])
    const info = await uploadAsset(env.<BINDING_NAME>, key, data.body, data.contentType)
    return info
  })
```

7. **Verify**:

```bash
bun typecheck
bun check:fix
```

## Conventions

- Keys: namespace by `<orgId>/<resource>/<filename>` so per-org cleanup is `bucket.list({ prefix: orgId })` + delete.
- Content-Type matters: it's read from `httpMetadata.contentType` on `bucket.get`. Set it on every `put`.
- For public reads on private buckets, sign URLs — don't make the bucket public unless it's truly public CDN content.
- Do NOT use the R2 S3 API (`https://<acct>.r2.cloudflarestorage.com/...`) from within the Worker — use the binding. The S3 API is for external clients.
