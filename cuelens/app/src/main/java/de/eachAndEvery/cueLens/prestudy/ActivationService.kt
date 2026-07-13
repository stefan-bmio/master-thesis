package de.eachAndEvery.cueLens.prestudy

import java.io.IOException
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject

interface ActivationService {
    suspend fun activate(email: String): String
}

class HttpActivationService(
    private val endpointUrl: String,
    private val connectionFactory: (URL) -> HttpURLConnection = {
        it.openConnection() as HttpURLConnection
    }
) : ActivationService {
    override suspend fun activate(email: String): String = withContext(Dispatchers.IO) {
        val connection = try {
            connectionFactory(URL(endpointUrl))
        } catch (error: IOException) {
            throw ActivationNetworkException(error)
        }
        val body = JSONObject().put("email", email).toString()
        try {
            connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
            connection.readTimeout = NETWORK_TIMEOUT_MILLIS
            connection.requestMethod = "PUT"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            connection.setRequestProperty("Accept", "application/json")
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(body)
            }

            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                throw ActivationHttpException(responseCode)
            }
            val responseBody = connection.inputStream
                .bufferedReader(Charsets.UTF_8)
                .use { it.readText() }
            val appToken = try {
                JSONObject(responseBody).getString("app_token")
            } catch (error: JSONException) {
                throw ActivationProtocolException(error)
            }
            if (appToken.isBlank()) throw ActivationProtocolException()
            appToken
        } catch (error: ActivationException) {
            throw error
        } catch (error: IOException) {
            throw ActivationNetworkException(error)
        } finally {
            connection.disconnect()
        }
    }

    private companion object {
        const val NETWORK_TIMEOUT_MILLIS = 15_000
    }
}

sealed class ActivationException(message: String, cause: Throwable? = null) :
    IOException(message, cause)

class ActivationHttpException(val statusCode: Int) :
    ActivationException("Unexpected HTTP status $statusCode")

class ActivationNetworkException(cause: IOException) :
    ActivationException("Activation request failed.", cause)

class ActivationProtocolException(cause: Throwable? = null) :
    ActivationException("Invalid activation response.", cause)
