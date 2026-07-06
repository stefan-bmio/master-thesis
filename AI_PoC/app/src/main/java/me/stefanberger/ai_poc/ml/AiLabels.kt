package me.stefanberger.ai_poc.ml

import android.content.Context

object AiLabels {
    val canonical: List<String> = listOf(
        "ashtray",
        "cigarette",
        "cigarette pack",
        "people smoking",
        "smoke",
        "negative"
    )

    val technicalToCanonical: Map<String, String> = mapOf(
        "ashtray" to "ashtray",
        "cigarette" to "cigarette",
        "cigarette_pack" to "cigarette pack",
        "people_smoking" to "people smoking",
        "smoke" to "smoke",
        "negative" to "negative"
    )

    val canonicalToTechnical: Map<String, String> = technicalToCanonical.entries.associate { (technical, canonical) ->
        canonical to technical
    }

    fun load(context: Context, assetPath: String): List<String> {
        val labels = context.assets.open(assetPath).bufferedReader().useLines { lines ->
            lines.map { it.trim() }.filter { it.isNotEmpty() }.toList()
        }
        require(labels == canonical) {
            "Unexpected label order in $assetPath: $labels"
        }
        return labels
    }

    fun emptyScores(): MutableMap<String, Float> = canonical.associateWith { 0f }.toMutableMap()

    fun scoreColumn(label: String): String = "score_${label.replace(" ", "_")}"
}
