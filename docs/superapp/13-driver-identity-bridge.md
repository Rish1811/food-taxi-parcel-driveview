# 13 — Driver identity bridge (k9 backend)

**Status: APPLIED 2026-08-11** — k9 commit `a45d325` on branch
`fix/public-set-prices`, backfill run with `--apply`, service restarted and
verified. This document records why it was needed and what was done; sections
2A–2C are the change as shipped, not a proposal.

Verified after applying, with a token minted exactly as the food delivery login
mints one:

```
200  GET   /taxi/drivers/me         -> {"id":"6a364380c6c740af07e7e677","name":"mayur",...}
200  PATCH /taxi/drivers/work-mode  -> {"workMode":"all","serviceCapabilities":["taxi","delivery"]}
200  GET   /taxi/rides/active/me    -> null
200  GET   /taxi/rides              -> results[]
socket: driver document's socketId updated to the connecting client's id
```

The socket check is indirect on purpose: `configureTaxiSocketServer` writes
`socketId` onto the Driver **only** in the branch that also joins
`driver:<id>`, so the write is proof the join happened. Room membership cannot
be read from a second process — its `io` instance is a different object.

---

## 1. The problem

k9 has two driver identities that were never joined:

| | Food side | Taxi side |
|---|---|---|
| Collection | `food_delivery_partners` | `taxidrivers` |
| Login | `POST /api/v1/food/auth/delivery/verify-otp` | taxi driver OTP |
| JWT payload | `{ userId, role: "DELIVERY_PARTNER" }` | `{ sub, role: "driver" }` |
| Socket room | `delivery:<partnerId>` | `driver:<driverId>` |

Both tokens are signed with the **same** `JWT_ACCESS_SECRET`
(`src/config/env.js:41`, `:143`), so the taxi middleware can *decode* a delivery
token. It then rejects it twice over:

- `authenticate(["driver"])` — `src/modules/taxi/middlewares/authMiddleware.js:76`
  → **403**, because `DELIVERY_PARTNER` is not in `allowedRoles`.
- `roleModelMap` — same file, line 15 — has no `DELIVERY_PARTNER` entry
  → **401 "Unsupported auth role"** even if the role check passed.

And on the socket, `addSocketSubscriptions` (`dispatchService.js:457`) only joins
`driver:<id>` when `role === 'driver'`, so a delivery-partner socket is never in
the room that `emitRideRequestToDrivers` broadcasts to
(`dispatchService.js:559`).

### Live data state (db `test`, checked 2026-08-10)

```
food_delivery_partners : 4 rows, driverId = null on all 4
taxidrivers            : 6 rows, serviceCapabilities: ['delivery'] on 0
UNIFIED_DISPATCH_ENABLED = false
```

The schema for the join already exists — `FoodDeliveryPartner.driverId`
(`deliveryPartner.model.js:98`) and `Driver.serviceCapabilities` / `workMode`
(`Driver.js:130`, `:136`) — it has simply never been populated. Phone
`8770552411` is `deliveryP` on the food side and `mayur` on the taxi side: the
same human, two documents.

> Note: the live app connects to database **`test`**, not `K9`.
> `MONGODB_DB_NAME=K9` in `.env` is dead — `src/config/db.js:22` calls
> `mongoose.connect(uri)` without `dbName`, and the URI has no path, so Mongo
> defaults to `test`. Worth fixing separately; do not "fix" it by adding
> `dbName` without migrating the data first, or the app will wake up to an
> empty database.

---

## 2. The fix

Three steps. Steps A and B are additive code; step C mutates live data.

### A. Resolve a delivery-partner token to its unified driver

`src/modules/taxi/middlewares/authMiddleware.js`, inside `authenticate`, before
the `allowedRoles` check:

```js
// A driver signed in through the delivery app carries a food-issued token
// (role DELIVERY_PARTNER, sub = partner id). Where that partner is linked to a
// unified Driver, treat the request as that driver — one login, both services.
// Unlinked partners fall through and are rejected exactly as before.
if (String(payload.role || '').toUpperCase() === 'DELIVERY_PARTNER') {
  const { FoodDeliveryPartner } = await import(
    '../../food/delivery/models/deliveryPartner.model.js'
  );
  const partnerId = payload.sub || payload.userId || payload.id;
  const partner = await FoodDeliveryPartner.findById(partnerId)
    .select('driverId')
    .lean();
  if (partner?.driverId) {
    payload = { ...payload, sub: String(partner.driverId), role: 'driver' };
  }
}
```

(`payload` must become `let`.)

### B. Join the driver room for a delivery-partner socket

`src/modules/taxi/socket/index.js`, in the `connection` handler, replacing the
bare `addSocketSubscriptions(...)` call:

```js
let identity = socket.auth;

// Same bridge as the REST middleware: without it a delivery-app socket sits in
// `delivery:<partnerId>` only, and every `rideRequest` — which is emitted to
// `driver:<driverId>` — misses it silently.
if (String(identity.role || '').toUpperCase() === 'DELIVERY_PARTNER') {
  const { FoodDeliveryPartner } = await import(
    '../../food/delivery/models/deliveryPartner.model.js'
  );
  const partnerId = identity.sub || identity.userId || identity.id;
  const partner = await FoodDeliveryPartner.findById(partnerId)
    .select('driverId')
    .lean();
  if (partner?.driverId) {
    identity = { ...identity, sub: String(partner.driverId), role: 'driver' };
  }
}

addSocketSubscriptions(socket, { role: identity.role, entityId: identity.sub });
```

Everything below that line in the handler already keys off `identity`, including
the `Driver.findByIdAndUpdate(identity.sub, { socketId })` that dispatch relies
on, so it starts working unchanged.

### C. Populate the link

`scripts/migrate-unify-drivers.js` already does this and is documented as
additive and idempotent: it matches on the last 10 digits of the phone, grants
`delivery` capability to an existing driver or creates a delivery-only one,
writes `FoodDeliveryPartner.driverId`, and snapshots (never mutates) wallet
balances.

```bash
MONGODB_DB_NAME= node scripts/migrate-unify-drivers.js --apply
```

**The `MONGODB_DB_NAME=` prefix is not optional.** The script honours that env
var (`dbName: process.env.MONGODB_DB_NAME`) while the app ignores it, so run
plain it connects to the empty `K9` database, reports *"0 delivery partners to
process"*, and exits successfully having done nothing. It looks like a clean
no-op run rather than a miss.

Result on this dataset:

```
link   driver 6a364380c6c740af07e7e677 <- partner 6a2aa65a13383c724393fb5d (8770552411) +delivery
create driver <- partner 6a2d162b9141e437a9873923 (9407235770)
create driver <- partner 6a3cc39a7d5c650e57e73cf4 (7358789910)
create driver <- partner 6a606d56bf3bd898558d8cba (7610416911)
partners 4 · linked 1 · created 3 · capabilityAdded 1 · profiles 4 · errors 0
```

Only `mayur` (8770552411) holds both capabilities, so only that account can
select Both. The three created drivers are `['delivery']` only, and the app
hides the switcher for them — correct, since they are not registered for taxi.
Granting them rides is an operator decision, made by adding `taxi` to
`serviceCapabilities`.

**This merges identities on live data and needs a decision before it runs.** On
the current dataset it will fold `deliveryP` into `mayur` (both `8770552411`)
and create three delivery-only drivers for the other partners. Run the dry run
first and read the report.

---

## 3. What each step unlocks

| Without | Symptom in the app |
|---|---|
| A | Work-mode switcher never renders (`/taxi/drivers/me` → 403); every stage transition fails |
| B | Driver appears online but no ride offer ever arrives |
| C | A and B both no-op — `driverId` is null, so the bridge finds nothing to resolve |

`UNIFIED_DISPATCH_ENABLED` governs a *different* thing — the cross-service
busy-lock that stops a driver being given a food order and a ride at once. Leave
it `false` until the flow is proven, then turn it on; without it a driver in
Both mode can be double-booked.

---

## 4. Alternative considered and rejected

Minting a second, taxi-issued token at delivery login and having the app hold
both. It works, but forces two Socket.IO connections from one app (a socket
carries one token, and the driver room is joined from it), doubles the
reconnect/token-refresh surface, and leaves two independent sessions to expire
out of step. The bridge above keeps one login, one token, one socket.
