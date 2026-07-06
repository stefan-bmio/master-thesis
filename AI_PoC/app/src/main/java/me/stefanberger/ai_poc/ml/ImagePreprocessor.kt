package me.stefanberger.ai_poc.ml

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import org.tensorflow.lite.DataType
import org.tensorflow.lite.Tensor
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.roundToInt

object ImagePreprocessor {
    fun decodeBitmapFromUri(context: Context, uri: Uri): Bitmap {
        val bitmap = context.contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream)
        } ?: error("Could not decode selected image.")

        val orientation = context.contentResolver.openInputStream(uri)?.use { stream ->
            ExifInterface(stream).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )
        } ?: ExifInterface.ORIENTATION_NORMAL

        return applyExifOrientation(bitmap, orientation)
    }

    fun decodeBitmapFromAsset(context: Context, assetPath: String): Bitmap {
        return context.assets.open(assetPath).use { stream ->
            BitmapFactory.decodeStream(stream)
        } ?: error("Could not decode benchmark asset: $assetPath")
    }

    fun toInputBuffer(bitmap: Bitmap, width: Int, height: Int, inputTensor: Tensor): ByteBuffer {
        val dataType = inputTensor.dataType()
        val bytesPerValue = when (dataType) {
            DataType.FLOAT32 -> 4
            DataType.INT8, DataType.UINT8 -> 1
            else -> error("Unsupported input tensor type: $dataType")
        }

        val resized = centerCropResize(bitmap, width, height)
        val pixels = IntArray(width * height)
        resized.getPixels(pixels, 0, width, 0, 0, width, height)
        if (resized !== bitmap) {
            resized.recycle()
        }

        val buffer = ByteBuffer
            .allocateDirect(width * height * 3 * bytesPerValue)
            .order(ByteOrder.nativeOrder())
        val quantization = inputTensor.quantizationParams()

        for (pixel in pixels) {
            putValue(buffer, dataType, ((pixel shr 16) and 0xff).toFloat(), quantization)
            putValue(buffer, dataType, ((pixel shr 8) and 0xff).toFloat(), quantization)
            putValue(buffer, dataType, (pixel and 0xff).toFloat(), quantization)
        }
        buffer.rewind()
        return buffer
    }

    fun centerCropResize(bitmap: Bitmap, width: Int, height: Int): Bitmap {
        val cropSize = minOf(bitmap.width, bitmap.height)
        val left = (bitmap.width - cropSize) / 2
        val top = (bitmap.height - cropSize) / 2
        val cropped = Bitmap.createBitmap(bitmap, left, top, cropSize, cropSize)
        val resized = Bitmap.createScaledBitmap(cropped, width, height, true)
        if (cropped !== bitmap && cropped !== resized) {
            cropped.recycle()
        }
        return resized
    }

    private fun putValue(
        buffer: ByteBuffer,
        dataType: DataType,
        value: Float,
        quantization: Tensor.QuantizationParams
    ) {
        when (dataType) {
            DataType.FLOAT32 -> buffer.putFloat(value)
            DataType.INT8 -> {
                val scale = quantization.scale.takeIf { it > 0f } ?: 1f
                val quantized = (value / scale + quantization.zeroPoint).roundToInt().coerceIn(-128, 127)
                buffer.put(quantized.toByte())
            }
            DataType.UINT8 -> {
                val scale = quantization.scale.takeIf { it > 0f } ?: 1f
                val quantized = (value / scale + quantization.zeroPoint).roundToInt().coerceIn(0, 255)
                buffer.put(quantized.toByte())
            }
            else -> error("Unsupported input tensor type: $dataType")
        }
    }

    private fun applyExifOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.preScale(-1f, 1f)
                matrix.postRotate(90f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.preScale(-1f, 1f)
                matrix.postRotate(270f)
            }
            else -> return bitmap
        }

        val transformed = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        bitmap.recycle()
        return transformed
    }
}
