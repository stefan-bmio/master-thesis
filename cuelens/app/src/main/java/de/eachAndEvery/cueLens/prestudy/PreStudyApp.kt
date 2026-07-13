package de.eachAndEvery.cueLens.prestudy

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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
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
import de.eachAndEvery.cueLens.BuildConfig
import de.eachAndEvery.cueLens.R
import de.eachAndEvery.cueLens.infofeed.AppLanguage
import de.eachAndEvery.cueLens.infofeed.localizedStrings
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlin.math.roundToInt
import kotlin.random.Random

@Composable
fun PreStudyApp(
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current.applicationContext
    val controller = remember(context) {
        PreStudyController(
            activationService = HttpActivationService(BuildConfig.ACTIVATION_URL),
            appTokenStore = SharedPreferencesAppTokenStore(context),
            feedbackService = HttpFeedbackService(BuildConfig.FEEDBACK_URL)
        )
    }
    val state by controller.state.collectAsState()
    val scope = rememberCoroutineScope()

    when (state.route) {
        PreStudyRoute.Home -> HomeScreen(
            hasAppToken = state.hasAppToken,
            language = language,
            onLanguageChange = onLanguageChange,
            onEmailActivation = controller::openEmailActivation,
            onDemo = controller::openDemo,
            onFeedback = controller::openFeedback,
            modifier = modifier
        )
        PreStudyRoute.EmailActivation -> {
            BackHandler { controller.backToHome() }
            EmailActivationScreen(
                activationInProgress = state.activationInProgress,
                activationFailed = state.activationFailed,
                language = language,
                onLanguageChange = onLanguageChange,
                onActivate = { email -> scope.launch { controller.activate(email) } },
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
    }
}

@Composable
fun HomeScreen(
    hasAppToken: Boolean,
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onEmailActivation: () -> Unit,
    onDemo: () -> Unit,
    onFeedback: () -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    PreStudyScreenFrame(
        language = language,
        onLanguageChange = onLanguageChange,
        modifier = modifier
    ) {
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
        Spacer(modifier = Modifier.height(24.dp))
        Button(
            enabled = !hasAppToken,
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
        Spacer(modifier = Modifier.height(12.dp))
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
                modifier = Modifier.width(64.dp),
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
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedTextField(
                value = comment,
                onValueChange = { comment = it },
                enabled = !submitting,
                minLines = 5,
                label = { Text(strings.feedbackCommentLabel) },
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
    activationInProgress: Boolean,
    activationFailed: Boolean,
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onActivate: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val strings = localizedStrings(language)
    var email by remember { mutableStateOf("") }
    val validEmail = PreStudyController.isValidEmail(email)
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
            modifier = Modifier.fillMaxWidth()
        )
        if (activationFailed) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = strings.activationFailed,
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

private val PreStudyBackground = Color(0xFFD7ECE9)
private val PreStudyPrimary = Color(0xFF006269)
private const val DEMO_MATCHING_WAIT_SECONDS = 5
