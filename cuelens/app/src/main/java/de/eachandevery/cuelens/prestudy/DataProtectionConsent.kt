package de.eachandevery.cuelens.prestudy

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.preferencesDataStore
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject

private val Context.dataProtectionDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "data_protection"
)

interface DataProtectionConsentStore {
    suspend fun isAccepted(): Boolean

    suspend fun markAccepted()
}

class DataStoreDataProtectionConsentStore(
    private val dataStore: DataStore<Preferences>
) : DataProtectionConsentStore {
    constructor(context: Context) : this(context.dataProtectionDataStore)

    override suspend fun isAccepted(): Boolean = dataStore.data
        .catch { cause ->
            if (cause is IOException) emit(emptyPreferences()) else throw cause
        }
        .first()[DATAPROT] ?: false

    override suspend fun markAccepted() {
        dataStore.edit { preferences ->
            preferences[DATAPROT] = true
        }
    }

    private companion object {
        val DATAPROT = booleanPreferencesKey("DATAPROT")
    }
}

interface DataProtectionService {
    suspend fun getStatus(appToken: String): Boolean

    suspend fun accept(appToken: String): Boolean
}

class HttpDataProtectionService(
    private val endpointUrl: String,
    private val connectionFactory: (URL) -> HttpURLConnection = {
        it.openConnection() as HttpURLConnection
    }
) : DataProtectionService {
    override suspend fun getStatus(appToken: String): Boolean =
        execute(
            method = "POST",
            requestBody = JSONObject().put("app_token", appToken).toString()
        )

    override suspend fun accept(appToken: String): Boolean =
        execute(
            method = "PUT",
            requestBody = JSONObject()
                .put("app_token", appToken)
                .put("dataprot", true)
                .toString()
        )

    private suspend fun execute(
        method: String,
        requestBody: String
    ): Boolean = withContext(Dispatchers.IO) {
        val connection = try {
            connectionFactory(URL(endpointUrl))
        } catch (error: IOException) {
            throw DataProtectionNetworkException(error)
        }
        try {
            connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
            connection.readTimeout = NETWORK_TIMEOUT_MILLIS
            connection.requestMethod = method
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Accept-Encoding", "identity")
            connection.setRequestProperty("User-Agent", "CueLens-Android")
            val bytes = requestBody.toByteArray(Charsets.UTF_8)
            connection.doOutput = true
            connection.setRequestProperty(
                "Content-Type",
                "application/json; charset=UTF-8"
            )
            connection.setRequestProperty("Content-Length", bytes.size.toString())
            connection.setFixedLengthStreamingMode(bytes.size)
            connection.outputStream.use { output -> output.write(bytes) }

            val responseCode = connection.responseCode
            if (responseCode != HttpURLConnection.HTTP_OK) {
                throw DataProtectionHttpException(responseCode)
            }
            val response = connection.inputStream.bufferedReader(Charsets.UTF_8).use {
                it.readText()
            }
            parseStatus(response)
        } catch (error: DataProtectionException) {
            throw error
        } catch (error: IOException) {
            throw DataProtectionNetworkException(error)
        } finally {
            connection.disconnect()
        }
    }

    private fun parseStatus(response: String): Boolean {
        try {
            val payload = JSONObject(response)
            if (!payload.has("dataprot") || payload.get("dataprot") !is Boolean) {
                throw DataProtectionProtocolException()
            }
            return payload.getBoolean("dataprot")
        } catch (error: DataProtectionProtocolException) {
            throw error
        } catch (error: JSONException) {
            throw DataProtectionProtocolException(error)
        }
    }

    private companion object {
        const val NETWORK_TIMEOUT_MILLIS = 15_000
    }
}

sealed class DataProtectionException(message: String, cause: Throwable? = null) :
    IOException(message, cause)

class DataProtectionHttpException(val statusCode: Int) :
    DataProtectionException("Unexpected HTTP status $statusCode")

class DataProtectionNetworkException(cause: IOException) :
    DataProtectionException("Data protection request failed.", cause)

class DataProtectionProtocolException(cause: Throwable? = null) :
    DataProtectionException("Invalid data protection response.", cause)
