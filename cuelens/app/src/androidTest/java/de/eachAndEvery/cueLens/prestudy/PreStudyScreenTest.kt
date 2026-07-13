package de.eachAndEvery.cueLens.prestudy

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performTextInput
import de.eachAndEvery.cueLens.infofeed.AppLanguage
import de.eachAndEvery.cueLens.ui.theme.CueLensTheme
import org.junit.Rule
import org.junit.Test

class PreStudyScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun homeShowsDemoAndDisablesOnlyEmailActivationForExistingToken() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                HomeScreen(
                    hasAppToken = true,
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onEmailActivation = {},
                    onDemo = {},
                    onFeedback = {}
                )
            }
        }

        composeRule.onNodeWithText("Willkommen bei CueLens").assertIsDisplayed()
        composeRule.onNodeWithText("E-Mail-Aktivierung").assertIsNotEnabled()
        composeRule.onNodeWithText("Beispiel-Studiensituation").assertIsEnabled()
        composeRule.onNodeWithText("Feedback").assertIsEnabled()
        composeRule.onNodeWithText("Die App wurde bereits aktiviert.").assertIsDisplayed()
        composeRule.onNodeWithText("EN").assertIsDisplayed()
    }

    @Test
    fun activationRequiresPlausibleEmailAddress() {
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                EmailActivationScreen(
                    activationInProgress = false,
                    activationFailed = false,
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onActivate = {}
                )
            }
        }

        composeRule.onNodeWithText("Aktivieren").assertIsNotEnabled()
        composeRule.onNodeWithText("E-Mail-Adresse").performTextInput("person@example.org")
        composeRule.onNodeWithText("Aktivieren").assertIsEnabled()
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
