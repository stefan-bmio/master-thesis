package de.eachandevery.cuelens.prestudy

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import de.eachandevery.cuelens.BuildConfig
import de.eachandevery.cuelens.R
import de.eachandevery.cuelens.ProductiveStudyApp
import de.eachandevery.cuelens.retryPersistedStudyTransfer
import de.eachandevery.cuelens.infofeed.AppLanguage
import de.eachandevery.cuelens.infofeed.localizedStrings
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import java.util.Locale
import kotlin.math.roundToInt
import kotlin.random.Random

@Composable
fun PreStudyApp(
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    studyHomeOpenRequest: Long = 0L,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current.applicationContext
    val controller = remember(context) {
        PreStudyController(
            activationService = HttpActivationService(BuildConfig.ACTIVATION_URL),
            appTokenStore = AndroidKeystoreAppTokenStore(context),
            dataProtectionService = HttpDataProtectionService(BuildConfig.DATA_PROTECTION_URL),
            dataProtectionConsentStore = DataStoreDataProtectionConsentStore(context),
            featureConfigService = HttpFeatureConfigService(BuildConfig.FEATURE_CONFIG_URL),
            studyProgressStore = SharedPreferencesStudyProgressStore(context),
            studyTransferRetryService = StudyTransferRetryService {
                retryPersistedStudyTransfer(context).getOrThrow()
            },
            feedbackService = HttpFeedbackService(BuildConfig.FEEDBACK_URL)
        )
    }
    val state by controller.state.collectAsState()
    val scope = rememberCoroutineScope()
    LaunchedEffect(controller) {
        if (state.hasAppToken) {
            controller.refreshDataProtectionConsent(openScreenWhenRequired = true)
        }
    }
    LaunchedEffect(state.route, state.hasAppToken) {
        if (state.route == PreStudyRoute.Home) {
            controller.refreshNextStudyRun()
        }
    }

    LaunchedEffect(studyHomeOpenRequest) {
        if (studyHomeOpenRequest > 0L) {
            controller.backToHome()
            controller.refreshNextStudyRun()
        }
    }

    LaunchedEffect(
        state.route,
        state.nextStudyRunVisible,
        state.nextStudyRunAvailableAtMillis,
        state.studyTransferPending,
        state.studyCompleted
    ) {
        if (state.route == PreStudyRoute.Home) {
            runCatching {
                StudyReminderScheduler.reconcile(
                    context,
                    featureEnabled = state.nextStudyRunVisible
                )
            }
        }
    }

    when (state.route) {
        PreStudyRoute.Home -> HomeScreen(
            hasAppToken = state.hasAppToken,
            tokenStorageFailed = state.tokenStorageFailed,
            nextStudyRunVisible = state.nextStudyRunVisible,
            nextStudyRunEligible = state.nextStudyRunEligible,
            nextStudyRunAvailableAtMillis = state.nextStudyRunAvailableAtMillis,
            studyTransferPending = state.studyTransferPending,
            studyTransferRetrying = state.studyTransferRetrying,
            studyTransferRetryFailed = state.studyTransferRetryFailed,
            studyCompleted = state.studyCompleted,
            compensationCode = state.compensationCode,
            language = language,
            onLanguageChange = onLanguageChange,
            onEmailActivation = controller::openEmailActivation,
            onDemo = controller::openDemo,
            onFeedback = controller::openFeedback,
            onNextStudyRun = { scope.launch { controller.openNextStudyRun() } },
            onRetryStudyTransfer = {
                scope.launch { controller.retryPendingStudyTransfer() }
            },
            modifier = modifier
        )
        PreStudyRoute.EmailActivation -> {
            BackHandler { controller.backToHome() }
            EmailActivationScreen(
                activationState = state.activationState,
                activationNeedsSupport = state.activationNeedsSupport,
                language = language,
                onLanguageChange = onLanguageChange,
                onActivate = { email -> scope.launch { controller.activate(email) } },
                modifier = modifier
            )
        }
        PreStudyRoute.DataProtectionConsent -> {
            BackHandler {
                if (state.dataProtectionConsentState != DataProtectionConsentState.Submitting) {
                    controller.backToHome()
                }
            }
            val privacyPolicyUrl = if (language == AppLanguage.English) {
                BuildConfig.PRIVACY_POLICY_URL_EN
            } else {
                BuildConfig.PRIVACY_POLICY_URL_DE
            }
            DataProtectionConsentScreen(
                consentState = state.dataProtectionConsentState,
                language = language,
                privacyPolicyUrl = privacyPolicyUrl,
                onLanguageChange = onLanguageChange,
                onOpenPrivacyPolicy = {
                    val uri = Uri.parse(privacyPolicyUrl)
                    if (uri.scheme.equals("https", ignoreCase = true)) {
                        runCatching {
                            context.startActivity(
                                Intent(Intent.ACTION_VIEW, uri).addFlags(
                                    Intent.FLAG_ACTIVITY_NEW_TASK
                                )
                            )
                        }
                    }
                },
                onSubmit = { scope.launch { controller.acceptDataProtection() } },
                modifier = modifier
            )
        }
        PreStudyRoute.DemoImageMatching -> {
            BackHandler { controller.backToHome() }
            DemoImageMatchingScreen(
                language = language,
                onLanguageChange = onLanguageChange,
                onSelected = controller::advanceDemo,
                modifier = modifier
            )
        }
        PreStudyRoute.DemoWordLabeling -> {
            BackHandler { controller.backToHome() }
            DemoWordLabelingScreen(
                language = language,
                onLanguageChange = onLanguageChange,
                onSelected = controller::advanceDemo,
                modifier = modifier
            )
        }
        PreStudyRoute.DemoCraving -> {
            BackHandler { controller.backToHome() }
            DemoCravingScreen(
                language = language,
                onLanguageChange = onLanguageChange,
                onSubmit = controller::advanceDemo,
                modifier = modifier
            )
        }
        PreStudyRoute.DemoComplete -> {
            BackHandler { controller.backToHome() }
            DemoCompleteScreen(
                language = language,
                onLanguageChange = onLanguageChange,
                onFinish = controller::backToHome,
                modifier = modifier
            )
        }
        PreStudyRoute.Feedback -> {
            BackHandler { controller.backToHome() }
            FeedbackScreen(
                submitting = state.feedbackSubmitting,
                submitted = state.feedbackSubmitted,
                failed = state.feedbackFailed,
                language = language,
                onLanguageChange = onLanguageChange,
                onSubmit = { source, comment ->
                    scope.launch { controller.submitFeedback(source, comment, BuildConfig.VERSION_NAME) }
                },
                onFinish = controller::backToHome,
                modifier = modifier
            )
        }
        PreStudyRoute.ProductiveStudy -> {
            ProductiveStudyApp(
                language = language,
                onLanguageChange = onLanguageChange,
                onExit = controller::backToHome,
                modifier = modifier
            )
        }
    }
}

@Composable
internal fun DataProtectionConsentScreen(
    consentState: DataProtectionConsentState,
    language: AppLanguage,
    privacyPolicyUrl: String,
    onLanguageChange: () -> Unit,
    onOpenPrivacyPolicy: () -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    var accepted by remember { mutableStateOf(false) }
    val requestRunning =
        consentState == DataProtectionConsentState.Checking ||
            consentState == DataProtectionConsentState.Submitting
    val trustedPolicyUrl = remember(privacyPolicyUrl) {
        runCatching {
            Uri.parse(privacyPolicyUrl).scheme.equals("https", ignoreCase = true)
        }.getOrDefault(false)
    }

    PreStudyScreenFrame(
        language = language,
        onLanguageChange = onLanguageChange,
        modifier = modifier
    ) {
        Text(
            text = strings.dataProtectionTitle,
            color = Color.Black,
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = strings.dataProtectionNotice,
            color = Color.Black,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(16.dp))
        OutlinedButton(
            enabled = trustedPolicyUrl && !requestRunning,
            onClick = onOpenPrivacyPolicy,
            shape = RoundedCornerShape(4.dp),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = PreStudyPrimary),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(strings.dataProtectionOpenPolicy)
        }
        Spacer(modifier = Modifier.height(16.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(
                checked = accepted,
                enabled = !requestRunning,
                onCheckedChange = { accepted = it },
                colors = CheckboxDefaults.colors(checkedColor = PreStudyPrimary),
                modifier = Modifier.semantics {
                    contentDescription = strings.dataProtectionAccept
                }
            )
            Text(
                text = strings.dataProtectionAccept,
                color = Color.Black,
                style = MaterialTheme.typography.bodyMedium
            )
        }
        if (requestRunning) {
            Spacer(modifier = Modifier.height(12.dp))
            CircularProgressIndicator(color = PreStudyPrimary)
        }
        if (consentState == DataProtectionConsentState.Error) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = strings.dataProtectionFailed,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center
            )
        }
        Spacer(modifier = Modifier.height(20.dp))
        Button(
            enabled = accepted && !requestRunning && trustedPolicyUrl,
            onClick = onSubmit,
            shape = RoundedCornerShape(4.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = PreStudyPrimary,
                disabledContainerColor = PreStudyDisabledButton
            ),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(
                if (consentState == DataProtectionConsentState.Submitting) {
                    strings.dataProtectionSubmitting
                } else {
                    strings.dataProtectionSubmit
                }
            )
        }
    }
}

@Composable
fun HomeScreen(
    hasAppToken: Boolean,
    tokenStorageFailed: Boolean = false,
    nextStudyRunVisible: Boolean = false,
    nextStudyRunEligible: Boolean = false,
    nextStudyRunAvailableAtMillis: Long = 0L,
    studyTransferPending: Boolean = false,
    studyTransferRetrying: Boolean = false,
    studyTransferRetryFailed: Boolean = false,
    studyCompleted: Boolean = false,
    compensationCode: String? = null,
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onEmailActivation: () -> Unit,
    onDemo: () -> Unit,
    onFeedback: () -> Unit,
    onNextStudyRun: () -> Unit = {},
    onRetryStudyTransfer: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    val context = LocalContext.current
    val clipboardManager = remember(context) {
        context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    }
    var nowMillis by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val remainingCooldownMillis = maxOf(0L, nextStudyRunAvailableAtMillis - nowMillis)
    val nextStudyRunEnabled = nextStudyRunEligible && remainingCooldownMillis == 0L

    LaunchedEffect(nextStudyRunVisible, nextStudyRunAvailableAtMillis) {
        while (nextStudyRunVisible && nextStudyRunAvailableAtMillis > System.currentTimeMillis()) {
            nowMillis = System.currentTimeMillis()
            delay(1_000L)
        }
        nowMillis = System.currentTimeMillis()
    }

    PreStudyScreenFrame(
        language = language,
        onLanguageChange = onLanguageChange,
        modifier = modifier
    ) {
        if (studyCompleted) {
            if (!compensationCode.isNullOrBlank()) {
                Text(
                    text = strings.studyCompensationCode,
                    color = Color.Black,
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = compensationCode,
                    color = Color.Black,
                    style = MaterialTheme.typography.headlineMedium,
                    textAlign = TextAlign.Center
                )
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedButton(
                    onClick = {
                        clipboardManager.setPrimaryClip(
                            ClipData.newPlainText(strings.studyCompensationCode, compensationCode)
                        )
                    },
                    shape = RoundedCornerShape(4.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = PreStudyPrimary),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(strings.studyCopyCompensationCode)
                }
            }
        } else {
            Text(
                text = strings.homeWelcome,
                color = Color.Black,
                style = MaterialTheme.typography.titleLarge,
                textAlign = TextAlign.Center
            )
            if (hasAppToken) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = strings.activationAlreadyCompleted,
                    color = Color.Black,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center
                )
            }
            if (nextStudyRunVisible) {
                Spacer(modifier = Modifier.height(12.dp))
                Button(
                    enabled = nextStudyRunEnabled,
                    onClick = onNextStudyRun,
                    shape = RoundedCornerShape(4.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = PreStudyPrimary,
                        contentColor = Color.White,
                        disabledContainerColor = PreStudyDisabledButton,
                        disabledContentColor = Color.White
                    ),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        if (remainingCooldownMillis > 0L) {
                            strings.nextStudyRunCountdown(
                                formatStudyCooldown(remainingCooldownMillis)
                            )
                        } else {
                            strings.nextStudyRun
                        }
                    )
                }
            }
            if (studyTransferPending) {
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedButton(
                    enabled = !studyTransferRetrying,
                    onClick = onRetryStudyTransfer,
                    shape = RoundedCornerShape(4.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = PreStudyPrimary),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        if (studyTransferRetrying) {
                            strings.studyTransferRunning
                        } else {
                            strings.studyRetryPendingTransfer
                        }
                    )
                }
            }
            if (studyTransferRetryFailed) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = strings.studySubmissionFailed,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center
                )
            }
            if (tokenStorageFailed) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = strings.activationFailed,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center
                )
            }
            Spacer(modifier = Modifier.height(24.dp))
            Button(
                enabled = !hasAppToken && !tokenStorageFailed,
                onClick = onEmailActivation,
                shape = RoundedCornerShape(4.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(strings.emailActivation)
            }
            Spacer(modifier = Modifier.height(12.dp))
            Button(
                onClick = onDemo,
                shape = RoundedCornerShape(4.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(strings.demoStudySituation)
            }
        }
        Spacer(modifier = Modifier.height(if (studyCompleted) 24.dp else 12.dp))
        Button(
            onClick = onFeedback,
            shape = RoundedCornerShape(4.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(strings.feedback)
        }
    }
}

internal fun formatStudyCooldown(durationMillis: Long): String {
    val totalSeconds = (durationMillis.coerceAtLeast(0L) + 999L) / 1_000L
    val hours = totalSeconds / 3_600L
    val minutes = (totalSeconds % 3_600L) / 60L
    val seconds = totalSeconds % 60L
    return String.format(Locale.ROOT, "%02d:%02d:%02d", hours, minutes, seconds)
}

@Composable
internal fun DemoImageMatchingScreen(
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onSelected: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    val choices = remember {
        if (Random.nextBoolean()) listOf(R.drawable.match_a_000, R.drawable.match_b_000)
        else listOf(R.drawable.match_b_000, R.drawable.match_a_000)
    }
    var remainingSeconds by remember { mutableStateOf(DEMO_MATCHING_WAIT_SECONDS) }
    androidx.compose.runtime.LaunchedEffect(Unit) {
        repeat(DEMO_MATCHING_WAIT_SECONDS) { elapsedSeconds ->
            delay(1000)
            remainingSeconds = DEMO_MATCHING_WAIT_SECONDS - elapsedSeconds - 1
        }
    }
    PreStudyScreenFrame(language, onLanguageChange, modifier) {
        DemoHeading(strings.demoImageMatchingTitle, strings.demoSituationNotice)
        Spacer(modifier = Modifier.height(16.dp))
        Image(
            painter = painterResource(R.drawable.cue_000),
            contentDescription = strings.demoCueImageDescription,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(16.dp))
        if (remainingSeconds == 0) {
            Text(
                text = strings.demoMatchingPrompt,
                color = Color.Black,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center
            )
        }
        Spacer(modifier = Modifier.height(12.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            DemoImageChoice(choices[0], remainingSeconds == 0, strings.demoChoiceImageOne, onSelected, Modifier.weight(1f))
            androidx.compose.foundation.layout.Box(
                modifier = Modifier
                    .width(64.dp)
                    .zIndex(1f),
                contentAlignment = Alignment.Center
            ) {
                if (remainingSeconds > 0) {
                    DemoCountdownIndicator(remainingSeconds)
                }
            }
            DemoImageChoice(choices[1], remainingSeconds == 0, strings.demoChoiceImageTwo, onSelected, Modifier.weight(1f))
        }
    }
}

@Composable
private fun DemoCountdownIndicator(remainingSeconds: Int) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .requiredSize(88.dp)
            .background(
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
                shape = CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            progress = { remainingSeconds / DEMO_MATCHING_WAIT_SECONDS.toFloat() },
            modifier = Modifier.fillMaxSize(),
            strokeWidth = 4.dp
        )
        Text(
            text = remainingSeconds.toString(),
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun DemoImageChoice(
    resourceId: Int,
    enabled: Boolean,
    description: String,
    onSelected: () -> Unit,
    modifier: Modifier
) {
    Button(
        enabled = enabled,
        onClick = onSelected,
        shape = RoundedCornerShape(4.dp),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(4.dp),
        modifier = modifier
    ) {
        Image(
            painter = painterResource(resourceId),
            contentDescription = description,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
internal fun DemoWordLabelingScreen(
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onSelected: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    val labels = remember(strings.demoFittingLabel, strings.demoLessFittingLabel) {
        listOf(strings.demoFittingLabel, strings.demoLessFittingLabel).shuffled()
    }
    PreStudyScreenFrame(language, onLanguageChange, modifier) {
        DemoHeading(strings.demoWordLabelingTitle, strings.demoSituationNotice)
        Spacer(modifier = Modifier.height(16.dp))
        Image(
            painter = painterResource(R.drawable.cue_001),
            contentDescription = strings.demoCueImageDescription,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(strings.demoLabelingPrompt, color = Color.Black, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(12.dp))
        labels.forEach { label ->
            Button(
                onClick = onSelected,
                shape = RoundedCornerShape(4.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary),
                modifier = Modifier.fillMaxWidth()
            ) { Text(label) }
            Spacer(modifier = Modifier.height(8.dp))
        }
    }
}

@Composable
internal fun DemoCravingScreen(
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onSubmit: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    var craving by remember { mutableStateOf(50) }
    PreStudyScreenFrame(language, onLanguageChange, modifier) {
        DemoHeading(strings.demoCravingTitle, strings.demoSituationNotice)
        Spacer(modifier = Modifier.height(20.dp))
        Text(strings.demoCravingPrompt, color = Color.Black, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(16.dp))
        Text(craving.toString(), color = Color.Black, style = MaterialTheme.typography.headlineMedium)
        Slider(
            value = craving.toFloat(),
            onValueChange = { craving = it.roundToInt() },
            valueRange = 0f..100f,
            steps = 99,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(20.dp))
        Button(onClick = onSubmit, shape = RoundedCornerShape(4.dp), colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary), modifier = Modifier.fillMaxWidth()) {
            Text(strings.demoContinue)
        }
    }
}

@Composable
internal fun DemoCompleteScreen(
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onFinish: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    PreStudyScreenFrame(language, onLanguageChange, modifier) {
        Text(strings.demoCompleteTitle, color = Color.Black, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(16.dp))
        Text(strings.demoCompleteNotice, color = Color.Black, style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(24.dp))
        Button(onClick = onFinish, shape = RoundedCornerShape(4.dp), colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary), modifier = Modifier.fillMaxWidth()) {
            Text(strings.backToHome)
        }
    }
}

@Composable
private fun DemoHeading(title: String, notice: String) {
    Text(title, color = Color.Black, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
    Spacer(modifier = Modifier.height(8.dp))
    Text(notice, color = Color.Black, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
}

@Composable
internal fun FeedbackScreen(
    submitting: Boolean,
    submitted: Boolean,
    failed: Boolean,
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onSubmit: (String, String) -> Unit,
    onFinish: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    var source by remember { mutableStateOf("") }
    var comment by remember { mutableStateOf("") }
    val validFeedback = PreStudyController.isValidFeedback(source, comment)
    PreStudyScreenFrame(language, onLanguageChange, modifier) {
        Text(strings.feedback, color = Color.Black, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(12.dp))
        Text(strings.feedbackPrivacyNotice, color = Color.Black, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(16.dp))
        if (submitted) {
            Text(strings.feedbackSubmitted, color = Color.Black, style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center)
            Spacer(modifier = Modifier.height(24.dp))
            Button(onClick = onFinish, shape = RoundedCornerShape(4.dp), colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary), modifier = Modifier.fillMaxWidth()) {
                Text(strings.backToHome)
            }
        } else {
            OutlinedTextField(
                value = source,
                onValueChange = { source = it },
                enabled = !submitting,
                singleLine = true,
                label = { Text(strings.feedbackSourceLabel) },
                colors = preStudyTextFieldColors(),
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedTextField(
                value = comment,
                onValueChange = { comment = it },
                enabled = !submitting,
                minLines = 5,
                label = { Text(strings.feedbackCommentLabel) },
                colors = preStudyTextFieldColors(),
                modifier = Modifier.fillMaxWidth()
            )
            if (failed) {
                Spacer(modifier = Modifier.height(12.dp))
                Text(strings.feedbackFailed, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
            }
            Spacer(modifier = Modifier.height(20.dp))
            Button(
                enabled = validFeedback && !submitting,
                onClick = { onSubmit(source, comment) },
                shape = RoundedCornerShape(4.dp),
                colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(if (submitting) strings.feedbackSubmitting else strings.feedbackSubmit)
            }
        }
    }
}

@Composable
fun EmailActivationScreen(
    activationState: ActivationState,
    activationNeedsSupport: Boolean,
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onActivate: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    var email by remember { mutableStateOf("") }
    val validEmail = PreStudyController.isValidEmail(email)
    val activationInProgress = activationState == ActivationState.RequestingToken ||
        activationState == ActivationState.ConfirmingToken
    PreStudyScreenFrame(
        language = language,
        onLanguageChange = onLanguageChange,
        modifier = modifier
    ) {
        Text(
            text = strings.emailActivation,
            color = Color.Black,
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(20.dp))
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            enabled = !activationInProgress,
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
            label = { Text(strings.emailAddress) },
            colors = preStudyTextFieldColors(),
            modifier = Modifier.fillMaxWidth()
        )
        if (activationState == ActivationState.Error) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = if (activationNeedsSupport) {
                    strings.activationNeedsSupport
                } else {
                    strings.activationFailed
                },
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center
            )
        }
        Spacer(modifier = Modifier.height(20.dp))
        Button(
            enabled = validEmail && !activationInProgress,
            onClick = { onActivate(email.trim()) },
            shape = RoundedCornerShape(4.dp),
            colors = ButtonDefaults.buttonColors(containerColor = PreStudyPrimary),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (activationInProgress) strings.activationRunning else strings.activate)
        }
    }
}

@Composable
private fun PreStudyScreenFrame(
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val strings = localizedStrings(language)
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(PreStudyBackground)
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
                onClick = onLanguageChange,
                shape = RoundedCornerShape(4.dp),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = PreStudyPrimary),
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
            verticalArrangement = Arrangement.Center,
            content = content
        )
    }
}

@Composable
private fun preStudyTextFieldColors(): TextFieldColors = OutlinedTextFieldDefaults.colors(
    focusedTextColor = Color.Black,
    unfocusedTextColor = Color.Black,
    disabledTextColor = PreStudySecondaryText,
    focusedLabelColor = PreStudyPrimary,
    unfocusedLabelColor = PreStudySecondaryText,
    disabledLabelColor = PreStudySecondaryText,
    cursorColor = PreStudyPrimary,
    focusedBorderColor = PreStudyPrimary,
    unfocusedBorderColor = PreStudySecondaryText,
    disabledBorderColor = PreStudySecondaryText
)

private val PreStudyBackground = Color(0xFFD7ECE9)
private val PreStudyPrimary = Color(0xFF006269)
private val PreStudyDisabledButton = Color(0xFF527C79)
private val PreStudySecondaryText = Color(0xFF3F4A49)
private const val DEMO_MATCHING_WAIT_SECONDS = 5
