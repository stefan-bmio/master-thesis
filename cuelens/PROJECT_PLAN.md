# CueLens MVP Project Plan

## Summary

CueLens is a portrait-only Android app that presents smoking cue images, collects tap responses in two sequential phases, and then asks the user to submit their current craving level:

1. Image matching phase: show each available `cue_0nn.png` once in natural numeric order with `match_a_0nn.png` and `match_b_0nn.png`.
2. Word matching phase: show each available `cue_1nn.png` once in natural numeric order with two tappable words from a dictionary.
3. Craving submission phase: show a question, a slider from `0` to `100`, and a submit button.

This plan covers only the MVP. A test strategy, iterative plan for further functionality, and security measures will be added later.

## Key MVP Behavior

- Lock the app to portrait mode.
- Use Jetpack Compose and keep the implementation simple.
- Load image assets from `app/src/main/res/drawable`.
- Center the cue image on the display.
- Scale the cue image to fill the full display height from top edge to bottom edge while preserving aspect ratio.
- Allow the cue image to overflow horizontally and crop the overflowing parts outside the visible display area.
- Do not leave empty background space around the cue image anywhere on the display.
- Show two tappable match images side by side near the bottom edge.
- Preserve aspect ratio for both match images.
- Overlay tappable images and word choices on top of the cue image.
- Keep reasonable spacing between choices and from bottom and side edges.
- Advance immediately after the user taps one of the two choices.
- Complete all image-matching items before starting word-matching items.
- After all available word-matching cue images have been shown once, present the craving submission view.
- Show the text `Wie hoch ist in diesem Moment Ihr Rauchverlangen?`.
- Show an integer slider with values from `0` to `100`.
- Set the default slider value to `50`.
- Show a submit button labeled `Absenden`.
- Place the text, slider, and submit button below each other and centered on the display.
- When the user taps `Absenden`, send a POST HTTP request to `https://cuelens.each-and-every.de/submit`.
- Send the selected slider value as the only POST parameter.

## Dynamic Resource Rules

- Do not hardcode the full list of cue or match drawable names.
- Discover MVP image-matching items by counting upward from `000`:
  - cue: `cue_0nn`
  - choices: `match_a_0nn`, `match_b_0nn`
- Include an image-matching item only when all three corresponding drawables exist.
- Stop the image-matching phase when the next required cue or match drawable set is missing.
- Discover MVP word-matching items by counting upward from `100`:
  - cue: `cue_1nn`
  - dictionary entry keyed by the same numeric suffix
- Include a word-matching item only when both the cue drawable and dictionary entry exist.
- Stop the word-matching phase when the next required cue drawable or dictionary entry is missing.
- Future assets are part of the MVP flow as soon as they are added with the correct names.

## Dictionary Rules

- Create a simple in-app dictionary for word-matching choices.
- Key dictionary entries by the same numeric suffix used by `cue_1nn`.
- The first entry must map `100` to:
  - `Paff`
  - `Klick`
- Additional future word-phase cue images require corresponding dictionary entries with matching suffixes.

## Implementation Direction

- Replace the default starter screen in `MainActivity.kt` with the CueLens MVP flow.
- Keep state local and minimal:
  - current phase
  - current numeric suffix/index
  - current cue drawable ID
  - current pair of choices
- Use Android resource lookup by generated drawable names, using a counter variable and formatted suffixes.
- Represent image-matching items as resolved drawable IDs.
- Represent word-matching items as a resolved cue drawable ID plus two dictionary words.
- Add a final craving submission state after the word-matching phase.
- Store the selected craving value as an integer from `0` to `100`, initialized to `50`.
- Add the minimal HTTP client functionality needed to POST the selected slider value.
- Use Compose layout primitives:
  - full-screen portrait layout
  - centered cue image that covers the visible display area by height, with horizontal overflow cropped
  - bottom-aligned row for image choices overlaid on the cue image
  - bottom-aligned row for word choices overlaid on the cue image
  - centered column for the craving text, slider, and submit button
- Use a cover-style approach for cue images so no letterboxing or empty background is visible.
- Use `ContentScale.Fit` or equivalent behavior for tappable match images so each choice remains fully visible.
- Use simple clickable components for tappable images and words.

## MVP Acceptance Checks

- `./PROJECT_PLAN.md` exists.
- The document describes only the MVP scope.
- The document does not include a formal test strategy.
- The document does not include future functionality or security sections.
- The document clearly states portrait-only behavior.
- The document captures both phases and their order.
- The document specifies dynamic resource loading by numeric suffix.
- The document treats future correctly named assets as part of the MVP.
- The document includes the initial dictionary entry: `100` -> `Paff`, `Klick`.
- The document states that cue images cover the complete visible display area with horizontal cropping allowed.
- The document states that tappable images and word choices overlay the cue image.
- The document includes the final craving submission screen.
- The document specifies the slider range, default value, submit label, endpoint, and POST behavior.
- The document follows K.I.S.S. and avoids unnecessary architecture.
