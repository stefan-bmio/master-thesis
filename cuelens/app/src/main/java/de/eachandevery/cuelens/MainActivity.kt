package de.eachandevery.cuelens

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.compose.foundation.shape.CircleShape
import de.eachandevery.cuelens.prestudy.AndroidKeystoreAppTokenStore
import de.eachandevery.cuelens.prestudy.AppTokenStore
import de.eachandevery.cuelens.prestudy.KEY_COMPENSATION_CODE
import de.eachandevery.cuelens.prestudy.KEY_CONFIRMED_SITUATION_COUNT
import de.eachandevery.cuelens.prestudy.KEY_MATCHING_ORDER
import de.eachandevery.cuelens.prestudy.KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS
import de.eachandevery.cuelens.prestudy.KEY_PENDING_SUBMISSION_CRAVING
import de.eachandevery.cuelens.prestudy.KEY_STUDY_COMPLETED
import de.eachandevery.cuelens.prestudy.NO_PENDING_CRAVING
import de.eachandevery.cuelens.prestudy.STUDY_PREFERENCES_NAME
import de.eachandevery.cuelens.infofeed.AppLanguage
import de.eachandevery.cuelens.infofeed.InfoFeedStrings
import de.eachandevery.cuelens.infofeed.localizedStrings
import de.eachandevery.cuelens.ui.theme.CueLensTheme
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.random.Random
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.MutableStateFlow
import org.json.JSONException
import org.json.JSONObject

class MainActivity : ComponentActivity() {
    private val infoFeedOpenRequests = MutableStateFlow(0L)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            val infoFeedOpenRequest by infoFeedOpenRequests.collectAsState()
            CueLensTheme {
                CueLensApp(infoFeedOpenRequest = infoFeedOpenRequest)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(
                de.eachandevery.cuelens.infofeed.AndroidInfoFeedNotifier.EXTRA_OPEN_INFO_FEED,
                false
            )
        ) {
            infoFeedOpenRequests.value += 1L
        }
    }
}

@Composable
internal fun ProductiveStudyApp(
    language: AppLanguage,
    onLanguageChange: () -> Unit,
    onExit: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val strings = localizedStrings(language)
    val imageItems = remember { loadImageMatchItems(context) }
    val wordItems = remember { loadWordMatchItems(context) }
    val coroutineScope = rememberCoroutineScope()
    val preferences = remember {
        context.getSharedPreferences(STUDY_PREFERENCES_NAME, Context.MODE_PRIVATE)
    }
    val appTokenStore = remember { AndroidKeystoreAppTokenStore(context) }
    var phase by remember { mutableStateOf(Phase.StartGate) }
    var itemIndex by remember { mutableIntStateOf(0) }
    var currentImageItems by remember { mutableStateOf(emptyList<ImageMatchItem>()) }
    var currentWordItems by remember { mutableStateOf(emptyList<WordMatchItem>()) }
    var completedSituationCount by remember {
        mutableIntStateOf(
            preferences.getInt(KEY_CONFIRMED_SITUATION_COUNT, 0)
        )
    }
    var nextRunAvailableAtMillis by remember {
        mutableStateOf(
            preferences.getLong(KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS, 0L)
        )
    }
    var matchingOrder by remember {
        mutableStateOf(loadMatchingOrder(preferences, imageItems.size))
    }
    var hasActivation by remember {
        mutableStateOf(runCatching { appTokenStore.getAppToken() != null }.getOrDefault(false))
    }
    var pendingSubmissionCraving by remember {
        mutableIntStateOf(preferences.getInt(KEY_PENDING_SUBMISSION_CRAVING, NO_PENDING_CRAVING))
    }
    var compensationCode by remember {
        mutableStateOf(preferences.getString(KEY_COMPENSATION_CODE, null))
    }
    var studyCompleted by remember {
        mutableStateOf(preferences.getBoolean(KEY_STUDY_COMPLETED, false))
    }
    var syncInProgress by remember { mutableStateOf(false) }
    var syncMessage by remember { mutableStateOf<String?>(null) }

    val refreshPersistedState = {
        completedSituationCount = preferences.getInt(KEY_CONFIRMED_SITUATION_COUNT, 0)
        nextRunAvailableAtMillis = preferences.getLong(KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS, 0L)
        hasActivation = runCatching { appTokenStore.getAppToken() != null }.getOrDefault(false)
        pendingSubmissionCraving = preferences.getInt(KEY_PENDING_SUBMISSION_CRAVING, NO_PENDING_CRAVING)
        compensationCode = preferences.getString(KEY_COMPENSATION_CODE, null)
        studyCompleted = preferences.getBoolean(KEY_STUDY_COMPLETED, false)
    }

    val syncPendingWork = {
        coroutineScope.launch {
            syncInProgress = true
            syncMessage = null
            val result = recoverPendingNetworkWork(preferences, appTokenStore)
            refreshPersistedState()
            syncInProgress = false
            if (result.isFailure) {
                syncMessage = strings.studySubmissionFailed
            }
        }
        Unit
    }

    LaunchedEffect(Unit) {
        if (hasPendingNetworkWork(preferences)) {
            syncInProgress = true
            syncMessage = null
            val result = recoverPendingNetworkWork(preferences, appTokenStore)
            refreshPersistedState()
            syncInProgress = false
            if (result.isFailure) {
                syncMessage = strings.studySubmissionFailed
            }
        }
    }

    val getMatchingOrder = {
        matchingOrder.ifEmpty {
            val generatedOrder = imageItems.indices.shuffled()
            saveMatchingOrder(preferences, generatedOrder)
            matchingOrder = generatedOrder
            generatedOrder
        }
    }

    val startRun = {
        val situationIndex = preferences.getInt(
            KEY_CONFIRMED_SITUATION_COUNT,
            completedSituationCount
        )
        itemIndex = 0
        currentImageItems = emptyList()
        currentWordItems = emptyList()
        when {
            situationIndex < MATCHING_SITUATION_COUNT -> {
                val order = getMatchingOrder()
                currentImageItems = order
                    .drop(situationIndex * TRIALS_PER_SITUATION)
                    .take(TRIALS_PER_SITUATION)
                    .mapNotNull { imageItems.getOrNull(it) }
                if (currentImageItems.isNotEmpty()) {
                    phase = Phase.ImageMatching
                }
            }
            situationIndex < TOTAL_SITUATION_COUNT -> {
                val labelSituationIndex = situationIndex - MATCHING_SITUATION_COUNT
                currentWordItems = wordItems
                    .drop(labelSituationIndex * TRIALS_PER_SITUATION)
                    .take(TRIALS_PER_SITUATION)
                if (currentWordItems.isNotEmpty()) {
                    phase = Phase.WordMatching
                }
            }
        }
    }

    val finishRun = { craving: Int ->
        preferences.edit()
            .putInt(KEY_PENDING_SUBMISSION_CRAVING, craving.coerceIn(0, 100))
            .apply()
        pendingSubmissionCraving = craving.coerceIn(0, 100)
        itemIndex = 0
        currentImageItems = emptyList()
        currentWordItems = emptyList()
        phase = Phase.StartGate
        syncPendingWork()
        Unit
    }

    val advance = {
        when (phase) {
            Phase.ImageMatching -> {
                if (itemIndex + 1 < currentImageItems.size) {
                    itemIndex += 1
                } else {
                    phase = Phase.CravingSubmission
                    itemIndex = 0
                }
            }
            Phase.WordMatching -> {
                if (itemIndex + 1 < currentWordItems.size) {
                    itemIndex += 1
                } else {
                    phase = Phase.CravingSubmission
                    itemIndex = 0
                }
            }
            Phase.StartGate,
            Phase.CravingSubmission -> Unit
        }
    }

    val networkWorkPending = pendingSubmissionCraving != NO_PENDING_CRAVING ||
        (!compensationCode.isNullOrBlank() && !studyCompleted)
    val canStartNow = hasActivation && !networkWorkPending && !syncInProgress && !studyCompleted

    LaunchedEffect(hasActivation) {
        if (!hasActivation) onExit()
    }
    BackHandler(enabled = phase == Phase.StartGate, onBack = onExit)

    Surface(modifier = modifier.fillMaxSize(), color = StudyBackground) {
        Box(modifier = Modifier.fillMaxSize()) {
            when (phase) {
            Phase.StartGate -> StartGateScreen(
                nextRunAvailableAtMillis = nextRunAvailableAtMillis,
                completedSituationCount = completedSituationCount,
                studyCompleted = studyCompleted,
                compensationCode = compensationCode,
                networkWorkPending = networkWorkPending,
                syncInProgress = syncInProgress,
                syncMessage = syncMessage,
                canStartSituation = canStartSituation(
                    completedSituationCount = completedSituationCount,
                    imageItemCount = imageItems.size,
                    wordItemCount = wordItems.size
                ) && canStartNow,
                strings = strings,
                onStartRun = startRun,
                onRetrySync = syncPendingWork
            )
            Phase.ImageMatching -> {
                val item = currentImageItems.getOrNull(itemIndex)
                if (item != null) {
                    ImageMatchScreen(item = item, onChoiceTapped = advance)
                }
            }
            Phase.WordMatching -> {
                val item = currentWordItems.getOrNull(itemIndex)
                if (item != null) {
                    WordMatchScreen(item = item, language = language, onChoiceTapped = advance)
                }
            }
            Phase.CravingSubmission -> CravingSubmissionScreen(
                prompt = strings.demoCravingPrompt,
                submitLabel = strings.studySubmit,
                onSubmit = finishRun
            )
            }
            OutlinedButton(
                onClick = onLanguageChange,
                shape = RoundedCornerShape(4.dp),
                border = BorderStroke(1.dp, StudyPrimary),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = StudyBackground,
                    contentColor = StudyPrimary
                ),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(16.dp)
            ) {
                Text(strings.languageSwitchLabel)
            }
        }
    }
}

@Composable
private fun StartGateScreen(
    nextRunAvailableAtMillis: Long,
    completedSituationCount: Int,
    studyCompleted: Boolean,
    compensationCode: String?,
    networkWorkPending: Boolean,
    syncInProgress: Boolean,
    syncMessage: String?,
    canStartSituation: Boolean,
    strings: InfoFeedStrings,
    onStartRun: () -> Unit,
    onRetrySync: () -> Unit
) {
    var nowMillis by remember { mutableStateOf(System.currentTimeMillis()) }
    val remainingMillis = max(0L, nextRunAvailableAtMillis - nowMillis)
    val studyComplete = studyCompleted || completedSituationCount >= TOTAL_SITUATION_COUNT
    val startEnabled = remainingMillis == 0L && canStartSituation && !studyComplete &&
        !networkWorkPending && !syncInProgress
    val nextSituationNumber = (completedSituationCount + 1).coerceAtMost(TOTAL_SITUATION_COUNT)

    LaunchedEffect(nextRunAvailableAtMillis) {
        while (nextRunAvailableAtMillis > System.currentTimeMillis()) {
            nowMillis = System.currentTimeMillis()
            delay(1000)
        }
        nowMillis = System.currentTimeMillis()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = when {
                studyComplete -> strings.studyCompleted
                networkWorkPending || syncInProgress -> strings.studyTransferPending
                canStartSituation -> strings.studyRunProgress(
                    nextSituationNumber,
                    TOTAL_SITUATION_COUNT
                )
                else -> strings.studyResourcesIncomplete
            },
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(12.dp))
        if (studyComplete && !compensationCode.isNullOrBlank()) {
            Text(
                text = strings.studyCompensationCode,
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = compensationCode,
                style = MaterialTheme.typography.titleMedium,
                textAlign = TextAlign.Center
            )
        } else {
            Text(
                text = if (networkWorkPending || syncInProgress) {
                    strings.studyCompleteTransfer
                } else {
                    formatDuration(remainingMillis)
                },
                style = MaterialTheme.typography.headlineMedium,
                textAlign = TextAlign.Center
            )
        }
        if (!syncMessage.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = syncMessage,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center
            )
        }
        Spacer(modifier = Modifier.height(24.dp))
        if (networkWorkPending || syncInProgress) {
            Button(
                enabled = !syncInProgress,
                onClick = onRetrySync,
                colors = ButtonDefaults.buttonColors(containerColor = StudyPrimary)
            ) {
                Text(
                    text = if (syncInProgress) strings.studyTransferRunning else strings.studyRetry
                )
            }
        } else if (!studyComplete) {
            Button(
                enabled = startEnabled,
                onClick = onStartRun,
                colors = ButtonDefaults.buttonColors(containerColor = StudyPrimary)
            ) {
                Text(text = strings.studyStartRun)
            }
        }
    }
}

@Composable
private fun ImageMatchScreen(item: ImageMatchItem, onChoiceTapped: () -> Unit) {
    val choices = remember(item.cueResId, item.matchAResId, item.matchBResId) {
        if (Random.nextBoolean()) {
            listOf(item.matchAResId, item.matchBResId)
        } else {
            listOf(item.matchBResId, item.matchAResId)
        }
    }
    var remainingSeconds by remember(item.cueResId) { mutableIntStateOf(IMAGE_MATCH_WAIT_SECONDS) }
    val choicesEnabled = remainingSeconds == 0

    LaunchedEffect(item.cueResId) {
        remainingSeconds = IMAGE_MATCH_WAIT_SECONDS
        repeat(IMAGE_MATCH_WAIT_SECONDS) { elapsedSeconds ->
            delay(1000)
            remainingSeconds = IMAGE_MATCH_WAIT_SECONDS - elapsedSeconds - 1
        }
    }

    CueScreen(cueResId = item.cueResId) {
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(start = 24.dp, end = 24.dp, bottom = 32.dp)
                .height(120.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            MatchImage(resId = choices[0], enabled = choicesEnabled, onClick = onChoiceTapped)
            Box(
                modifier = Modifier
                    .width(64.dp)
                    .zIndex(1f),
                contentAlignment = Alignment.Center
            ) {
                if (!choicesEnabled) {
                    CountdownIndicator(remainingSeconds = remainingSeconds)
                }
            }
            MatchImage(resId = choices[1], enabled = choicesEnabled, onClick = onChoiceTapped)
        }
    }
}

@Composable
private fun CountdownIndicator(remainingSeconds: Int) {
    Box(
        modifier = Modifier
            .requiredSize(88.dp)
            .background(
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.92f),
                shape = CircleShape
            ),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(
            progress = { remainingSeconds / IMAGE_MATCH_WAIT_SECONDS.toFloat() },
            modifier = Modifier.fillMaxSize(),
            strokeWidth = 4.dp
        )
        Text(
            text = remainingSeconds.toString(),
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.titleLarge.copy(
                fontSize = 28.sp,
                lineHeight = 28.sp
            ),
            textAlign = TextAlign.Center
        )
    }
}

@Composable
private fun WordMatchScreen(
    item: WordMatchItem,
    language: AppLanguage,
    onChoiceTapped: () -> Unit
) {
    val wordA = item.wordA(language)
    val wordB = item.wordB(language)
    val choices = remember(item.cueResId, wordA, wordB) {
        if (Random.nextBoolean()) {
            listOf(wordA, wordB)
        } else {
            listOf(wordB, wordA)
        }
    }

    CueScreen(cueResId = item.cueResId) {
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(start = 24.dp, end = 24.dp, bottom = 32.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Button(
                onClick = onChoiceTapped,
                colors = ButtonDefaults.buttonColors(containerColor = StudyPrimary)
            ) {
                Text(text = choices[0])
            }
            Spacer(modifier = Modifier.width(24.dp))
            Button(
                onClick = onChoiceTapped,
                colors = ButtonDefaults.buttonColors(containerColor = StudyPrimary)
            ) {
                Text(text = choices[1])
            }
        }
    }
}

@Composable
private fun CueScreen(cueResId: Int, controls: @Composable BoxScope.() -> Unit) {
    Box(modifier = Modifier.fillMaxSize()) {
        Image(
            painter = painterResource(id = cueResId),
            contentDescription = null,
            modifier = Modifier
                .align(Alignment.Center)
                .fillMaxSize(),
            contentScale = ContentScale.Crop
        )
        controls()
    }
}

@Composable
private fun MatchImage(@DrawableRes resId: Int, enabled: Boolean, onClick: () -> Unit) {
    Image(
        painter = painterResource(id = resId),
        contentDescription = null,
        modifier = Modifier
            .fillMaxHeight()
            .width(140.dp)
            .clickable(enabled = enabled, onClick = onClick),
        contentScale = ContentScale.Fit
    )
}

@Composable
private fun CravingSubmissionScreen(
    prompt: String,
    submitLabel: String,
    onSubmit: (Int) -> Unit
) {
    var craving by remember { mutableIntStateOf(50) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = prompt,
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(24.dp))
        Slider(
            value = craving.toFloat(),
            onValueChange = { craving = it.roundToInt() },
            valueRange = 0f..100f,
            steps = 99,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(24.dp))
        Button(
            onClick = {
                onSubmit(craving)
            },
            colors = ButtonDefaults.buttonColors(containerColor = StudyPrimary)
        ) {
            Text(text = submitLabel)
        }
    }
}

private fun loadImageMatchItems(context: Context): List<ImageMatchItem> {
    val items = mutableListOf<ImageMatchItem>()
    var index = 0
    while (true) {
        val suffix = "%03d".format(index)
        val cue = context.drawableId("cue_$suffix")
        val matchA = context.drawableId("match_a_$suffix")
        val matchB = context.drawableId("match_b_$suffix")
        if (cue == 0 || matchA == 0 || matchB == 0) break
        items += ImageMatchItem(cue, matchA, matchB)
        index += 1
    }
    return items
}

private fun loadWordMatchItems(context: Context): List<WordMatchItem> {
    return cueLabelMappings.mapNotNull { mapping ->
        val cue = context.drawableId(mapping.cueName)
        if (cue == 0) {
            null
        } else {
            WordMatchItem(
                cue,
                mapping.germanFittingLabel,
                mapping.germanLessFittingLabel,
                mapping.englishFittingLabel,
                mapping.englishLessFittingLabel
            )
        }
    }
}

private fun Context.drawableId(name: String): Int =
    resources.getIdentifier(name, "drawable", packageName)

private fun canStartSituation(
    completedSituationCount: Int,
    imageItemCount: Int,
    wordItemCount: Int
): Boolean =
    when {
        completedSituationCount >= TOTAL_SITUATION_COUNT -> false
        completedSituationCount < MATCHING_SITUATION_COUNT ->
            imageItemCount >= (completedSituationCount + 1) * TRIALS_PER_SITUATION
        else -> {
            val labelSituationIndex = completedSituationCount - MATCHING_SITUATION_COUNT
            wordItemCount > labelSituationIndex * TRIALS_PER_SITUATION
        }
    }

private fun loadMatchingOrder(preferences: SharedPreferences, imageItemCount: Int): List<Int> {
    val savedOrder = preferences.getString(KEY_MATCHING_ORDER, null).orEmpty()
    if (savedOrder.isBlank()) return emptyList()

    val order = savedOrder
        .split(",")
        .mapNotNull { value -> value.toIntOrNull() }

    return if (order.size == imageItemCount && order.toSet().size == imageItemCount) {
        order
    } else {
        emptyList()
    }
}

private fun saveMatchingOrder(preferences: SharedPreferences, order: List<Int>) {
    preferences.edit()
        .putString(KEY_MATCHING_ORDER, order.joinToString(","))
        .apply()
}

private fun formatDuration(durationMillis: Long): String {
    val totalSeconds = durationMillis / 1000
    val hours = totalSeconds / 3600
    val minutes = (totalSeconds % 3600) / 60
    val seconds = totalSeconds % 60
    return "%02d:%02d:%02d".format(hours, minutes, seconds)
}

internal suspend fun retryPersistedStudyTransfer(context: Context): Result<Unit> =
    recoverPendingNetworkWork(
        context.getSharedPreferences(STUDY_PREFERENCES_NAME, Context.MODE_PRIVATE),
        AndroidKeystoreAppTokenStore(context.applicationContext)
    )

private suspend fun recoverPendingNetworkWork(
    preferences: SharedPreferences,
    appTokenStore: AppTokenStore
): Result<Unit> =
    runCatching {
        val compensationCode = preferences.getString(KEY_COMPENSATION_CODE, null)
        val studyCompleted = preferences.getBoolean(KEY_STUDY_COMPLETED, false)
        if (!compensationCode.isNullOrBlank() && !studyCompleted) {
            CravingSubmissionClient.confirmCompensation(compensationCode)
            preferences.edit()
                .putBoolean(KEY_STUDY_COMPLETED, true)
                .putInt(KEY_CONFIRMED_SITUATION_COUNT, TOTAL_SITUATION_COUNT)
                .remove(KEY_PENDING_SUBMISSION_CRAVING)
                .apply()
            return@runCatching
        }

        val activeToken = appTokenStore.getAppToken()
            ?: throw IllegalStateException("Missing app token")

        val pendingCraving = preferences.getInt(KEY_PENDING_SUBMISSION_CRAVING, NO_PENDING_CRAVING)
        if (pendingCraving == NO_PENDING_CRAVING) {
            return@runCatching
        }

        when (val response = CravingSubmissionClient.submitSelfReport(
            appToken = activeToken,
            craving = pendingCraving
        )) {
            is SelfReportResponse.Next -> {
                advanceAfterConfirmedSubmission(preferences)
            }
            is SelfReportResponse.Complete -> {
                preferences.edit()
                    .putString(KEY_COMPENSATION_CODE, response.compensationCode)
                    .remove(KEY_PENDING_SUBMISSION_CRAVING)
                    .apply()
                CravingSubmissionClient.confirmCompensation(response.compensationCode)
                preferences.edit()
                    .putBoolean(KEY_STUDY_COMPLETED, true)
                    .putInt(KEY_CONFIRMED_SITUATION_COUNT, TOTAL_SITUATION_COUNT)
                    .apply()
            }
        }
    }.onFailure {
        Log.w(TAG, "Pending network work could not be completed", it)
    }

private fun advanceAfterConfirmedSubmission(preferences: SharedPreferences) {
    val nextCompletedSituationCount = (preferences.getInt(KEY_CONFIRMED_SITUATION_COUNT, 0) + 1)
        .coerceAtMost(TOTAL_SITUATION_COUNT)
    val nextRunAt = System.currentTimeMillis() + BuildConfig.RUN_COOLDOWN_MILLIS
    preferences.edit()
        .putInt(KEY_CONFIRMED_SITUATION_COUNT, nextCompletedSituationCount)
        .putLong(KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS, nextRunAt)
        .remove(KEY_PENDING_SUBMISSION_CRAVING)
        .apply()
}

private fun hasPendingNetworkWork(preferences: SharedPreferences): Boolean {
    val compensationCode = preferences.getString(KEY_COMPENSATION_CODE, null)
    return preferences.getInt(KEY_PENDING_SUBMISSION_CRAVING, NO_PENDING_CRAVING) != NO_PENDING_CRAVING ||
        (!compensationCode.isNullOrBlank() && !preferences.getBoolean(KEY_STUDY_COMPLETED, false))
}

private object CravingSubmissionClient {
    suspend fun submitSelfReport(appToken: String, craving: Int): SelfReportResponse {
        val response = putJson(
            ServerRequest.SelfReportSubmission,
            JSONObject()
                .put("app_token", appToken)
                .put("craving", craving)
                .put("app_version", BuildConfig.VERSION_NAME)
        )
        val status = response.optString("status")
        return try {
            if (status == "complete") {
                SelfReportResponse.Complete(response.getString("compensation_code"))
            } else {
                SelfReportResponse.Next
            }
        } catch (e: JSONException) {
            logServerRequestError(
                ServerRequest.SelfReportSubmission,
                serverErrorMessage = "Unexpected JSON response shape",
                cause = e
            )
            throw e
        }
    }

    suspend fun confirmCompensation(compensationCode: String) {
        putJsonNoContent(
            ServerRequest.CompensationConfirmation,
            JSONObject().put("compensation_code", compensationCode)
        )
    }

    private suspend fun putJson(request: ServerRequest, payload: JSONObject): JSONObject = withContext(Dispatchers.IO) {
        val response = executePut(request, payload, expectedNoContent = false)
        try {
            JSONObject(response ?: "{}")
        } catch (e: JSONException) {
            logServerRequestError(request, serverErrorMessage = "Invalid JSON response", cause = e)
            throw e
        }
    }

    private suspend fun putJsonNoContent(request: ServerRequest, payload: JSONObject) {
        withContext(Dispatchers.IO) {
            executePut(request, payload, expectedNoContent = true)
        }
    }

    private fun executePut(request: ServerRequest, payload: JSONObject, expectedNoContent: Boolean): String? {
        val body = payload.toString().toByteArray(Charsets.UTF_8)
        val connection = URL(request.url).openConnection() as HttpURLConnection
        var responseCode: Int? = null
        var serverErrorMessage: String? = null
        try {
            connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
            connection.readTimeout = NETWORK_TIMEOUT_MILLIS
            writeJsonPutRequest(connection, body)

            responseCode = connection.responseCode
            if (expectedNoContent) {
                if (responseCode != HttpURLConnection.HTTP_NO_CONTENT) {
                    serverErrorMessage = readServerErrorMessage(connection)
                    throw IOException("Unexpected HTTP status $responseCode")
                }
                return null
            }
            if (responseCode !in 200..299) {
                serverErrorMessage = readServerErrorMessage(connection)
                throw IOException("Unexpected HTTP status $responseCode")
            }
            return connection.inputStream.bufferedReader(Charsets.UTF_8).use { reader ->
                reader.readText()
            }
        } catch (e: IOException) {
            logServerRequestError(request, responseCode, serverErrorMessage, e)
            throw e
        } finally {
            connection.disconnect()
        }
    }

    private fun readServerErrorMessage(connection: HttpURLConnection): String? {
        val errorBody = connection.errorStream?.bufferedReader(Charsets.UTF_8)?.use { reader ->
            reader.readText()
        } ?: return null

        return try {
            JSONObject(errorBody).optString("error").takeIf { it.isNotBlank() }
        } catch (_: JSONException) {
            null
        }
    }

    private fun logServerRequestError(
        request: ServerRequest,
        statusCode: Int? = null,
        serverErrorMessage: String? = null,
        cause: Throwable
    ) {
        val details = buildList {
            add("request=${request.logName}")
            if (statusCode != null) {
                add("status=$statusCode")
            }
            if (!serverErrorMessage.isNullOrBlank()) {
                add("server_error=$serverErrorMessage")
            }
        }.joinToString(", ")
        Log.w(TAG, "Server request failed: $details", cause)
    }
}

internal fun writeJsonPutRequest(connection: HttpURLConnection, body: ByteArray) {
    connection.requestMethod = "PUT"
    connection.doOutput = true
    connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
    connection.setRequestProperty("Accept", "application/json, */*;q=0.8")
    connection.setRequestProperty("Accept-Charset", "UTF-8, *;q=0.5")
    connection.setRequestProperty("Accept-Language", "de, en;q=0.8, *;q=0.5")
    connection.setRequestProperty("Accept-Encoding", "identity")
    connection.setRequestProperty("User-Agent", "CueLens-Android")
    connection.setRequestProperty("Content-Length", body.size.toString())
    connection.setFixedLengthStreamingMode(body.size)
    connection.outputStream.use { output -> output.write(body) }
}

private enum class ServerRequest(val logName: String, val url: String) {
    SelfReportSubmission("self_report_submission", BuildConfig.CRAVING_SUBMIT_URL),
    CompensationConfirmation("compensation_confirmation", BuildConfig.CRAVING_SUBMIT_URL)
}

private enum class Phase {
    StartGate,
    ImageMatching,
    WordMatching,
    CravingSubmission
}

private data class ImageMatchItem(
    @param:DrawableRes val cueResId: Int,
    @param:DrawableRes val matchAResId: Int,
    @param:DrawableRes val matchBResId: Int
)

private data class WordMatchItem(
    @param:DrawableRes val cueResId: Int,
    val germanWordA: String,
    val germanWordB: String,
    val englishWordA: String,
    val englishWordB: String
) {
    fun wordA(language: AppLanguage): String =
        if (language == AppLanguage.English) englishWordA else germanWordA

    fun wordB(language: AppLanguage): String =
        if (language == AppLanguage.English) englishWordB else germanWordB
}

private sealed interface SelfReportResponse {
    data object Next : SelfReportResponse
    data class Complete(val compensationCode: String) : SelfReportResponse
}

private data class CueLabelMapping(
    val cueName: String,
    val germanFittingLabel: String,
    val germanLessFittingLabel: String,
    val englishFittingLabel: String,
    val englishLessFittingLabel: String
)

// Draft translations require fachliche review before the production toggle is enabled.
private val cueLabelMappings = listOf(
    CueLabelMapping("cue_000", "Rauchschleier", "Abendlicht", "smoke haze", "evening light"),
    CueLabelMapping("cue_001", "Aschegeruch", "Regenschirmmoment", "smell of ash", "umbrella moment"),
    CueLabelMapping("cue_002", "Kaffee dazu", "Handy in der Hand", "coffee with it", "phone in hand"),
    CueLabelMapping("cue_003", "nachglimmen", "Tischrunde", "smoldering", "around the table"),
    CueLabelMapping("cue_004", "ausdrücken", "Nachtluft", "stubbing it out", "night air"),
    CueLabelMapping("cue_005", "abaschen", "Packung öffnen", "tapping off ash", "opening the pack"),
    CueLabelMapping("cue_006", "Zigarette nehmen", "Rauchkringel", "taking a cigarette", "smoke ring"),
    CueLabelMapping("cue_007", "Packung klopfen", "Fensterpause", "tapping the pack", "window break"),
    CueLabelMapping("cue_008", "Zigarette nehmen", "gemeinsam draußen", "taking a cigarette", "outside together"),
    CueLabelMapping("cue_009", "Stadtluft", "Balkonmoment", "city air", "balcony moment"),
    CueLabelMapping("cue_010", "Packungsrascheln", "Rauchschleier", "pack rustling", "smoke haze"),
    CueLabelMapping("cue_011", "Wegbegleiter", "Tischrunde", "companion", "around the table"),
    CueLabelMapping("cue_012", "Feuer suchen", "Wolke", "looking for a light", "cloud"),
    CueLabelMapping("cue_013", "Klick", "Geselligkeit", "click", "company"),
    CueLabelMapping("cue_014", "Haltestellenpause", "Glutmoment", "bus-stop break", "glowing moment"),
    CueLabelMapping("cue_015", "Papiergeschmack", "Hofpause", "taste of paper", "courtyard break"),
    CueLabelMapping("cue_016", "Gewohnheitsgriff", "Kneipenluft", "habitual reach", "pub air"),
    CueLabelMapping("cue_017", "Fingergefühl", "Feuerzeugklick", "feeling in the fingers", "lighter click"),
    CueLabelMapping("cue_018", "Aufglimmen", "gemeinsam draußen", "lighting up", "outside together"),
    CueLabelMapping("cue_019", "Tischrunde", "Filtergeschmack", "around the table", "taste of the filter"),
    CueLabelMapping("cue_020", "Gesprächspause", "erster Zug", "pause in conversation", "first drag"),
    CueLabelMapping("cue_021", "Nachtluft", "verbrannter Geruch", "night air", "burnt smell"),
    CueLabelMapping("cue_022", "rauchige Luft", "Kaffee dazu", "smoky air", "coffee with it"),
    CueLabelMapping("cue_023", "Tischrunde", "Glutpunkt", "around the table", "glowing tip"),
    CueLabelMapping("cue_024", "Gewohnheitsgriff", "trockener Tabak", "habitual reach", "dry tobacco"),
    CueLabelMapping("cue_025", "Dazugehören", "Filter an den Lippen", "belonging", "filter on the lips"),
    CueLabelMapping("cue_026", "gemeinsam draußen", "Papiergeschmack", "outside together", "taste of paper"),
    CueLabelMapping("cue_027", "Flamme", "Asche abstreifen", "flame", "brushing off ash"),
    CueLabelMapping("cue_028", "leiser Moment", "Mundzug", "quiet moment", "draw in the mouth"),
    CueLabelMapping("cue_029", "Wartezeit", "herber Duft", "waiting time", "tart scent"),
    CueLabelMapping("cue_030", "kleine Ruhe", "Feuerzeugklick", "brief calm", "lighter click"),
    CueLabelMapping("cue_031", "Jetzt eine", "Mundzug", "one right now", "draw in the mouth"),
    CueLabelMapping("cue_032", "Nachtluft", "Filtergeschmack", "night air", "taste of the filter"),
    CueLabelMapping("cue_033", "Anzündmoment", "Stadtluft", "lighting moment", "city air"),
    CueLabelMapping("cue_034", "Fensterpause", "Flamme", "window break", "flame"),
    CueLabelMapping("cue_035", "Schreibtischpause", "Regenschirmmoment", "desk break", "umbrella moment"),
    CueLabelMapping("cue_036", "Halskratzen", "Balkonmoment", "scratchy throat", "balcony moment"),
    CueLabelMapping("cue_037", "runterkommen", "Knistern", "winding down", "crackling"),
    CueLabelMapping("cue_038", "dichter Zug", "Packung klopfen", "dense drag", "tapping the pack"),
    CueLabelMapping("cue_039", "Feierabendzug", "Folie öffnen", "after-work drag", "opening the foil"),
    CueLabelMapping("cue_040", "vertrauter Moment", "Flamme", "familiar moment", "flame"),
    CueLabelMapping("cue_041", "draußen stehen", "Schreibtischpause", "standing outside", "desk break"),
    CueLabelMapping("cue_042", "Haltestellenpause", "würziges Aroma", "bus-stop break", "spicy aroma"),
    CueLabelMapping("cue_043", "vor die Tür", "Nachgeschmack", "stepping outside", "aftertaste"),
    CueLabelMapping("cue_044", "ziehen", "Dazugehören", "taking a drag", "belonging"),
    CueLabelMapping("cue_045", "nur kurz", "Feierabendzug", "just briefly", "after-work drag"),
    CueLabelMapping("cue_046", "Automatismus", "Aschegeruch", "automatic habit", "smell of ash"),
    CueLabelMapping("cue_047", "Lust auf Zug", "Knistern", "wanting a drag", "crackling"),
    CueLabelMapping("cue_048", "Feierabendzug", "Tabakduft", "after-work drag", "tobacco scent"),
    CueLabelMapping("cue_049", "Rauchkringel", "Aufglimmen", "smoke ring", "lighting up")
)

private const val TAG = "CueLens"
private const val NETWORK_TIMEOUT_MILLIS = 15_000
private const val TRIALS_PER_SITUATION = 5
private const val MATCHING_SITUATION_COUNT = 10
private const val LABELING_SITUATION_COUNT = 10
private const val TOTAL_SITUATION_COUNT = MATCHING_SITUATION_COUNT + LABELING_SITUATION_COUNT
private const val IMAGE_MATCH_WAIT_SECONDS = 4

private val StudyBackground = Color(0xFFD7ECE9)
private val StudyPrimary = Color(0xFF006269)
