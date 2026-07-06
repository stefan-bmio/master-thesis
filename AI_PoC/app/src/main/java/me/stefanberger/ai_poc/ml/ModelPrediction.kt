package me.stefanberger.ai_poc.ml

data class ModelPrediction(
    val modelId: String,
    val predictedLabel: String,
    val scores: Map<String, Float>,
    val latencyMs: Long
)
