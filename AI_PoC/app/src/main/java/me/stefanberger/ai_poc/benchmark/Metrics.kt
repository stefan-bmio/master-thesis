package me.stefanberger.ai_poc.benchmark

import me.stefanberger.ai_poc.ml.AiLabels

data class MetricRow(
    val runId: String,
    val modelId: String,
    val metricScope: String,
    val label: String,
    val matrix: ConfusionMatrix,
    val sensitivity: Double?,
    val specificity: Double?,
    val precision: Double?,
    val f1: Double?,
    val accuracy: Double?,
    val meanLatencyMs: Double,
    val p95LatencyMs: Double,
    val n: Int
)

object Metrics {
    private val positiveLabels = setOf("ashtray", "cigarette", "cigarette pack", "people smoking", "smoke")

    fun aggregate(runId: String, rows: List<BenchmarkPredictionRow>): List<MetricRow> {
        return rows.groupBy { it.modelId }.flatMap { (modelId, modelRows) ->
            val multiclass = AiLabels.canonical.map { label ->
                val matrix = oneVsRest(modelRows, label)
                metricRow(runId, modelId, "multiclass_one_vs_rest", label, matrix, modelRows)
            }
            val binary = binaryMatrix(modelRows)
            multiclass + metricRow(runId, modelId, "binary_smoking_cue", "smoking_cue", binary, modelRows)
        }
    }

    private fun oneVsRest(rows: List<BenchmarkPredictionRow>, label: String): ConfusionMatrix {
        var tp = 0
        var fp = 0
        var tn = 0
        var fn = 0

        rows.forEach { row ->
            val actual = row.trueLabel == label
            val predicted = row.predictedLabel == label
            when {
                actual && predicted -> tp += 1
                actual && !predicted -> fn += 1
                !actual && predicted -> fp += 1
                else -> tn += 1
            }
        }

        return ConfusionMatrix(tp = tp, fp = fp, tn = tn, fn = fn)
    }

    private fun binaryMatrix(rows: List<BenchmarkPredictionRow>): ConfusionMatrix {
        var tp = 0
        var fp = 0
        var tn = 0
        var fn = 0

        rows.forEach { row ->
            val actual = row.trueLabel in positiveLabels
            val predicted = row.predictedLabel in positiveLabels
            when {
                actual && predicted -> tp += 1
                actual && !predicted -> fn += 1
                !actual && predicted -> fp += 1
                else -> tn += 1
            }
        }

        return ConfusionMatrix(tp = tp, fp = fp, tn = tn, fn = fn)
    }

    private fun metricRow(
        runId: String,
        modelId: String,
        metricScope: String,
        label: String,
        matrix: ConfusionMatrix,
        rows: List<BenchmarkPredictionRow>
    ): MetricRow {
        val precision = divide(matrix.tp, matrix.tp + matrix.fp)
        val sensitivity = divide(matrix.tp, matrix.tp + matrix.fn)
        val f1 = if (precision != null && sensitivity != null && precision + sensitivity > 0.0) {
            2.0 * precision * sensitivity / (precision + sensitivity)
        } else {
            null
        }
        val latencies = rows.map { it.latencyMs }.sorted()

        return MetricRow(
            runId = runId,
            modelId = modelId,
            metricScope = metricScope,
            label = label,
            matrix = matrix,
            sensitivity = sensitivity,
            specificity = divide(matrix.tn, matrix.tn + matrix.fp),
            precision = precision,
            f1 = f1,
            accuracy = divide(matrix.tp + matrix.tn, matrix.n),
            meanLatencyMs = latencies.average(),
            p95LatencyMs = percentile(latencies, 0.95),
            n = rows.size
        )
    }

    private fun divide(numerator: Int, denominator: Int): Double? {
        return if (denominator == 0) null else numerator.toDouble() / denominator.toDouble()
    }

    private fun percentile(values: List<Long>, quantile: Double): Double {
        if (values.isEmpty()) return Double.NaN
        val index = ((values.size - 1) * quantile).toInt().coerceIn(values.indices)
        return values[index].toDouble()
    }
}
