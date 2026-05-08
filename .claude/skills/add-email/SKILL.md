---
name: add-email
description: Wire Cloudflare Email Sending and add an email helper + (optional) template
user-invocable: true
argument-hint: [template-name]
---

Wire Cloudflare Email Sending: **$ARGUMENTS**

Cloudflare Email Sending (Beta) sends transactional outbound mail from a verified domain. DKIM/SPF/DMARC are managed by Cloudflare. Daily quota: 1000.

## Prerequisites

- A Cloudflare-verified sending domain. Verify via the Email Routing → Email Sending dashboard before this skill will work.
- The `EMAIL_FROM` address must be on the verified domain (e.g., `no-reply@yourdomain.com`).

## Process

1. **Add the binding to `wrangler.jsonc`**:

```jsonc
"send_email": [
  { "name": "SEND_EMAIL" }
]
```

2. **Add public env vars to `wrangler.jsonc`** (these are NOT secrets):

```jsonc
"vars": {
  "EMAIL_FROM": "no-reply@yourdomain.com",
  "EMAIL_FROM_NAME": "Your App",
  "EMAIL_REPLY_TO": "support@yourdomain.com"
}
```

3. **Regenerate types**:

```bash
bun cf-typegen
```

4. **Add the helper** at `src/server/services/email.ts`:

```ts
type EmailRecipient = string | string[]

interface EmailPayload {
  to: EmailRecipient
  subject: string
  text?: string
  html?: string
  fromName?: string
  fromAddress?: string
  replyTo?: string
  cc?: EmailRecipient
  bcc?: EmailRecipient
  headers?: Record<string, string>
}

export interface EmailService {
  send(payload: EmailPayload): Promise<{ messageId: string }>
}

export function createEmail(opts: {
  binding: SendEmail
  from: string
  fromName?: string
  defaultReplyTo?: string
}): EmailService {
  return {
    async send({ to, subject, text, html, fromName, fromAddress, replyTo, cc, bcc, headers }) {
      if (!text && !html) {
        throw new Error('createEmail.send: must include text or html body')
      }
      const senderEmail = fromAddress ?? opts.from
      const senderName = fromName ?? opts.fromName
      const result = await opts.binding.send({
        from: senderName ? { name: senderName, email: senderEmail } : senderEmail,
        to,
        subject,
        replyTo: replyTo ?? opts.defaultReplyTo,
        cc,
        bcc,
        headers,
        text,
        html,
      })
      return { messageId: result.messageId }
    },
  }
}
```

5. **(Optional) Add a template** at `src/server/services/email-templates/<name>.ts`:

```ts
export function render<Name>Email(opts: { name?: string; ctaUrl: string }): {
  subject: string
  text: string
  html: string
} {
  const greeting = opts.name ? `Hi ${opts.name},` : 'Hi,'
  return {
    subject: '<subject line>',
    text: `${greeting}\n\n<plain text body with link: ${opts.ctaUrl}>\n`,
    html: `<p>${greeting}</p><p>...</p><p><a href="${opts.ctaUrl}">CTA</a></p>`,
  }
}
```

6. **Use it from a server function**:

```ts
import { createServerFn } from '@tanstack/react-start'
import { env } from 'cloudflare:workers'
import { createEmail } from '@/server/services/email'
import { render<Name>Email } from '@/server/services/email-templates/<name>'

export const send<Name> = createServerFn({ method: 'POST' }).handler(async () => {
  const email = createEmail({
    binding: env.SEND_EMAIL,
    from: env.EMAIL_FROM,
    fromName: env.EMAIL_FROM_NAME,
    defaultReplyTo: env.EMAIL_REPLY_TO,
  })
  const tpl = render<Name>Email({ ctaUrl: 'https://...' })
  return email.send({
    to: 'user@example.com',
    subject: tpl.subject,
    text: tpl.text,
    html: tpl.html,
  })
})
```

7. **Verify**:

```bash
bun typecheck
bun check:fix
```

## Conventions

- Always go through `createEmail()` — never call `env.SEND_EMAIL.send` directly. The factory enforces from/replyTo defaults.
- Templates return `{ subject, text, html }` — always include both text and HTML for deliverability.
- Local dev: `env.SEND_EMAIL` may be undefined. Guard with `if (!env.SEND_EMAIL) { console.warn(...); return }` in dev paths.
- Stripe-style transactional patterns (verify email, password reset, receipts) live under `src/server/services/email-templates/`.
- For better-auth's verification/reset hooks: pass the email render through `sendVerificationEmail` / `sendResetPassword` in `createAuth()`.
- Quota: 1000/day per CF account. Track usage if you anticipate spikes.
