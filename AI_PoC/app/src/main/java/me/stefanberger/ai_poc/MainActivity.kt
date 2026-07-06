package me.stefanberger.ai_poc

import android.content.Intent
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
import me.stefanberger.ai_poc.benchmark.BenchmarkRunResult
import me.stefanberger.ai_poc.benchmark.BenchmarkRunner
import me.stefanberger.ai_poc.benchmark.CsvExporter
import me.stefanberger.ai_poc.ml.AiLabels
import me.stefanberger.ai_poc.ml.AiModelConfig
import me.stefanberger.ai_poc.ml.ImageModelBackendFactory
import me.stefanberger.ai_poc.ml.ImagePreprocessor
import me.stefanberger.ai_poc.ml.ModelPrediction
import me.stefanberger.ai_poc.ui.theme.AIPoCTheme
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AIPoCTheme {
                CueLensClassifierScreen()
            }
        }
    }
}

@Composable
private fun CueLensClassifierScreen() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val backendResult = remember {
        runCatching {
            ImageModelBackendFactory.create(context.applicationContext, AiModelConfig.activeModel)
        }
    }
    val backend = backendResult.getOrNull()

    var selectedUri by remember { mutableStateOf<Uri?>(null) }
    var isBusy by remember { mutableStateOf(false) }
    var status by remember {
        mutableStateOf(
            backendResult.exceptionOrNull()?.message
                ?: "Active model: ${AiModelConfig.activeModel.id}"
        )
    }
    var prediction by remember { mutableStateOf<ModelPrediction?>(null) }
    var benchmarkResult by remember { mutableStateOf<BenchmarkRunResult?>(null) }

    DisposableEffect(backend) {
        onDispose { backend?.close() }
    }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null || backend == null) return@rememberLauncherForActivityResult
        selectedUri = uri
        prediction = null
        benchmarkResult = null
        isBusy = true
        status = "Classifying..."
        runCatching {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }

        scope.launch {
            val result = withContext(Dispatchers.IO) {
                runCatching {
                    val bitmap = ImagePreprocessor.decodeBitmapFromUri(context, uri)
                    try {
                        backend.classify(bitmap)
                    } finally {
                        bitmap.recycle()
                    }
                }
            }
            result.onSuccess {
                prediction = it
                status = "Done."
            }.onFailure {
                status = it.message ?: "Classification failed."
            }
            isBusy = false
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
                text = "CueLens Image Classifier",
                style = MaterialTheme.typography.headlineSmall
            )
            Text(text = status)
            Button(
                enabled = backend != null && !isBusy,
                onClick = { picker.launch(arrayOf("image/*")) }
            ) {
                Text("Open image")
            }

            selectedUri?.let { Text("Selected: $it") }
            if (isBusy) CircularProgressIndicator()

            prediction?.let { result ->
                Text(
                    text = "Prediction: ${result.predictedLabel} (${result.modelId}, ${result.latencyMs} ms)",
                    style = MaterialTheme.typography.titleMedium
                )
                AiLabels.canonical.forEach { label ->
                    Text("${label}: ${result.scores[label].orZero().formatScore()}")
                }
            }

            if (BuildConfig.FLAVOR == "benchmark") {
                BenchmarkControls(
                    isBusy = isBusy,
                    result = benchmarkResult,
                    onRunActive = {
                        isBusy = true
                        status = "Benchmark running..."
                        scope.launch {
                            val result = withContext(Dispatchers.IO) {
                                runCatching {
                                    BenchmarkRunner(context).run(listOf(AiModelConfig.activeModel))
                                }
                            }
                            result.onSuccess {
                                benchmarkResult = it
                                status = "Benchmark done: ${it.predictions.size} predictions."
                            }.onFailure {
                                status = it.message ?: "Benchmark failed."
                            }
                            isBusy = false
                        }
                    },
                    onRunAll = {
                        isBusy = true
                        status = "Benchmark running..."
                        scope.launch {
                            val result = withContext(Dispatchers.IO) {
                                runCatching {
                                    BenchmarkRunner(context).run(AiModelConfig.benchmarkModels)
                                }
                            }
                            result.onSuccess {
                                benchmarkResult = it
                                status = "Benchmark done: ${it.predictions.size} predictions."
                            }.onFailure {
                                status = it.message ?: "Benchmark failed."
                            }
                            isBusy = false
                        }
                    },
                    onExport = export@{
                        val current = benchmarkResult ?: return@export
                        val export = CsvExporter.export(context, current)
                        status = "CSV exported: ${export.predictionCsv.name}, ${export.metricCsv.name}"
                    }
                )
            }
        }
    }
}

@Composable
private fun BenchmarkControls(
    isBusy: Boolean,
    result: BenchmarkRunResult?,
    onRunActive: () -> Unit,
    onRunAll: () -> Unit,
    onExport: () -> Unit
) {
    Button(enabled = !isBusy, onClick = onRunActive) {
        Text("Run active model")
    }
    Button(enabled = !isBusy, onClick = onRunAll) {
        Text("Run all benchmark models")
    }
    Button(enabled = !isBusy && result != null, onClick = onExport) {
        Text("Export CSV")
    }
    result?.let {
        Text("Run: ${it.runId}")
        Text("Images: ${it.imageCount}; models: ${it.modelCount}")
        it.metrics.firstOrNull { metric -> metric.metricScope == "binary_smoking_cue" }?.let { metric ->
            Text("Binary sensitivity: ${metric.sensitivity.formatScore()}")
            Text("Binary specificity: ${metric.specificity.formatScore()}")
            Text("Mean latency: ${metric.meanLatencyMs.formatScore()} ms")
        }
    }
}

private fun Float?.orZero(): Float = this ?: 0f

private fun Float.formatScore(): String = String.format(Locale.US, "%.3f", this)

private fun Double?.formatScore(): String = this?.let { String.format(Locale.US, "%.3f", it) } ?: "n/a"
