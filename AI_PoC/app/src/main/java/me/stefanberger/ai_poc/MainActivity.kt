package me.stefanberger.ai_poc

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import me.stefanberger.ai_poc.ui.theme.AIPoCTheme
import org.tensorflow.lite.Interpreter
import java.io.Closeable
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel
import java.util.Locale
import kotlin.math.sqrt

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AIPoCTheme {
                SmokeClassifierScreen()
            }
        }
    }
}

@Composable
private fun SmokeClassifierScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val classifierResult = remember { runCatching { SmokeClassifier(context.applicationContext) } }
    val classifier = classifierResult.getOrNull()

    var selectedUri by remember { mutableStateOf<Uri?>(null) }
    var isClassifying by remember { mutableStateOf(false) }
    var status by remember {
        mutableStateOf(
            classifierResult.exceptionOrNull()?.let { "Could not load MobileCLIP: ${it.message}" }
                ?: "Pick a 256x256 image to classify."
        )
    }
    var classification by remember { mutableStateOf<Classification?>(null) }

    DisposableEffect(classifier) {
        onDispose { classifier?.close() }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null || classifier == null) return@rememberLauncherForActivityResult

        selectedUri = uri
        classification = null
        isClassifying = true
        status = "Classifying..."
        runCatching {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }

        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching { classifier.classify(uri) }
            }
            result.onSuccess {
                classification = it
                status = "Done."
            }.onFailure {
                status = it.message ?: "Classification failed."
            }
            isClassifying = false
        }
    }

    Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text(
                text = "MobileCLIP S2 Smoke Classifier",
                style = MaterialTheme.typography.headlineSmall
            )
            Text(
                text = "Prototype input: RGB JPEG/PNG/WebP, exactly 256 x 256 px, upright. This does not resize, crop, rotate, or correct EXIF orientation."
            )
            Button(
                enabled = classifier != null && !isClassifying,
                onClick = { picker.launch(arrayOf("image/*")) }
            ) {
                Text("Open image")
            }

            selectedUri?.let { Text("Selected: $it") }
            if (isClassifying) CircularProgressIndicator()
            Text(status)

            classification?.let { result ->
                Text(
                    text = "Prediction: ${result.label} (${result.score.formatScore()})",
                    style = MaterialTheme.typography.titleMedium
                )
                result.scores.forEach { score ->
                    Text("${score.label}: ${score.score.formatScore()}")
                }
            }
        }
    }
}

private class SmokeClassifier(context: Context) : Closeable {
    private val interpreter = Interpreter(
        loadModel(context),
        Interpreter.Options().setNumThreads(2)
    )
    private val contentResolver = context.contentResolver

    fun classify(uri: Uri): Classification {
        val imageInput = imageInput(uri)
        val scores = prompts.map { prompt ->
            val output0 = Array(1) { FloatArray(embeddingSize) }
            val output1 = Array(1) { FloatArray(embeddingSize) }
            val outputs = mutableMapOf<Int, Any>(
                0 to output0,
                1 to output1
            )

            imageInput.rewind()
            interpreter.runForMultipleInputsOutputs(
                arrayOf(imageInput, arrayOf(prompt.tokens)),
                outputs
            )

            LabelScore(prompt.label, cosine(output0[0], output1[0]))
        }.sortedByDescending { it.score }

        val top = scores.first()
        return Classification(top.label, top.score, scores)
    }

    private fun imageInput(uri: Uri): ByteBuffer {
        val bitmap = contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream)
        } ?: error("Could not decode the selected image.")

        if (bitmap.width != imageSize || bitmap.height != imageSize) {
            val message = "Image must already be ${imageSize}x$imageSize px. Selected image is ${bitmap.width}x${bitmap.height} px."
            bitmap.recycle()
            error(message)
        }

        val pixels = IntArray(imageSize * imageSize)
        bitmap.getPixels(pixels, 0, imageSize, 0, 0, imageSize, imageSize)
        bitmap.recycle()

        val input = ByteBuffer
            .allocateDirect(imageSize * imageSize * channels * floatBytes)
            .order(ByteOrder.nativeOrder())

        for (channel in 0 until channels) {
            for (pixel in pixels) {
                val value = when (channel) {
                    0 -> (pixel shr 16) and 0xff
                    1 -> (pixel shr 8) and 0xff
                    else -> pixel and 0xff
                } / 255f
                input.putFloat((value - clipMean[channel]) / clipStd[channel])
            }
        }

        input.rewind()
        return input
    }

    override fun close() {
        interpreter.close()
    }

    private companion object {
        private const val modelName = "mobileclip_s2_datacompdr_last.tflite"
        private const val imageSize = 256
        private const val channels = 3
        private const val embeddingSize = 512
        private const val textLength = 77
        private const val floatBytes = 4
        private val clipMean = floatArrayOf(0.48145466f, 0.4578275f, 0.40821073f)
        private val clipStd = floatArrayOf(0.26862954f, 0.26130258f, 0.27577711f)

        private val prompts = listOf(
            Prompt("cigarette", tokens(49406, 320, 1125, 539, 320, 18548, 49407)),
            Prompt("smoke", tokens(49406, 320, 1125, 539, 18548, 6664, 49407)),
            Prompt("pack of cigarettes", tokens(49406, 320, 1125, 539, 320, 3420, 539, 22750, 49407)),
            Prompt("full ashtray", tokens(49406, 320, 1125, 539, 320, 1476, 2067, 14621, 49407)),
            Prompt("person smoking", tokens(49406, 320, 1125, 539, 320, 2533, 9038, 320, 18548, 49407)),
            Prompt("group of people smoking", tokens(49406, 320, 1125, 539, 320, 1771, 539, 1047, 9038, 22750, 49407)),
            Prompt("none of the other", tokens(49406, 320, 1125, 38644, 531, 22750, 541, 9038, 49407))
        )

        private fun loadModel(context: Context): MappedByteBuffer {
            context.assets.openFd(modelName).use { fileDescriptor ->
                FileInputStream(fileDescriptor.fileDescriptor).channel.use { channel ->
                    return channel.map(
                        FileChannel.MapMode.READ_ONLY,
                        fileDescriptor.startOffset,
                        fileDescriptor.declaredLength
                    )
                }
            }
        }

        private fun tokens(vararg ids: Int): LongArray {
            return LongArray(textLength).also { output ->
                ids.forEachIndexed { index, id -> output[index] = id.toLong() }
            }
        }

        private fun cosine(a: FloatArray, b: FloatArray): Float {
            var dot = 0.0
            var normA = 0.0
            var normB = 0.0

            for (index in a.indices) {
                val av = a[index].toDouble()
                val bv = b[index].toDouble()
                dot += av * bv
                normA += av * av
                normB += bv * bv
            }

            return if (normA == 0.0 || normB == 0.0) {
                0f
            } else {
                (dot / sqrt(normA * normB)).toFloat()
            }
        }
    }
}

private data class Prompt(
    val label: String,
    val tokens: LongArray
)

private data class Classification(
    val label: String,
    val score: Float,
    val scores: List<LabelScore>
)

private data class LabelScore(
    val label: String,
    val score: Float
)

private fun Float.formatScore(): String = String.format(Locale.US, "%.3f", this)
