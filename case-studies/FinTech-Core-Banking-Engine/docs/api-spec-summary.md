# 🔌 API Specification & Idempotency Contracts

This document summarizes core API endpoints, idempotency header contracts, and webhook integration patterns.

---

## 1. Idempotency Contract

All mutating requests (`POST`, `PUT`, `PATCH`, `DELETE`) require an `Idempotency-Key` header:

```http
POST /api/v1/transactions/transfers HTTP/1.1
Host: api.fintech-engine.io
Authorization: Bearer <API_TOKEN>
Idempotency-Key: e8a946b2-6014-41d3-90d5-5d5d6771bfa3
Content-Type: application/json

{
  "source_account_id": "acc_01HXYZ88301",
  "destination_account_id": "acc_01HXYZ99402",
  "amount_cents": 5000000,
  "currency": "RWF",
  "reference": "INVOICE-2024-901"
}
```

### Response Codes & Semantic Meaning
- `201 Created`: Transaction processed successfully for the first time.
- `200 OK`: Duplicate request detected with the same `Idempotency-Key`; returning the authoritative previously cached result.
- `409 Conflict`: Request with this `Idempotency-Key` is currently undergoing processing by another worker.
- `422 Unprocessable Entity`: Request body differs from the original request submitted under the same key.

---

## 2. Core API Endpoints

| Method | Endpoint | Description | Idempotency Required |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/accounts` | Provision a new customer or merchant ledger account | Yes |
| `GET` | `/api/v1/accounts/:id/balance` | Query real-time calculated balance from ledger lines | No |
| `POST` | `/api/v1/transactions/transfers` | Atomic transfer between accounts | Yes |
| `POST` | `/api/v1/transactions/payouts` | External disbursement (MoMo / Bank / Card) | Yes |
| `POST` | `/api/v1/webhooks/payment-rails` | Inbound payment rail webhook handler (signature verified) | Yes |
| `GET` | `/api/v1/reconciliation/reports/:date` | Fetch automated end-of-day reconciliation summary | No |

---

## 3. Webhook Security & Signature Verification

Inbound webhooks from payment rails are verified using HMAC SHA-256 signatures over the raw request payload:

```typescript
import crypto from 'crypto';

export function verifyWebhookSignature(payload: string, signatureHeader: string, secret: string): boolean {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload, 'utf8')
    .digest('hex');

  // Constant-time comparison to prevent timing attacks
  return crypto.timingSafeEqual(
    Buffer.from(signatureHeader),
    Buffer.from(expectedSignature)
  );
}
```
