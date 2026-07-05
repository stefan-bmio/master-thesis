package de.eachAndEvery.cueLens

import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
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
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.shape.CircleShape
import de.eachAndEvery.cueLens.ui.theme.CueLensTheme
import java.io.IOException
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.random.Random
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CueLensTheme {
                CueLensApp()
            }
        }
    }
}

@Composable
private fun CueLensApp() {
    val context = LocalContext.current
    val imageItems = remember { loadImageMatchItems(context) }
    val wordItems = remember { loadWordMatchItems(context) }
    val coroutineScope = rememberCoroutineScope()
    val preferences = remember { context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE) }
    var phase by remember { mutableStateOf(Phase.StartGate) }
    var itemIndex by remember { mutableIntStateOf(0) }
    var currentImageItems by remember { mutableStateOf(emptyList<ImageMatchItem>()) }
    var currentWordItems by remember { mutableStateOf(emptyList<WordMatchItem>()) }
    var completedSituationCount by remember {
        mutableIntStateOf(
            preferences.getInt(
                KEY_CONFIRMED_SITUATION_COUNT,
                preferences.getInt(LEGACY_KEY_COMPLETED_SITUATION_COUNT, 0)
            )
        )
    }
    var nextRunAvailableAtMillis by remember {
        mutableStateOf(
            preferences.getLong(
                KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS,
                preferences.getLong(LEGACY_KEY_NEXT_RUN_AVAILABLE_AT_MILLIS, 0L)
            )
        )
    }
    var matchingOrder by remember {
        mutableStateOf(loadMatchingOrder(preferences, imageItems.size))
    }
    var appToken by remember { mutableStateOf(preferences.getString(KEY_APP_TOKEN, null)) }
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
        completedSituationCount = preferences.getInt(
            KEY_CONFIRMED_SITUATION_COUNT,
            preferences.getInt(LEGACY_KEY_COMPLETED_SITUATION_COUNT, 0)
        )
        nextRunAvailableAtMillis = preferences.getLong(
            KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS,
            preferences.getLong(LEGACY_KEY_NEXT_RUN_AVAILABLE_AT_MILLIS, 0L)
        )
        appToken = preferences.getString(KEY_APP_TOKEN, null)
        pendingSubmissionCraving = preferences.getInt(KEY_PENDING_SUBMISSION_CRAVING, NO_PENDING_CRAVING)
        compensationCode = preferences.getString(KEY_COMPENSATION_CODE, null)
        studyCompleted = preferences.getBoolean(KEY_STUDY_COMPLETED, false)
    }

    val syncPendingWork = {
        coroutineScope.launch {
            syncInProgress = true
            syncMessage = null
            val result = recoverPendingNetworkWork(preferences)
            refreshPersistedState()
            syncInProgress = false
            if (result.isFailure) {
                syncMessage = "Die Datenübertragung ist fehlgeschlagen. Bitte versuchen Sie es erneut."
            }
        }
        Unit
    }

    LaunchedEffect(Unit) {
        if (hasPendingNetworkWork(preferences)) {
            syncInProgress = true
            syncMessage = null
            val result = recoverPendingNetworkWork(preferences)
            refreshPersistedState()
            syncInProgress = false
            if (result.isFailure) {
                syncMessage = "Die Datenübertragung ist fehlgeschlagen. Bitte versuchen Sie es erneut."
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
            preferences.getInt(LEGACY_KEY_COMPLETED_SITUATION_COUNT, completedSituationCount)
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

    val hasActivation = !appToken.isNullOrBlank()
    val networkWorkPending = pendingSubmissionCraving != NO_PENDING_CRAVING ||
        (!compensationCode.isNullOrBlank() && !studyCompleted)
    val canStartNow = hasActivation && !networkWorkPending && !syncInProgress && !studyCompleted

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        if (!hasActivation && !studyCompleted) {
            ActivationScreen(
                syncInProgress = syncInProgress,
                message = syncMessage,
                onActivate = { email ->
                    coroutineScope.launch {
                        syncInProgress = true
                        syncMessage = null
                        val result = activateAndConfirm(preferences, email)
                        refreshPersistedState()
                        syncInProgress = false
                        if (result.isFailure) {
                            syncMessage = "Die Aktivierung ist fehlgeschlagen. Bitte prüfen Sie die E-Mail-Adresse und versuchen Sie es erneut."
                        }
                    }
                }
            )
        } else when (phase) {
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
                    WordMatchScreen(item = item, onChoiceTapped = advance)
                }
            }
            Phase.CravingSubmission -> CravingSubmissionScreen(onSubmit = finishRun)
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
                studyComplete -> "Studie abgeschlossen"
                networkWorkPending || syncInProgress -> "Datenübertragung ausstehend"
                canStartSituation -> "Durchgang $nextSituationNumber von $TOTAL_SITUATION_COUNT"
                else -> "Cue Labeling noch unvollständig"
            },
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(12.dp))
        if (studyComplete && !compensationCode.isNullOrBlank()) {
            Text(
                text = "Aufwandsentschädigungscode:",
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
                    "Bitte schließen Sie die Übertragung ab."
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
                onClick = onRetrySync
            ) {
                Text(text = if (syncInProgress) "Übertragung läuft" else "Erneut versuchen")
            }
        } else if (!studyComplete) {
            Button(
                enabled = startEnabled,
                onClick = onStartRun
            ) {
                Text(text = "Durchgang starten")
            }
        }
    }
}

@Composable
private fun ActivationScreen(
    syncInProgress: Boolean,
    message: String?,
    onActivate: (String) -> Unit
) {
    var email by remember { mutableStateOf("") }
    val trimmedEmail = email.trim()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "App aktivieren",
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(16.dp))
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            enabled = !syncInProgress,
            singleLine = true,
            label = { Text("E-Mail-Adresse") },
            modifier = Modifier.fillMaxWidth()
        )
        if (!message.isNullOrBlank()) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center
            )
        }
        Spacer(modifier = Modifier.height(24.dp))
        Button(
            enabled = !syncInProgress && trimmedEmail.isNotBlank(),
            onClick = { onActivate(trimmedEmail) }
        ) {
            Text(text = if (syncInProgress) "Aktivierung läuft" else "Aktivieren")
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
                modifier = Modifier.width(64.dp),
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
private fun WordMatchScreen(item: WordMatchItem, onChoiceTapped: () -> Unit) {
    val choices = remember(item.cueResId, item.wordA, item.wordB) {
        if (Random.nextBoolean()) {
            listOf(item.wordA, item.wordB)
        } else {
            listOf(item.wordB, item.wordA)
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
            Button(onClick = onChoiceTapped) {
                Text(text = choices[0])
            }
            Spacer(modifier = Modifier.width(24.dp))
            Button(onClick = onChoiceTapped) {
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
private fun CravingSubmissionScreen(onSubmit: (Int) -> Unit) {
    var craving by remember { mutableIntStateOf(50) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Wie hoch ist in diesem Moment Ihr Rauchverlangen?",
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
            }
        ) {
            Text(text = "Absenden")
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
            WordMatchItem(cue, mapping.germanFittingLabel, mapping.germanLessFittingLabel)
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

private suspend fun activateAndConfirm(preferences: SharedPreferences, email: String): Result<Unit> =
    runCatching {
        val activation = CravingSubmissionClient.activate(email)
        preferences.edit()
            .putString(KEY_APP_TOKEN, activation.appToken)
            .putInt(KEY_CONFIRMED_SITUATION_COUNT, 0)
            .remove(KEY_STUDY_COMPLETED)
            .remove(KEY_COMPENSATION_CODE)
            .apply()
        recoverPendingNetworkWork(preferences).getOrThrow()
    }.onFailure {
        Log.w(TAG, "Activation failed", it)
    }

private suspend fun recoverPendingNetworkWork(preferences: SharedPreferences): Result<Unit> =
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

        val appToken = preferences.getString(KEY_APP_TOKEN, null)
        val activeToken = appToken
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
    val nextRunAt = System.currentTimeMillis() + RUN_COOLDOWN_MILLIS
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
    suspend fun activate(email: String): ActivationResponse {
        val response = putJson(
            ServerRequest.Activation,
            JSONObject().put("email", email)
        )
        return try {
            ActivationResponse(
                appToken = response.getString("app_token")
            )
        } catch (e: JSONException) {
            logServerRequestError(
                ServerRequest.Activation,
                serverErrorMessage = "Unexpected JSON response shape",
                cause = e
            )
            throw e
        }
    }

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
        val body = payload.toString()
        val connection = URL(request.url).openConnection() as HttpURLConnection
        var responseCode: Int? = null
        var serverErrorMessage: String? = null
        try {
            connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
            connection.readTimeout = NETWORK_TIMEOUT_MILLIS
            connection.requestMethod = "PUT"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Content-Length", body.toByteArray(Charsets.UTF_8).size.toString())
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(body)
            }

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

private enum class ServerRequest(val logName: String, val url: String) {
    Activation("activation", BuildConfig.ACTIVATION_URL),
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
    val wordA: String,
    val wordB: String
)

private data class ActivationResponse(
    val appToken: String
)

private sealed interface SelfReportResponse {
    data object Next : SelfReportResponse
    data class Complete(val compensationCode: String) : SelfReportResponse
}

private data class CueLabelMapping(
    val cueName: String,
    val germanFittingLabel: String,
    val germanLessFittingLabel: String,
    val englishFittingLabel: String? = null,
    val englishLessFittingLabel: String? = null
)

private val cueLabelMappings = listOf(
    CueLabelMapping("cue_000", "Rauchschleier", "Abendlicht"),
    CueLabelMapping("cue_001", "Aschegeruch", "Regenschirmmoment"),
    CueLabelMapping("cue_002", "Kaffee dazu", "Handy in der Hand"),
    CueLabelMapping("cue_003", "nachglimmen", "Tischrunde"),
    CueLabelMapping("cue_004", "ausdrücken", "Nachtluft"),
    CueLabelMapping("cue_005", "abaschen", "Packung öffnen"),
    CueLabelMapping("cue_006", "Zigarette nehmen", "Rauchkringel"),
    CueLabelMapping("cue_007", "Packung klopfen", "Fensterpause"),
    CueLabelMapping("cue_008", "Zigarette nehmen", "gemeinsam draußen"),
    CueLabelMapping("cue_009", "Stadtluft", "Balkonmoment"),
    CueLabelMapping("cue_010", "Packungsrascheln", "Rauchschleier"),
    CueLabelMapping("cue_011", "Wegbegleiter", "Tischrunde"),
    CueLabelMapping("cue_012", "Feuer suchen", "Wolke"),
    CueLabelMapping("cue_013", "Klick", "Geselligkeit"),
    CueLabelMapping("cue_014", "Haltestellenpause", "Glutmoment"),
    CueLabelMapping("cue_015", "Papiergeschmack", "Hofpause"),
    CueLabelMapping("cue_016", "Gewohnheitsgriff", "Kneipenluft"),
    CueLabelMapping("cue_017", "Fingergefühl", "Feuerzeugklick"),
    CueLabelMapping("cue_018", "Aufglimmen", "gemeinsam draußen"),
    CueLabelMapping("cue_019", "Tischrunde", "Filtergeschmack"),
    CueLabelMapping("cue_020", "Gesprächspause", "erster Zug"),
    CueLabelMapping("cue_021", "Nachtluft", "verbrannter Geruch"),
    CueLabelMapping("cue_022", "rauchige Luft", "Kaffee dazu"),
    CueLabelMapping("cue_023", "Tischrunde", "Glutpunkt"),
    CueLabelMapping("cue_024", "Gewohnheitsgriff", "trockener Tabak"),
    CueLabelMapping("cue_025", "Dazugehören", "Filter an den Lippen"),
    CueLabelMapping("cue_026", "gemeinsam draußen", "Papiergeschmack"),
    CueLabelMapping("cue_027", "Flamme", "Asche abstreifen"),
    CueLabelMapping("cue_028", "leiser Moment", "Mundzug"),
    CueLabelMapping("cue_029", "Wartezeit", "herber Duft"),
    CueLabelMapping("cue_030", "kleine Ruhe", "Feuerzeugklick"),
    CueLabelMapping("cue_031", "Jetzt eine", "Mundzug"),
    CueLabelMapping("cue_032", "Nachtluft", "Filtergeschmack"),
    CueLabelMapping("cue_033", "Anzündmoment", "Stadtluft"),
    CueLabelMapping("cue_034", "Fensterpause", "Flamme"),
    CueLabelMapping("cue_035", "Schreibtischpause", "Regenschirmmoment"),
    CueLabelMapping("cue_036", "Halskratzen", "Balkonmoment"),
    CueLabelMapping("cue_037", "runterkommen", "Knistern"),
    CueLabelMapping("cue_038", "dichter Zug", "Packung klopfen"),
    CueLabelMapping("cue_039", "Feierabendzug", "Folie öffnen"),
    CueLabelMapping("cue_040", "vertrauter Moment", "Flamme"),
    CueLabelMapping("cue_041", "draußen stehen", "Schreibtischpause"),
    CueLabelMapping("cue_042", "Haltestellenpause", "würziges Aroma"),
    CueLabelMapping("cue_043", "vor die Tür", "Nachgeschmack"),
    CueLabelMapping("cue_044", "ziehen", "Dazugehören"),
    CueLabelMapping("cue_045", "nur kurz", "Feierabendzug"),
    CueLabelMapping("cue_046", "Automatismus", "Aschegeruch"),
    CueLabelMapping("cue_047", "Lust auf Zug", "Knistern"),
    CueLabelMapping("cue_048", "Feierabendzug", "Tabakduft"),
    CueLabelMapping("cue_049", "Rauchkringel", "Aufglimmen")
)

private const val TAG = "CueLens"
private const val PREFERENCES_NAME = "cue_lens_state"
private const val KEY_CONFIRMED_SITUATION_COUNT = "confirmed_situation_count"
private const val KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS = "next_situation_available_at_millis"
private const val KEY_MATCHING_ORDER = "matching_order"
private const val KEY_APP_TOKEN = "app_token"
private const val KEY_PENDING_SUBMISSION_CRAVING = "pending_submission_craving"
private const val KEY_COMPENSATION_CODE = "compensation_code"
private const val KEY_STUDY_COMPLETED = "study_completed"
private const val LEGACY_KEY_NEXT_RUN_AVAILABLE_AT_MILLIS = "next_run_available_at_millis"
private const val LEGACY_KEY_COMPLETED_SITUATION_COUNT = "completed_situation_count"
private const val NO_PENDING_CRAVING = -1
private const val NETWORK_TIMEOUT_MILLIS = 15_000
private const val TRIALS_PER_SITUATION = 5
private const val MATCHING_SITUATION_COUNT = 10
private const val LABELING_SITUATION_COUNT = 10
private const val TOTAL_SITUATION_COUNT = MATCHING_SITUATION_COUNT + LABELING_SITUATION_COUNT
//private const val IMAGE_MATCH_WAIT_SECONDS = 4
private const val IMAGE_MATCH_WAIT_SECONDS = 1
//private const val RUN_COOLDOWN_MILLIS = 3L * 60L * 60L * 1000L
private const val RUN_COOLDOWN_MILLIS = 3L
