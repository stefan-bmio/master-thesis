package me.stefanberger.ai_poc.ml

import android.content.Context

object ImageModelBackendFactory {
    fun create(context: Context, spec: ModelSpec): ImageModelBackend {
        return when (spec.backend) {
            BackendType.ML_KIT_BASELINE -> MlKitBaselineBackend(spec)
            BackendType.LITERT_CLASSIFIER -> LiteRtClassifierBackend(context, spec)
        }
    }
}
