package me.stefanberger.ai_poc.ml

data class ModelSpec(
    val id: String,
    val backend: BackendType,
    val assetModelPath: String? = null,
    val inputWidth: Int = 224,
    val inputHeight: Int = 224,
    val labelsAssetPath: String = "labels.txt",
    val threshold: Float = 0.5f,
    val numThreads: Int = 2
)

enum class BackendType {
    ML_KIT_BASELINE,
    LITERT_CLASSIFIER
}

object Models {
    val ML_KIT_IMAGE_LABELING_BASELINE = ModelSpec(
        id = "mlkit_image_labeling_baseline",
        backend = BackendType.ML_KIT_BASELINE,
        threshold = 0.5f
    )

    val MOBILE_NET_V3_SMALL_INT8 = ModelSpec(
        id = "mobilenetv3small_transfer_int8",
        backend = BackendType.LITERT_CLASSIFIER,
        assetModelPath = "models/mobilenetv3small_cuelens_int8.tflite",
        threshold = 0.5f
    )

    val MOBILE_NET_V3_SMALL_FLOAT32 = ModelSpec(
        id = "mobilenetv3small_transfer_float32",
        backend = BackendType.LITERT_CLASSIFIER,
        assetModelPath = "models/mobilenetv3small_cuelens_float32.tflite",
        threshold = 0.5f
    )

    val EFFICIENT_NET_LITE0_INT8 = ModelSpec(
        id = "efficientnet_lite0_transfer_int8",
        backend = BackendType.LITERT_CLASSIFIER,
        assetModelPath = "models/efficientnet_lite0_cuelens_int8.tflite",
        threshold = 0.5f
    )

    val EFFICIENT_NET_LITE0_FLOAT32 = ModelSpec(
        id = "efficientnet_lite0_transfer_float32",
        backend = BackendType.LITERT_CLASSIFIER,
        assetModelPath = "models/efficientnet_lite0_cuelens_float32.tflite",
        threshold = 0.5f
    )
}

object AiModelConfig {
    val activeModel: ModelSpec = Models.MOBILE_NET_V3_SMALL_FLOAT32
    // val activeModel: ModelSpec = Models.MOBILE_NET_V3_SMALL_INT8
    // val activeModel: ModelSpec = Models.EFFICIENT_NET_LITE0_FLOAT32
    // val activeModel: ModelSpec = Models.EFFICIENT_NET_LITE0_INT8
    // val activeModel: ModelSpec = Models.ML_KIT_IMAGE_LABELING_BASELINE

    val benchmarkModels: List<ModelSpec> = listOf(
        Models.ML_KIT_IMAGE_LABELING_BASELINE,
        Models.MOBILE_NET_V3_SMALL_FLOAT32,
        Models.MOBILE_NET_V3_SMALL_INT8,
        Models.EFFICIENT_NET_LITE0_FLOAT32,
        Models.EFFICIENT_NET_LITE0_INT8
    )
}
