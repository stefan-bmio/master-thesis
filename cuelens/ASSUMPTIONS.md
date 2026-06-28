# CueLens Assumptions and Unclear Specifications

## Assumptions

- The Android app project root is `./`.
- Missing assets terminate the current phase rather than causing a crash.
- The productive app uses `PUT` requests to `submit.php`.
- Each productive study situation contains exactly five trials.
- Local app progress is only a cache. The completion count is derived from token components that were returned by the server and confirmed by the app.
- A completion token consists of 20 components with exactly three alphanumeric characters each.
- The first component is unique across the expected maximum of 85 participants and is protected by a database uniqueness constraint on `component_01`.
- The token table is not permanently related to the scientific self-report table.
- `delivered_component_count` records how many token components the server has returned.
- `confirmed_component_count` records how many returned components the app has confirmed with the second `PUT` request.
- The temporary `submission` table is used only during the three-way handshake and is cleared after confirmed transfer to `self_reports`.
- `situation_index`, `condition`, and the fixed trial count are derived server-side from the confirmed token progress and the study configuration.
- The app does not send `situation_index`, `condition`, or `trial_count` in the regular submit payload.
- A repeated confirmation request is idempotent and returns HTTP 204.
- Invalid token prefixes or malformed token components return HTTP 400 without writing study data.

## Unclear Specifications

- The exact allowed alphanumeric alphabet for token components is not yet fixed.
- The final user-facing token format is not yet fixed.
- The exact JSON response shape of the initial `submit.php` PUT is not yet fixed.
- The exact confirmation payload is not yet fixed. The current documentation prefers the full token prefix including the newly returned component.
- The retention time and cleanup behavior for stale `submission` rows are not yet fixed.
- The server response for an initial request after all 20 components have already been confirmed is not yet fixed.
- The exact behavior after app reinstallation before all 20 components have been received is not yet specified.
- The extent to which local token components and pending submissions must be encrypted on the device is not yet specified.
- The exact UI copy for the final token display and the participant instructions for compensation are not yet specified.
