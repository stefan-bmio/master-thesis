package me.stefanberger.ai_poc.ml

import android.graphics.Bitmap

interface ImageModelBackend : AutoCloseable {
    val modelId: String
    suspend fun classify(bitmap: Bitmap): ModelPrediction
}
