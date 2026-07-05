# CueLens Assumptions and Resolved Specifications

## Assumptions

- The Android app project root is `./`.
- Missing assets terminate the current phase rather than causing a crash.
- The productive app uses JSON `PUT` requests to `submit.php`; the older `POST` form submission is obsolete.
- The former 20-component completion token is replaced by a server-side HMAC-SHA-256 hash chain with 20 steps.
- The server stores the HMAC secret only in the protected server-side `config` directory.
- The server does not persist the app token; it stores only the currently valid next HMAC value in `valid_hashes`.
- Each productive study situation contains exactly five trials.
- Local app progress is only a cache. Authoritative progress is whether the app holds the next valid HMAC value returned by the server and confirmed by the app.
- The temporary `submission` table is used only during the three-way handshake and is cleared after confirmed transfer to `self_reports`.
- `situation_index`, `condition_code`, and the fixed trial count are derived server-side from the HMAC chain index and the study configuration.
- The app does not send `situation_index`, `condition_code`, or `trial_count` in the regular submit payload.
- A repeated confirmation request is idempotent and returns HTTP 204.
- Malformed UUIDs, malformed HMAC hashes, missing required fields, unknown hashes, HMAC-chain mismatches, and invalid craving values return HTTP 400 without writing study data.
- There are no cleanup rules for stale `submission` rows; unresolved rows remain for later manual inspection.
- App reinstallation resets participation state on the device for data protection reasons. The server does not reconstruct app tokens or HMAC state for a reinstalled app.
- Local app tokens, current hashes, pending submissions, and pending confirmation hashes should be stored as sensitive local state; encryption remains recommended when feasible for the target Android version.
- The final compensation proof shown to participants is the UUID stored in `compensation_code`.

## Resolved Specifications

- `PUT` replaces the older `POST` endpoint behavior.
- HMAC-Hash-Chain replaces the older 20-components-token design.
- The initial registration response returns JSON with `app_token` and `hash`.
- A regular initial self-report response returns JSON with `next_hash`, `situation_index`, and `condition_code`.
- The regular confirmation payload uses `confirmed_hash`.
- The final self-report response returns JSON with `status: "complete"` and `compensation_code`.
- Final compensation confirmation uses a `compensation_code` payload and returns HTTP 204.
- A request after app reinstallation is treated as a fresh device state; the server does not recover previous local token material.

## Remaining Unclear Specifications

- Exact UI copy for the final token display and participant instructions for compensation is not yet specified.
- The current `compensation_code` table does not persist a link to `participant_id` or `consumed_hash`; therefore an already issued final code cannot be reconstructed from a retry if the final response was lost.
