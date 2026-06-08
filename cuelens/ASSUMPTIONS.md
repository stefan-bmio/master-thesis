# CueLens Assumptions and Unclear Specifications

## Assumptions

- The Android app project root is `./`.
- The MVP does not need persistence, scoring, analytics, randomization, networking, authentication, or user accounts.
- Missing assets terminate the current phase rather than causing a crash.

## Unclear Specifications

- The app behavior after the craving value is submitted is not specified.
- The app behavior if the POST request fails is not specified.
- The exact POST parameter name for the selected slider value is not specified.
