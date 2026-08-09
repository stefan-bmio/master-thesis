package de.eachandevery.cuelens.prestudy

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTextInput
import de.eachandevery.cuelens.infofeed.AppLanguage
import de.eachandevery.cuelens.ui.theme.CueLensTheme
import org.junit.Rule
import org.junit.Test

class PreStudyScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun homeShowsDemoAndDisablesOnlyAppActivationForExistingToken() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                HomeScreen(
                    hasAppToken = true,
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onAppActivation = {},
                    onDemo = {},
                    onFeedback = {}
                )
            }
        }

        composeRule.onNodeWithText("Willkommen bei CueLens").assertIsDisplayed()
        composeRule.onNodeWithText("App-Aktivierung").assertIsNotEnabled()
        composeRule.onNodeWithText("Beispiel-Studiensituation").assertIsEnabled()
        composeRule.onNodeWithText("Feedback").assertIsEnabled()
        composeRule.onNodeWithText("Die App ist aktiviert.").assertIsDisplayed()
        composeRule.onNodeWithText("EN").assertIsDisplayed()
    }

    @Test
    fun activationAcceptsEmailAddressAndExplainsProlificIdentifier() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                EmailActivationScreen(
                    activationState = ActivationState.Idle,
                    activationNeedsSupport = false,
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onActivate = {}
                )
            }
        }

        composeRule.onNodeWithText("Aktivieren").assertIsNotEnabled()
        composeRule.onNodeWithText("App-Aktivierung").assertIsDisplayed()
        composeRule.onNodeWithText("E-Mail-Adresse oder Prolific-ID")
            .performTextInput("person@example.org")
        composeRule.onNodeWithText("Aktivieren").assertIsEnabled()
        composeRule.onNodeWithText(
            "Wenn Sie über Prolific teilnehmen, geben Sie hier Ihre Prolific-ID ein."
        ).assertIsDisplayed()
    }

    @Test
    fun activationAcceptsProlificId() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                EmailActivationScreen(
                    activationState = ActivationState.Idle,
                    activationNeedsSupport = false,
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onActivate = {}
                )
            }
        }

        composeRule.onNodeWithText("E-Mail-Adresse oder Prolific-ID")
            .performTextInput("AbCdEf1234567890GhIjKlMn")
        composeRule.onNodeWithText("Aktivieren").assertIsEnabled()
    }

    @Test
    fun directCompletionKeepsCodeAndCopyAction() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                HomeScreen(
                    hasAppToken = true,
                    completionState = CompletionState.DirectCompleted("COMP-1234"),
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onAppActivation = {},
                    onDemo = {},
                    onFeedback = {}
                )
            }
        }

        composeRule.onNodeWithText("Studie abgeschlossen").assertIsDisplayed()
        composeRule.onNodeWithText("COMP-1234").assertIsDisplayed()
        composeRule.onNodeWithText("Code kopieren").assertIsDisplayed()
    }

    @Test
    fun prolificCompletionShowsExactGermanTextWithoutCodeUi() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                HomeScreen(
                    hasAppToken = true,
                    completionState = CompletionState.ProlificCompleted,
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onAppActivation = {},
                    onDemo = {},
                    onFeedback = {}
                )
            }
        }

        composeRule.onNodeWithText(
            "Studie abgeschlossen. Der Abschluss bei Prolific erfolgt üblicherweise innerhalb 2 Tagen."
        ).assertIsDisplayed()
        composeRule.onNodeWithText("Code kopieren").assertDoesNotExist()
        composeRule.onNodeWithText("Aufwandsentschädigungscode", substring = true)
            .assertDoesNotExist()
    }

    @Test
    fun prolificCompletionShowsExactEnglishText() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                HomeScreen(
                    hasAppToken = true,
                    completionState = CompletionState.ProlificCompleted,
                    language = AppLanguage.English,
                    onLanguageChange = {},
                    onAppActivation = {},
                    onDemo = {},
                    onFeedback = {}
                )
            }
        }

        composeRule.onNodeWithText(
            "Study completed. Completion on Prolific usually takes place within 2 days."
        ).assertIsDisplayed()
        composeRule.onNodeWithText("Copy code").assertDoesNotExist()
    }

    @Test
    fun demoShowsMatchingPhaseAndLocksChoicesInitially() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                DemoImageMatchingScreen(
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onSelected = {}
                )
            }
        }

        composeRule.onNodeWithText("Beispiel: Cue-Matching").assertIsDisplayed()
        composeRule.onNodeWithText("Dies ist ein Beispiel und kein Teil der Studie.").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Erste Bildauswahl").assertIsNotEnabled()
        composeRule.onNodeWithText("EN").assertIsDisplayed()
    }

    @Test
    fun demoShowsLocalizedLabeling() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                DemoWordLabelingScreen(
                    language = AppLanguage.English,
                    onLanguageChange = {},
                    onSelected = {}
                )
            }
        }

        composeRule.onNodeWithText("Example: cue labeling").assertIsDisplayed()
        composeRule.onNodeWithText("Ash smell").assertIsDisplayed()
        composeRule.onNodeWithText("Umbrella moment").assertIsDisplayed()
    }

    @Test
    fun demoCompletionExplainsThatNoDataWereStoredOrTransmitted() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                DemoCompleteScreen(
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onFinish = {}
                )
            }
        }
        composeRule.onNodeWithText("Es wurden keine Daten übertragen oder dauerhaft gespeichert.")
            .assertIsDisplayed()
    }

    @Test
    fun feedbackRequiresContentAndExplainsPrivacyBoundary() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                FeedbackScreen(
                    submitting = false,
                    submitted = false,
                    failed = false,
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onSubmit = { _, _ -> },
                    onFinish = {}
                )
            }
        }

        composeRule.onNodeWithText("Bitte geben Sie keine personenbezogenen Daten, E-Mail-Adressen oder Abrechnungscodes ein.")
            .assertIsDisplayed()
        composeRule.onNodeWithText("Absenden").assertIsNotEnabled()
        composeRule.onNodeWithText("Was gefällt Ihnen an der Studie, wobei gab es eventuell Probleme?")
            .performTextInput("Das Beispiel war verständlich.")
        composeRule.onNodeWithText("Absenden").assertIsEnabled()
    }
}
