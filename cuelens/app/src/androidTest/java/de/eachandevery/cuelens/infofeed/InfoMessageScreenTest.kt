package de.eachandevery.cuelens.infofeed

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.isToggleable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import de.eachandevery.cuelens.ui.theme.CueLensTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class InfoMessageScreenTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun messageScreenShowsControlsAndForwardsActions() {
        var hidePermanently = false
        var confirmed = false
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                InfoMessageScreen(
                    state = state(),
                    language = AppLanguage.German,
                    onLanguageChange = {},
                    onHidePermanentlyChange = { hidePermanently = it },
                    onConfirm = { confirmed = true }
                )
            }
        }

        composeRule.onNodeWithText("Deutsche Nachricht").assertIsDisplayed()
        composeRule.onNodeWithText("Diese Nachricht nicht mehr anzeigen").assertIsDisplayed()
        composeRule.onNode(isToggleable()).performClick()
        composeRule.onNodeWithText("OK").performClick()

        composeRule.runOnIdle {
            assertTrue(hidePermanently)
            assertTrue(confirmed)
        }
    }

    @Test
    fun languageSwitchImmediatelyUpdatesMessageAndLabels() {
        var language by mutableStateOf(AppLanguage.German)
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                InfoMessageScreen(
                    state = state(),
                    language = language,
                    onLanguageChange = { language = AppLanguage.English },
                    onHidePermanentlyChange = {},
                    onConfirm = {}
                )
            }
        }

        composeRule.onNodeWithText("EN").performClick()

        composeRule.onNodeWithText("English message").assertIsDisplayed()
        composeRule.onNodeWithText("Do not show this message again").assertIsDisplayed()
        composeRule.onNodeWithText("DE").assertIsDisplayed()
    }

    @Test
    fun notificationConsentIsEnabledByDefaultAndCanBeDeclined() {
        var enabled by mutableStateOf(true)
        var continued = false
        composeRule.setContent {
            CueLensTheme(dynamicColor = false) {
                NotificationConsentScreen(
                    language = AppLanguage.German,
                    notificationsEnabled = enabled,
                    onNotificationsEnabledChange = { enabled = it },
                    onLanguageChange = {},
                    onContinue = { continued = true },
                    enabled = true
                )
            }
        }

        composeRule.onNodeWithText("Benachrichtigungen zulassen").assertIsDisplayed()
        composeRule.onNodeWithText(
            "CueLens kann Sie über neue allgemeine Informationen wie Update-Hinweise und über " +
                "die Verfügbarkeit einer neuen Studienaufgabe informieren. Benachrichtigungen " +
                "enthalten keine Angaben zu Rauchstatus oder Rauchverlangen."
        ).assertIsDisplayed()
        composeRule.onNode(isToggleable()).performClick()
        composeRule.onNodeWithText("Weiter").performClick()

        composeRule.runOnIdle {
            assertTrue(!enabled)
            assertTrue(continued)
        }
    }

    private fun state() = InfoFeedUiState.ShowingMessage(
        messages = listOf(
            InfoMessage(
                id = 1L,
                createdAtUtc = "2026-07-07T20:00:00Z",
                textDe = "Deutsche Nachricht",
                textEn = "English message"
            )
        ),
        index = 0
    )
}
