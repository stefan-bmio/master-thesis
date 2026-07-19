package de.eachandevery.cuelens.infofeed

import android.content.Context
import android.content.res.Configuration
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.eachandevery.cuelens.R
import java.util.Locale

@Composable
fun InfoMessageScreen(
    state: InfoFeedUiState.ShowingMessage,
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onHidePermanentlyChange: (Boolean) -> Unit,
    onConfirm: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    val messageText = when (language) {
        AppLanguage.German -> state.currentMessage.textDe
        AppLanguage.English -> state.currentMessage.textEn
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(FeedBackground)
            .statusBarsPadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End
        ) {
            OutlinedButton(
                enabled = !state.isConfirming,
                onClick = onLanguageChange,
                shape = RoundedCornerShape(4.dp),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = FeedPrimary),
                modifier = Modifier.semantics {
                    contentDescription = strings.languageSwitchDescription
                }
            ) {
                Text(strings.languageSwitchLabel)
            }
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = messageText,
                color = Color.Black,
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center
            )
        }
        Spacer(modifier = Modifier.height(16.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .toggleable(
                    value = state.hidePermanently,
                    enabled = !state.isConfirming,
                    role = Role.Checkbox,
                    onValueChange = onHidePermanentlyChange
                ),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(
                checked = state.hidePermanently,
                enabled = !state.isConfirming,
                onCheckedChange = null,
                colors = CheckboxDefaults.colors(checkedColor = FeedPrimary)
            )
            Text(
                text = strings.hidePermanently,
                color = Color.Black,
                style = MaterialTheme.typography.bodyMedium
            )
        }
        Spacer(modifier = Modifier.height(16.dp))
        Button(
            enabled = !state.isConfirming,
            onClick = onConfirm,
            shape = RoundedCornerShape(4.dp),
            colors = ButtonDefaults.buttonColors(containerColor = FeedPrimary),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(strings.confirm)
        }
    }
}

@Composable
fun InfoFeedLoadingScreen(
    language: AppLanguage,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(FeedBackground)
            .statusBarsPadding()
            .navigationBarsPadding(),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(color = FeedPrimary)
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = strings.loading,
                color = Color.Black,
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center
            )
        }
    }
}

data class InfoFeedStrings(
    val loading: String,
    val hidePermanently: String,
    val confirm: String,
    val loadFailed: String,
    val dismissFailed: String,
    val languageSwitchLabel: String,
    val languageSwitchDescription: String,
    val notificationConsentTitle: String,
    val notificationConsentText: String,
    val notificationConsentToggle: String,
    val continueLabel: String,
    val homeWelcome: String,
    val emailActivation: String,
    val activationAlreadyCompleted: String,
    val emailAddress: String,
    val activate: String,
    val activationRunning: String,
    val activationFailed: String,
    val activationNeedsSupport: String,
    val demoStudySituation: String,
    val demoSituationNotice: String,
    val demoImageMatchingTitle: String,
    val demoWordLabelingTitle: String,
    val demoCravingTitle: String,
    val demoMatchingWait: (Int) -> String,
    val demoMatchingPrompt: String,
    val demoLabelingPrompt: String,
    val demoFittingLabel: String,
    val demoLessFittingLabel: String,
    val demoCueImageDescription: String,
    val demoChoiceImageOne: String,
    val demoChoiceImageTwo: String,
    val demoCravingPrompt: String,
    val demoContinue: String,
    val demoCompleteTitle: String,
    val demoCompleteNotice: String,
    val backToHome: String,
    val feedback: String,
    val feedbackPrivacyNotice: String,
    val feedbackSourceLabel: String,
    val feedbackCommentLabel: String,
    val feedbackSubmit: String,
    val feedbackSubmitting: String,
    val feedbackSubmitted: String,
    val feedbackFailed: String
)

@Composable
fun localizedStrings(language: AppLanguage): InfoFeedStrings {
    val context = LocalContext.current
    val localizedContext = remember(context, language) {
        context.forLanguage(language)
    }
    return remember(localizedContext) {
        InfoFeedStrings(
            loading = localizedContext.getString(R.string.info_feed_loading),
            hidePermanently = localizedContext.getString(R.string.info_feed_hide_permanently),
            confirm = localizedContext.getString(R.string.info_feed_confirm),
            loadFailed = localizedContext.getString(R.string.info_feed_load_failed),
            dismissFailed = localizedContext.getString(R.string.info_feed_dismiss_failed),
            languageSwitchLabel = localizedContext.getString(R.string.language_switch_label),
            languageSwitchDescription = localizedContext.getString(
                R.string.language_switch_description
            ),
            notificationConsentTitle = localizedContext.getString(
                R.string.notification_consent_title
            ),
            notificationConsentText = localizedContext.getString(
                R.string.notification_consent_text
            ),
            notificationConsentToggle = localizedContext.getString(
                R.string.notification_consent_toggle
            ),
            continueLabel = localizedContext.getString(R.string.continue_label),
            homeWelcome = localizedContext.getString(R.string.home_welcome),
            emailActivation = localizedContext.getString(R.string.email_activation),
            activationAlreadyCompleted = localizedContext.getString(
                R.string.activation_already_completed
            ),
            emailAddress = localizedContext.getString(R.string.email_address),
            activate = localizedContext.getString(R.string.activate),
            activationRunning = localizedContext.getString(R.string.activation_running),
            activationFailed = localizedContext.getString(R.string.activation_failed),
            activationNeedsSupport = localizedContext.getString(R.string.activation_needs_support),
            demoStudySituation = localizedContext.getString(R.string.demo_study_situation),
            demoSituationNotice = localizedContext.getString(R.string.demo_situation_notice),
            demoImageMatchingTitle = localizedContext.getString(R.string.demo_image_matching_title),
            demoWordLabelingTitle = localizedContext.getString(R.string.demo_word_labeling_title),
            demoCravingTitle = localizedContext.getString(R.string.demo_craving_title),
            demoMatchingWait = { seconds -> localizedContext.getString(R.string.demo_matching_wait, seconds) },
            demoMatchingPrompt = localizedContext.getString(R.string.demo_matching_prompt),
            demoLabelingPrompt = localizedContext.getString(R.string.demo_labeling_prompt),
            demoFittingLabel = localizedContext.getString(R.string.demo_fitting_label),
            demoLessFittingLabel = localizedContext.getString(R.string.demo_less_fitting_label),
            demoCueImageDescription = localizedContext.getString(R.string.demo_cue_image_description),
            demoChoiceImageOne = localizedContext.getString(R.string.demo_choice_image_one),
            demoChoiceImageTwo = localizedContext.getString(R.string.demo_choice_image_two),
            demoCravingPrompt = localizedContext.getString(R.string.demo_craving_prompt),
            demoContinue = localizedContext.getString(R.string.demo_continue),
            demoCompleteTitle = localizedContext.getString(R.string.demo_complete_title),
            demoCompleteNotice = localizedContext.getString(R.string.demo_complete_notice),
            backToHome = localizedContext.getString(R.string.back_to_home),
            feedback = localizedContext.getString(R.string.feedback),
            feedbackPrivacyNotice = localizedContext.getString(R.string.feedback_privacy_notice),
            feedbackSourceLabel = localizedContext.getString(R.string.feedback_source_label),
            feedbackCommentLabel = localizedContext.getString(R.string.feedback_comment_label),
            feedbackSubmit = localizedContext.getString(R.string.feedback_submit),
            feedbackSubmitting = localizedContext.getString(R.string.feedback_submitting),
            feedbackSubmitted = localizedContext.getString(R.string.feedback_submitted),
            feedbackFailed = localizedContext.getString(R.string.feedback_failed)
        )
    }
}

private fun Context.forLanguage(language: AppLanguage): Context {
    val configuration = Configuration(resources.configuration)
    configuration.setLocale(Locale.forLanguageTag(language.languageTag))
    return createConfigurationContext(configuration)
}

private val FeedBackground = Color(0xFFD7ECE9)
private val FeedPrimary = Color(0xFF006269)
