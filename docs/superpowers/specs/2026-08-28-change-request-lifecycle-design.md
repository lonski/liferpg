# Change Request Lifecycle Improvements — Design

**Status:** Approved in chat (bounded-scope items, decided incrementally). This
spec exists only to give the implementation plan a binding reference.

## 1. Full-width request card (bug)

Each card in `ChangeRequestsScreen`'s admin queue is built from a `Stack`
whose non-positioned child (the crimson-bordered inner box holding the
character name / email / deltas / reason) receives *loose* width constraints
from Flutter's `Stack` layout algorithm. When the pending-only action row
(Zaakceptuj/Odrzuć/Edytuj) is absent — i.e. any accepted/rejected/cancelled
card — nothing forces that inner box to full width, so it shrink-wraps to its
longest text line and leaves the right side of the card showing bare
`cardGradient` background. Fix: give that inner `Container` an explicit
`width: double.infinity`, which Flutter's `tighten()` clamps to the maximum
width its parent (the `Stack`, itself already tight to the card's width)
offers — full width, unconditionally, regardless of which children happen to
render.

## 2. Confirm before reject

Rejecting a pending request currently fires immediately on tap. Add a
parchment-styled yes/no confirmation dialog (same visual language as the
existing edit-before-accept dialog: `parchment` background, crimson 2px
border, `fontDisplay` title) before the reject actually runs. Because a near
identical dialog is needed for cancel (item 5), factor a single reusable
helper, `showConfirmDialog`, rather than duplicate the ~25-line dialog twice.

## 3. Restore rejected → pending

Admins can currently only accept or reject; there is no way back. Add
`ChangeRequestRepository.restoreToPending`, transactionally guarded (throws a
new `ChangeRequestNotRejected` if the request is not currently `rejected`),
which flips `status` back to `pending` and clears `decidedBy`/`decidedAt` (a
restored request has not been decided). Surface it as a "Przywróć" button on
each card in the "Odrzucone" (rejected) tab. No confirmation dialog — it's
non-destructive.

## 4. Reason required on new requests

`ChangeRequestForm`'s "Powód" (reason) field is optional today. Require it
for new requests: add a non-empty validator to the field (only rendered when
`showReason: true`, i.e. only on `NewChangeRequestScreen` — the admin's
edit-before-accept dialog passes `showReason: false` and is unaffected), and
extend `NewChangeRequestScreen`'s `canSubmit` gate to also require a non-null
`_reason`.

## 5. Requester can cancel a pending request

A non-admin currently has no way to withdraw a request they no longer want
acted on. Add a fourth `ChangeRequestStatus` value, `cancelled`, so a
cancelled request stays visible in the requester's own history list (next to
Oczekuje/Zaakceptowana/Odrzucona) rather than disappearing. Firestore rule:
the requester may update their own request from `pending` to `cancelled` and
touch no other field —

```
allow update: if isAdmin()
              || (isAuthenticated()
                  && resource.data.requesterUid == request.auth.uid
                  && resource.data.status == 'pending'
                  && request.resource.data.status == 'cancelled'
                  && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status']));
allow delete: if isAdmin();
```

`ChangeRequestRepository.cancel(request)` re-reads the doc inside a
transaction (reusing the existing `_readPending` guard — a request that is no
longer pending throws `ChangeRequestNoLongerPending`, same as a double-tap on
accept/reject) and sets `status` to `cancelled`. No `decidedBy`/`decidedAt` —
this is not an admin decision. UI: a "Anuluj" affordance next to each pending
row in `NewChangeRequestScreen`'s own-requests list, gated behind the shared
`showConfirmDialog` from item 2.

Cancelled requests are invisible to the admin queue under every filter (the
same as an accepted/rejected request already is once decided) — the admin
was not asked to see cancellations, so no admin-side UI changes are in
scope.

## 6. Remove the dollars (gold_usd) field entirely

Full removal, not a UI-only hide: drop `gold_usd`/`goldUsd`/"Dolary" from the
`Character` model, `ChangeSet` model, the character card's currency chip, the
character editor form, the change-request form, the change-request delta
application, and `CLAUDE.md`'s documentation of the field. Any `gold_usd`
value already sitting on a Firestore character document is simply never read
or written again — it is not deleted from Firestore, just orphaned. This is
a scoped, mechanical removal: no new behavior, just deletion of every
reference.
