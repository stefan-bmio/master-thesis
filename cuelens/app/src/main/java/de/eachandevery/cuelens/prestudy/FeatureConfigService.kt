package de.eachandevery.cuelens.prestudy

import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

fun interface FeatureConfigService {
    suspend fun nextStudyRunEnabled(): Boolean
}

class HttpFeatureConfigService(
    private val endpointUrl: String,
    private val connectionFactory: (URL) -> HttpURLConnection = {
        it.openConnection() as HttpURLConnection
    }
) : FeatureConfigService {
    override suspend fun nextStudyRunEnabled(): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            val connection = connectionFactory(URL(endpointUrl))
            try {
                connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
                connection.readTimeout = NETWORK_TIMEOUT_MILLIS
                connection.requestMethod = "GET"
                connection.setRequestProperty("Accept", "application/json")
                if (connection.responseCode != HttpURLConnection.HTTP_OK) return@runCatching false
                val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use {
                    it.readText()
                }
                val features = JSONObject(response).getJSONObject("features")
                if (!features.has("next_study_run_enabled") ||
                    features.get("next_study_run_enabled") !is Boolean
                ) {
                    return@runCatching false
                }
                features.getBoolean("next_study_run_enabled")
            } finally {
                connection.disconnect()
            }
        }.getOrDefault(false)
    }

    private companion object {
        const val NETWORK_TIMEOUT_MILLIS = 15_000
    }
}
