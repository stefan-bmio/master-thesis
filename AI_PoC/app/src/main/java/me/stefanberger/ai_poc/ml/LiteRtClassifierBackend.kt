package me.stefanberger.ai_poc.ml

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Interpreter
import org.tensorflow.lite.Tensor
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

class LiteRtClassifierBackend(
    context: Context,
    private val spec: ModelSpec
) : ImageModelBackend {
    override val modelId: String = spec.id

    private val appContext = context.applicationContext
    private val labels: List<String> = AiLabels.load(appContext, spec.labelsAssetPath)
    private val interpreter = Interpreter(
        loadModel(appContext, requireNotNull(spec.assetModelPath) { "Missing model asset path for ${spec.id}" }),
        Interpreter.Options()
            .setNumThreads(spec.numThreads)
            .setUseXNNPACK(false)
    )

    override suspend fun classify(bitmap: Bitmap): ModelPrediction {
        val startNs = SystemClock.elapsedRealtimeNanos()
        val input = ImagePreprocessor.toInputBuffer(
            bitmap = bitmap,
            width = spec.inputWidth,
            height = spec.inputHeight,
            inputTensor = interpreter.getInputTensor(0)
        )
        val scores = runInference(input)
        val latencyMs = (SystemClock.elapsedRealtimeNanos() - startNs) / 1_000_000L
        val topIndex = scores.indices.maxBy { scores[it] }
        val predictedLabel = labels[topIndex]

        return ModelPrediction(
            modelId = modelId,
            predictedLabel = predictedLabel,
            scores = labels.zip(scores.asIterable()).toMap(),
            latencyMs = latencyMs
        )
    }

    override fun close() {
        interpreter.close()
    }

    private fun runInference(input: ByteBuffer): FloatArray {
        val outputTensor = interpreter.getOutputTensor(0)
        val outputCount = labels.size
        val outputBuffer = ByteBuffer
            .allocateDirect(outputCount * bytesPerValue(outputTensor.dataType()))
            .order(ByteOrder.nativeOrder())
        interpreter.run(input, outputBuffer)
        outputBuffer.rewind()
        return readScores(outputBuffer, outputTensor, outputCount)
    }

    private fun readScores(buffer: ByteBuffer, tensor: Tensor, outputCount: Int): FloatArray {
        val quantization = tensor.quantizationParams()
        return FloatArray(outputCount) {
            when (tensor.dataType()) {
                DataType.FLOAT32 -> buffer.float
                DataType.INT8 -> {
                    val raw = buffer.get().toInt()
                    (raw - quantization.zeroPoint) * quantization.scale
                }
                DataType.UINT8 -> {
                    val raw = buffer.get().toInt() and 0xff
                    (raw - quantization.zeroPoint) * quantization.scale
                }
                else -> error("Unsupported output tensor type: ${tensor.dataType()}")
            }
        }
    }

    private fun bytesPerValue(dataType: DataType): Int {
        return when (dataType) {
            DataType.FLOAT32 -> 4
            DataType.INT8, DataType.UINT8 -> 1
            else -> error("Unsupported tensor type: $dataType")
        }
    }

    private fun loadModel(context: Context, assetPath: String): MappedByteBuffer {
        context.assets.openFd(assetPath).use { fileDescriptor ->
            FileInputStream(fileDescriptor.fileDescriptor).channel.use { channel ->
                return channel.map(
                    FileChannel.MapMode.READ_ONLY,
                    fileDescriptor.startOffset,
                    fileDescriptor.declaredLength
                )
            }
        }
    }
}
