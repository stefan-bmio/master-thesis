package me.stefanberger.ai_poc.benchmark

import android.content.Context
import android.os.Build
import me.stefanberger.ai_poc.BuildConfig
import me.stefanberger.ai_poc.ml.AiLabels
import me.stefanberger.ai_poc.ml.ImageModelBackendFactory
import me.stefanberger.ai_poc.ml.ImagePreprocessor
import me.stefanberger.ai_poc.ml.ModelSpec
import java.time.Instant
import java.time.format.DateTimeFormatter

data class BenchmarkPredictionRow(
    val runId: String,
    val deviceManufacturer: String,
    val deviceModel: String,
    val androidVersion: String,
    val modelId: String,
    val imagePath: String,
    val trueLabel: String,
    val predictedLabel: String,
    val scores: Map<String, Float>,
    val latencyMs: Long,
    val correct: Boolean
)

data class BenchmarkRunResult(
    val runId: String,
    val predictions: List<BenchmarkPredictionRow>,
    val metrics: List<MetricRow>
) {
    val modelCount: Int = predictions.map { it.modelId }.distinct().size
    val imageCount: Int = predictions.map { it.imagePath }.distinct().size
}

class BenchmarkRunner(private val context: Context) {
    suspend fun run(models: List<ModelSpec>): BenchmarkRunResult {
        check(BuildConfig.FLAVOR == "benchmark") {
            "Benchmark assets are only available in the benchmark flavor."
        }

        val appContext = context.applicationContext
        val manifest = BenchmarkManifest.load(appContext)
        val runId = DateTimeFormatter.ISO_INSTANT.format(Instant.now()).replace(":", "-")
        val rows = mutableListOf<BenchmarkPredictionRow>()

        models.forEach { spec ->
            ImageModelBackendFactory.create(appContext, spec).use { backend ->
                manifest.firstOrNull()?.let { first ->
                    val warmupBitmap = ImagePreprocessor.decodeBitmapFromAsset(appContext, first.assetPath)
                    runCatching { backend.classify(warmupBitmap) }
                    warmupBitmap.recycle()
                }

                manifest.forEach { item ->
                    val bitmap = ImagePreprocessor.decodeBitmapFromAsset(appContext, item.assetPath)
                    val prediction = backend.classify(bitmap)
                    bitmap.recycle()
                    rows += BenchmarkPredictionRow(
                        runId = runId,
                        deviceManufacturer = Build.MANUFACTURER,
                        deviceModel = Build.MODEL,
                        androidVersion = Build.VERSION.RELEASE ?: Build.VERSION.SDK_INT.toString(),
                        modelId = prediction.modelId,
                        imagePath = item.assetPath,
                        trueLabel = item.label,
                        predictedLabel = prediction.predictedLabel,
                        scores = AiLabels.canonical.associateWith { label -> prediction.scores[label] ?: 0f },
                        latencyMs = prediction.latencyMs,
                        correct = item.label == prediction.predictedLabel
                    )
                }
            }
        }

        return BenchmarkRunResult(
            runId = runId,
            predictions = rows,
            metrics = Metrics.aggregate(runId, rows)
        )
    }
}
