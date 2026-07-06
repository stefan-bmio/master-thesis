package me.stefanberger.ai_poc.benchmark

data class ConfusionMatrix(
    val tp: Int,
    val fp: Int,
    val tn: Int,
    val fn: Int
) {
    val n: Int = tp + fp + tn + fn
}
