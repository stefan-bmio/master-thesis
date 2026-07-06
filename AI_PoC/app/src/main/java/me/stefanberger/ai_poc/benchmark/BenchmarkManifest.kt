package me.stefanberger.ai_poc.benchmark

import android.content.Context
import org.json.JSONArray

data class BenchmarkImage(
    val assetPath: String,
    val label: String,
    val technicalLabel: String,
    val sha256: String?
)

object BenchmarkManifest {
    fun load(context: Context, assetPath: String = "eval_manifest.json"): List<BenchmarkImage> {
        val json = context.assets.open(assetPath).bufferedReader().use { it.readText() }
        val array = JSONArray(json)
        return List(array.length()) { index ->
            val item = array.getJSONObject(index)
            BenchmarkImage(
                assetPath = item.getString("asset_path"),
                label = item.getString("label"),
                technicalLabel = item.optString("technical_label"),
                sha256 = item.optString("sha256").takeIf { it.isNotBlank() }
            )
        }
    }
}
