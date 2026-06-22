package de.eachAndEvery.cueLens

import android.content.Context
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
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.random.Random
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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
        mutableIntStateOf(preferences.getInt(KEY_COMPLETED_SITUATION_COUNT, 0))
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

    val getMatchingOrder = {
        matchingOrder.ifEmpty {
            val generatedOrder = imageItems.indices.shuffled()
            saveMatchingOrder(preferences, generatedOrder)
            matchingOrder = generatedOrder
            generatedOrder
        }
    }

    val startRun = {
        val situationIndex = completedSituationCount
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
        val nextRunAt = System.currentTimeMillis() + RUN_COOLDOWN_MILLIS
        val nextCompletedSituationCount = (completedSituationCount + 1).coerceAtMost(TOTAL_SITUATION_COUNT)
        preferences.edit()
            .putInt(KEY_COMPLETED_SITUATION_COUNT, nextCompletedSituationCount)
            .putLong(KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS, nextRunAt)
            .apply()
        completedSituationCount = nextCompletedSituationCount
        nextRunAvailableAtMillis = nextRunAt
        itemIndex = 0
        currentImageItems = emptyList()
        currentWordItems = emptyList()
        phase = Phase.StartGate
        coroutineScope.launch {
            submitCraving(craving)
        }
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

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        when (phase) {
            Phase.StartGate -> StartGateScreen(
                nextRunAvailableAtMillis = nextRunAvailableAtMillis,
                completedSituationCount = completedSituationCount,
                canStartSituation = canStartSituation(
                    completedSituationCount = completedSituationCount,
                    imageItemCount = imageItems.size,
                    wordItemCount = wordItems.size
                ),
                onStartRun = startRun
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
    canStartSituation: Boolean,
    onStartRun: () -> Unit
) {
    var nowMillis by remember { mutableStateOf(System.currentTimeMillis()) }
    val remainingMillis = max(0L, nextRunAvailableAtMillis - nowMillis)
    val studyComplete = completedSituationCount >= TOTAL_SITUATION_COUNT
    val startEnabled = remainingMillis == 0L && canStartSituation && !studyComplete
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
                canStartSituation -> "Durchgang $nextSituationNumber von $TOTAL_SITUATION_COUNT"
                else -> "Cue Labeling noch unvollständig"
            },
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(12.dp))
        Text(
            text = formatDuration(remainingMillis),
            style = MaterialTheme.typography.headlineMedium,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(24.dp))
        Button(
            enabled = startEnabled,
            onClick = onStartRun
        ) {
            Text(text = "Durchgang starten")
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
                Text(text = item.wordA)
            }
            Spacer(modifier = Modifier.width(24.dp))
            Button(onClick = onChoiceTapped) {
                Text(text = item.wordB)
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
    val wordChoices = mapOf(
        100 to WordChoices("Paff", "Klick")
    )
    val items = mutableListOf<WordMatchItem>()
    var index = 100
    while (true) {
        val cue = context.drawableId("cue_$index")
        val choices = wordChoices[index]
        if (cue == 0 || choices == null) break
        items += WordMatchItem(cue, choices.wordA, choices.wordB)
        index += 1
    }
    return items
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

private fun loadMatchingOrder(preferences: android.content.SharedPreferences, imageItemCount: Int): List<Int> {
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

private fun saveMatchingOrder(preferences: android.content.SharedPreferences, order: List<Int>) {
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

private suspend fun submitCraving(craving: Int) {
    withContext(Dispatchers.IO) {
        val body = "craving=${URLEncoder.encode(craving.toString(), Charsets.UTF_8.name())}"
        val connection = URL("https://cuelens.each-and-every.de/submit").openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.setRequestProperty("Content-Length", body.toByteArray().size.toString())
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(body)
            }
            Log.i(TAG, "submitCraving response: ${connection.responseCode} ${connection.responseMessage}")
            connection.inputStream.close()
        } catch (_: Exception) {
            // MVP behavior: ignore request failures and keep the slider visible.
        } finally {
            connection.disconnect()
        }
    }
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

private data class WordChoices(
    val wordA: String,
    val wordB: String
)

private const val TAG = "CueLens"
private const val PREFERENCES_NAME = "cue_lens_state"
private const val KEY_COMPLETED_SITUATION_COUNT = "completed_situation_count"
private const val KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS = "next_situation_available_at_millis"
private const val KEY_MATCHING_ORDER = "matching_order"
private const val LEGACY_KEY_NEXT_RUN_AVAILABLE_AT_MILLIS = "next_run_available_at_millis"
private const val TRIALS_PER_SITUATION = 5
private const val MATCHING_SITUATION_COUNT = 10
private const val LABELING_SITUATION_COUNT = 10
private const val TOTAL_SITUATION_COUNT = MATCHING_SITUATION_COUNT + LABELING_SITUATION_COUNT
private const val IMAGE_MATCH_WAIT_SECONDS = 4
private const val RUN_COOLDOWN_MILLIS = 3L * 60L * 60L * 1000L
