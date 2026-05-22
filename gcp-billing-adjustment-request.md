# GCP Billing Adjustment Request — Cloud Run Egress Overage

## Account details
- **Billing account:** `011945-E30212-58E5E8`
- **Project:** `demos-416206` (project number `458492091300`)
- **Service:** Cloud Run — `capware-speedtest` (us-central1)
- **Affected SKUs:** Networking → Internet Egress (North America + Intercontinental)
- **Billing period(s) affected:** approx 2026-04-29 through 2026-05-21
- **Amount being disputed:** approximately $1,000 in egress charges (see attached invoice line items)

## Summary
A bug in our Cloud Run service caused Google Front End (GFE) to be billed for egress bytes that were never received by end users. The handler streamed data into GFE's buffer indefinitely after clients disconnected, amplifying billed egress by roughly 13× the actual user-received traffic. We caught the issue, deployed a fix, and migrated end-user traffic off Cloud Run to eliminate further exposure. We are requesting a one-time billing adjustment for the affected charges.

## Root cause
The `/stream` handler in `backend/cmd/server/main.go` ran a 60-second `for` loop writing 256 KB chunks to the response writer, with no check on `r.Context().Done()`:

```go
// Buggy version (commit 747d643, deployed 2026-04-29):
deadline := time.Now().Add(60 * time.Second)
for time.Now().Before(deadline) {
    if _, err := w.Write(chunk); err != nil {
        return
    }
    if canFlush { flusher.Flush() }
}
```

Our iOS client opens parallel TCP streams and cancels them after a short fixed window (≈10 s) to measure throughput. When the client cancelled, the TCP connection between the client and GFE closed, but the Cloud Run container continued writing into GFE's buffer until either the 60-second deadline elapsed or `w.Write` returned an error from a closed downstream. GFE bills egress at the rate bytes leave the container, not the rate bytes reach the user. The result: the container wrote ≈60 seconds of data at server-side throughput for every test the client only consumed ≈10 seconds of, and the user only received roughly 1/13th of what we were billed for.

With ~30 active users running an average of ~150 tests/month, this produced ~7 TB/month of phantom egress — almost entirely on the NA and intercontinental egress SKUs visible on the invoice.

## Fix
Two changes in commit [pending — to be referenced once committed] to `backend/cmd/server/main.go`:

1. **Cancel on client disconnect.** The write loop now `select`s on `r.Context().Done()` and returns immediately when the client TCP connection closes, so the container stops writing the moment GFE can't deliver:

   ```go
   for remaining > 0 {
       select {
       case <-ctx.Done():
           return // client disconnected — stop immediately
       default:
       }
       // ... write chunk
   }
   ```

2. **Hard byte cap.** A 500 MB ceiling per request bounds the absolute worst case even if the context check ever failed:

   ```go
   const maxBytes = 500 * 1024 * 1024
   // requested defaults to maxBytes when client doesn't specify
   ```

Fix deployed to Cloud Run on 2026-05-21.

## Mitigation: migrated off Cloud Run
On 2026-05-21 we migrated end-user traffic to a Cloudflare Worker (`pulse-speedtest.capwareops.workers.dev`), which serves the same `/down` and `/up` endpoints with egress included in the $5/month Workers plan. The `capware-speedtest` Cloud Run service has since been deleted, so there is no ongoing exposure and no possibility of recurrence on this account.

## What we are asking for
- A **one-time billing credit** for the egress overage on the `capware-speedtest` Cloud Run service between 2026-04-29 and 2026-05-21, on the basis that it was a self-inflicted bug, identified and remediated within the same billing window, with the affected service being permanently migrated off GCP to prevent recurrence.

We understand that Cloud Run billing is working as designed (we are billed for what the container egresses, not what users receive), and that the overage was caused by our code. We are asking for the adjustment as a one-time goodwill credit on the grounds that:
1. The bug was caught and fixed within ~3 weeks of going live, before scaling beyond ~30 users.
2. The affected workload is being permanently migrated off GCP.
3. The cost is materially significant relative to the size of our business.

## Supporting evidence available on request
- Cloud Run revision history showing the deploy date of the buggy version and the fixed version.
- Git diff of the fix.
- Cloudflare Worker deployment showing the migration target.
- iOS client source showing the 10-second test window and stream cancellation behavior, which establishes the ~13× billing amplification.

---

*Contact: Jason Salter — jason@capware.co — Capware LLC*
