package me.stefanberger.ai_poc.benchmark

import android.content.Context
import android.os.Environment
import me.stefanberger.ai_poc.ml.AiLabels
import java.io.File
import java.util.Locale

data class CsvExportResult(
    val predictionCsv: File,
    val metricCsv: File
)

object CsvExporter {
    fun export(context: Context, result: BenchmarkRunResult): CsvExportResult {
        val directory = context.getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
            ?: File(context.filesDir, "benchmarks")
        directory.mkdirs()

        val predictionFile = File(directory, "cuelens_predictions_${result.runId}.csv")
        val metricFile = File(directory, "cuelens_metrics_${result.runId}.csv")

        predictionFile.writeText(predictionCsv(result.predictions), Charsets.UTF_8)
        metricFile.writeText(metricCsv(result.metrics), Charsets.UTF_8)

        return CsvExportResult(predictionCsv = predictionFile, metricCsv = metricFile)
    }

    private fun predictionCsv(rows: List<BenchmarkPredictionRow>): String {
        val scoreHeaders = AiLabels.canonical.map(AiLabels::scoreColumn)
        val headers = listOf(
            "run_id",
            "device_manufacturer",
            "device_model",
            "android_version",
            "model_id",
            "image_path",
            "true_label",
            "predicted_label"
        ) + scoreHeaders + listOf("latency_ms", "correct")

        return buildString {
            appendLine(headers.joinToString(","))
            rows.forEach { row ->
                val values = listOf(
                    row.runId,
                    row.deviceManufacturer,
                    row.deviceModel,
                    row.androidVersion,
                    row.modelId,
                    row.imagePath,
                    row.trueLabel,
                    row.predictedLabel
                ) + AiLabels.canonical.map { label ->
                    format(row.scores[label]?.toDouble())
                } + listOf(
                    row.latencyMs.toString(),
                    row.correct.toString()
                )
                appendLine(values.joinToString(",") { escape(it) })
            }
        }
    }

    private fun metricCsv(rows: List<MetricRow>): String {
        val headers = listOf(
            "run_id",
            "model_id",
            "metric_scope",
            "label",
            "tp",
            "fp",
            "tn",
            "fn",
            "sensitivity",
            "specificity",
            "precision",
            "f1",
            "accuracy",
            "mean_latency_ms",
            "p95_latency_ms",
            "n"
        )

        return buildString {
            appendLine(headers.joinToString(","))
            rows.forEach { row ->
                val values = listOf(
                    row.runId,
                    row.modelId,
                    row.metricScope,
                    row.label,
                    row.matrix.tp.toString(),
                    row.matrix.fp.toString(),
                    row.matrix.tn.toString(),
                    row.matrix.fn.toString(),
                    format(row.sensitivity),
                    format(row.specificity),
                    format(row.precision),
                    format(row.f1),
                    format(row.accuracy),
                    format(row.meanLatencyMs),
                    format(row.p95LatencyMs),
                    row.n.toString()
                )
                appendLine(values.joinToString(",") { escape(it) })
            }
        }
    }

    private fun escape(value: String): String {
        return if (value.any { it == ',' || it == '"' || it == '\n' }) {
            "\"" + value.replace("\"", "\"\"") + "\""
        } else {
            value
        }
    }

    private fun format(value: Double?): String {
        return value?.let { String.format(Locale.US, "%.6f", it) } ?: ""
    }
}
