# CueLens Assumptions and Unclear Specifications

## Assumptions

- The Android app project root is `./`.
- Missing assets terminate the current phase rather than causing a crash.
- The productive app uses `PUT` requests for craving submissions to `submit.php`.
- Each productive study situation contains exactly five trials.
- The app treats locally stored progress as a cache. The authoritative completion count is derived from server-verified token components returned by `submit.php`.
- A new token consists of 20 components with exactly three alphanumeric characters each.
- The first token component is unique across the expected maximum of 85 participants and is protected by a database uniqueness constraint.
- The token table is not related to the craving table by a foreign key, stored token value, participant identifier, email address, or other direct relation.
- `delivered_component_count` in the token table records how many token components the server has returned to the app. It is used only to support idempotent retry of lost token responses.
- A retry request with `n == delivered_component_count - 1` token components returns component `n + 1` again, does not store the craving value again, and does not change `delivered_component_count`.
- Requests with nonexistent token prefixes, malformed token components, too few token components, or too many token components return HTTP 400 `Bad Request` without writing craving or token state.

## Unclear Specifications

- The exact allowed alphanumeric alphabet for token components is not yet fixed: case-sensitive `A-Z`, `a-z`, `0-9` versus a reduced alphabet without visually ambiguous characters.
- The final user-facing token format is not yet fixed, for example `A1b-9xQ-...` versus grouped blocks for easier manual transfer.
- The exact JSON response shape of `submit.php` is not yet fixed. It should at least contain the returned token component, the number of delivered components, and whether the request was a normal submission or an idempotent retry.
- The server response for a valid request with all 20 token components after study completion is not yet fixed. It should not store another craving value.
- The exact behavior after app reinstallation before all 20 components have been received is not yet specified.
- The extent to which local token components and pending submissions must be encrypted on the device is not yet specified.
- The exact UI copy for the final token display and the participant instructions for submitting that token for compensation are not yet specified.
