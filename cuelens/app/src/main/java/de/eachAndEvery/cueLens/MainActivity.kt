package de.eachAndEvery.cueLens

import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import de.eachAndEvery.cueLens.ui.theme.CueLensTheme
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
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
    var phase by remember {
        mutableStateOf(
            when {
                imageItems.isNotEmpty() -> Phase.ImageMatching
                wordItems.isNotEmpty() -> Phase.WordMatching
                else -> Phase.CravingSubmission
            }
        )
    }
    var itemIndex by remember { mutableIntStateOf(0) }

    val advance = {
        when (phase) {
            Phase.ImageMatching -> {
                if (itemIndex + 1 < imageItems.size) {
                    itemIndex += 1
                } else {
                    phase = Phase.WordMatching
                    itemIndex = 0
                }
            }
            Phase.WordMatching -> {
                if (itemIndex + 1 < wordItems.size) {
                    itemIndex += 1
                } else {
                    phase = Phase.CravingSubmission
                    itemIndex = 0
                }
            }
            Phase.CravingSubmission -> Unit
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        when (phase) {
            Phase.ImageMatching -> {
                val item = imageItems.getOrNull(itemIndex)
                if (item != null) {
                    ImageMatchScreen(item = item, onChoiceTapped = advance)
                }
            }
            Phase.WordMatching -> {
                val item = wordItems.getOrNull(itemIndex)
                if (item != null) {
                    WordMatchScreen(item = item, onChoiceTapped = advance)
                }
            }
            Phase.CravingSubmission -> CravingSubmissionScreen()
        }
    }
}

@Composable
private fun ImageMatchScreen(item: ImageMatchItem, onChoiceTapped: () -> Unit) {
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
            MatchImage(resId = item.matchAResId, onClick = onChoiceTapped)
            Spacer(modifier = Modifier.width(24.dp))
            MatchImage(resId = item.matchBResId, onClick = onChoiceTapped)
        }
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
private fun MatchImage(@DrawableRes resId: Int, onClick: () -> Unit) {
    Image(
        painter = painterResource(id = resId),
        contentDescription = null,
        modifier = Modifier
            .fillMaxHeight()
            .width(140.dp)
            .clickable(onClick = onClick),
        contentScale = ContentScale.Fit
    )
}

@Composable
private fun CravingSubmissionScreen() {
    val coroutineScope = rememberCoroutineScope()
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
                coroutineScope.launch {
                    submitCraving(craving)
                }
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
