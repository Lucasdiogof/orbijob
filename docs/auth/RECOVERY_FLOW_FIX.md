# Password recovery and account deletion: root causes and fix (2026-10-14)

Three bugs found in a manual test. Commits `df302f5` (deletion) and `43be697` (recovery), CI green.

## 1. A valid recovery code went to the Home without asking for a new password

**Root cause.** `verifyOTP(type: recovery)` creates a real Supabase session and the client emits `SIGNED_IN`. The app treated that session as
an ordinary sign-in in two places, and the outcome depended on the order in which two events arrived:

* `UserScope` keyed the account scope on `AuthState.user`. A new user id made it `popUntil(first)` and rebuild every account cubit.
* The cubit set `recovering = true` only after `verifyOTP` returned, and `AuthEffects` (inside the shell) then *pushed* the new-password route.
  * If `SIGNED_IN` arrived **after** that push, `UserScope` popped every route, including the new-password screen, and the Home remained.
  * If it arrived **before**, the code screen and the login were popped, and the push that followed depended on a listener mounted in the rebuilt
    tree.

**Fix.**

* `AuthCubit` has an explicit pending-recovery state.
  * It marks "verifying a code" *before* calling `verifyOTP`, so a session that appears during or right after that call is the recovery session.
  * After the call it also reads the repository's current session, so it never waits for the `SIGNED_IN` event.
* `AuthState.signedIn` is false and `AuthState.accountUser` is null while recovering: no account scope, no Home, no account data.
* `AuthGate` (the first route, never popped) shows **only** the new-password form while recovering, and removes the screens stacked on top
  (login, code). The form now has a confirmation field.
* Saving calls `updateUser` while the recovery session is still valid. Only after success does it sign that session out; the login then opens
  with "Password changed. Sign in with your new password."
* A marker on the device (`auth.recovery_pending_user`, the account id only) makes a restart in the middle of the recovery return to the form
  instead of the Home.

## 2. The new-password form appeared after deleting the account

**Root cause.** `recovering` stayed `true` because the form had never been shown. The recovery listener in `AuthEffects` had no `listenWhen`, so
**any** state emission with `recovering == true` opened the form. The deletion emits busy states, and those triggered it.

**Fix.**

* Sign-out, account deletion (start and end), a session of another account, and losing the session all clear the recovery and its marker.
* `AuthEffects` no longer opens the form at all; it reacts only to *transitions* of a notice or a failure.
* The form is driven by the state in `AuthGate`, so no late callback can bring it back.

## 3. The delete button did not enable for the current password

**Root cause.** There was no minimum-length rule: `_ready` already required only a non-empty password and the ticked box. The dialog simply did
not rebuild while the person typed. If the box was ticked first and the password typed afterwards, `_ready` was never evaluated again, so the
button stayed off.

**Fix.** The dialog listens to the password field. Any non-empty **current** password may be tried; the server (`account-delete`) checks it,
answers "That password is not correct. Nothing was deleted." when it is wrong, and keeps its own rate limit. The rules for creating a password
are unchanged.

## Regression tests

| # | Test file |
|---|---|
| 1, 2, 3 | `test/cubits/auth_recovery_flow_test.dart`, valid code with `SIGNED_IN` during and after `verifyOTP`; `test/features/recovery_code_test.dart` (screen flow: only the form, mismatch refused, login with the confirmation); `test/features/data_flows_test.dart` |
| — | `updateUser runs while the recovery session is still valid (no sign-out before it)` |
| 4 | wrong or expired code: error, nobody signed in, no recovery pending |
| 5 | sign-out during the recovery clears it and its marker |
| 6, 7 | deletion after an unfinished recovery, deletion from a recovery session, late session events: no state with `recovering` |
| 8, 9 | cubit: short current password accepted, wrong password = server error; widget: box ticked first, then a 2-3 character password (`account_data_test.dart`) |
| 10 | the deletion widget test runs in EN, PT and ES |
| 11 | restart in the middle of the recovery returns to the form; a marker of another account is ignored |

`account-delete` and `account-export` were not changed. The tests use `FakeAuth`; no real account was deleted.
