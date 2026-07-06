package me.stefanberger.ai_poc.ml

import android.graphics.Bitmap
import android.os.SystemClock
import com.google.android.gms.tasks.Task
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabel
import com.google.mlkit.vision.label.ImageLabeler
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

class MlKitBaselineBackend(
    private val spec: ModelSpec
) : ImageModelBackend {
    override val modelId: String = spec.id

    private val labeler: ImageLabeler = ImageLabeling.getClient(
        ImageLabelerOptions.Builder()
            .setConfidenceThreshold(spec.threshold)
            .build()
    )

    override suspend fun classify(bitmap: Bitmap): ModelPrediction {
        val startNs = SystemClock.elapsedRealtimeNanos()
        val labels = labeler.process(InputImage.fromBitmap(bitmap, 0)).await()
        val latencyMs = (SystemClock.elapsedRealtimeNanos() - startNs) / 1_000_000L

        val scores = AiLabels.emptyScores()
        labels.forEach { imageLabel ->
            mappedLabel(imageLabel.text)?.let { target ->
                scores[target] = maxOf(scores.getValue(target), imageLabel.confidence)
            }
        }

        val predictedLabel = labels.firstNotNullOfOrNull { imageLabel ->
            mappedLabel(imageLabel.text)?.takeIf { imageLabel.confidence >= spec.threshold }
        } ?: "negative"

        if (predictedLabel == "negative") {
            scores["negative"] = 1f
        }

        return ModelPrediction(
            modelId = modelId,
            predictedLabel = predictedLabel,
            scores = scores,
            latencyMs = latencyMs
        )
    }

    override fun close() {
        labeler.close()
    }

    private fun mappedLabel(label: String): String? {
        val normalized = label.lowercase().trim()
        return keywordMap.entries.firstOrNull { (keyword, _) ->
            normalized.contains(keyword)
        }?.value
    }

    private suspend fun Task<List<ImageLabel>>.await(): List<ImageLabel> {
        return suspendCancellableCoroutine { continuation ->
            addOnSuccessListener { continuation.resume(it) }
            addOnFailureListener { continuation.resumeWithException(it) }
            addOnCanceledListener { continuation.cancel() }
        }
    }

    private companion object {
        private val keywordMap = linkedMapOf(
            "ashtray" to "ashtray",
            "cigarette" to "cigarette",
            "cigar" to "cigarette",
            "tobacco" to "cigarette pack",
            "smoking" to "people smoking",
            "smoke" to "smoke"
        )
    }
}
