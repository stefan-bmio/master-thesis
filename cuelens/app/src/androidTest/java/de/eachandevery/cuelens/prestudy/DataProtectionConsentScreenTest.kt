package de.eachandevery.cuelens.prestudy

import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import de.eachandevery.cuelens.infofeed.AppLanguage
import de.eachandevery.cuelens.ui.theme.CueLensTheme
import org.junit.Rule
import org.junit.Test

class DataProtectionConsentScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun submitRequiresExplicitCheckboxSelection() {
        composeRule.setContent {
            CueLensTheme {
                DataProtectionConsentScreen(
                    consentState = DataProtectionConsentState.Required,
                    language = AppLanguage.German,
                    privacyPolicyUrl = "https://example.org/datenschutz",
                    onLanguageChange = {},
                    onOpenPrivacyPolicy = {},
                    onSubmit = {}
                )
            }
        }

        composeRule.onNodeWithText("Absenden").assertIsNotEnabled()
        composeRule
            .onNodeWithContentDescription(
                "Ich stimme der aktualisierten Datenschutzerklärung zu."
            )
            .performClick()
        composeRule.onNodeWithText("Absenden").assertIsEnabled()
    }

    @Test
    fun runningRequestDisablesConsentControls() {
        composeRule.setContent {
            CueLensTheme {
                DataProtectionConsentScreen(
                    consentState = DataProtectionConsentState.Submitting,
                    language = AppLanguage.German,
                    privacyPolicyUrl = "https://example.org/datenschutz",
                    onLanguageChange = {},
                    onOpenPrivacyPolicy = {},
                    onSubmit = {}
                )
            }
        }

        composeRule.onNodeWithText("Wird gesendet").assertIsNotEnabled()
        composeRule
            .onNodeWithContentDescription(
                "Ich stimme der aktualisierten Datenschutzerklärung zu."
            )
            .assertIsNotEnabled()
    }
}
