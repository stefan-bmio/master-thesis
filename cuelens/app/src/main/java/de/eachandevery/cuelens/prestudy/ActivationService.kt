package de.eachandevery.cuelens.prestudy

import java.io.IOException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject

interface ActivationService {
    suspend fun requestToken(email: String): String
    suspend fun confirmToken(email: String, appToken: String)
}

class HttpActivationService(
    private val endpointUrl: String,
    private val connectionFactory: (URL) -> HttpURLConnection = {
        it.openConnection() as HttpURLConnection
    }
) : ActivationService {
    override suspend fun requestToken(email: String): String = withContext(Dispatchers.IO) {
        val response = executeRequest(JSONObject().put("email", email), expectedStatus = 200)
        val appToken = try {
            JSONObject(response).getString("app_token")
        } catch (error: JSONException) {
            throw ActivationProtocolException(error)
        }
        if (!UUID_V4.matches(appToken)) throw ActivationProtocolException()
        appToken.lowercase()
    }

    override suspend fun confirmToken(email: String, appToken: String): Unit =
        withContext(Dispatchers.IO) {
            try {
                executeRequest(
                    JSONObject()
                        .put("email", email)
                        .put("app_token", appToken),
                    expectedStatus = 204
                )
            } catch (error: ActivationNetworkException) {
                if (error.cause is SocketTimeoutException) {
                    throw ActivationConfirmationTimeoutException(error.cause as SocketTimeoutException)
                }
                throw error
            }
        }

    private fun executeRequest(body: JSONObject, expectedStatus: Int): String {
        val requestBody = body.toString().toByteArray(Charsets.UTF_8)
        val connection = try {
            connectionFactory(URL(endpointUrl))
        } catch (error: IOException) {
            throw ActivationNetworkException(error)
        }
        try {
            connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
            connection.readTimeout = NETWORK_TIMEOUT_MILLIS
            connection.requestMethod = "PUT"
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            connection.setRequestProperty("Accept", "application/json, */*;q=0.8")
            connection.setRequestProperty("Accept-Charset", "UTF-8, *;q=0.5")
            connection.setRequestProperty("Accept-Language", "de, en;q=0.8, *;q=0.5")
            connection.setRequestProperty("Accept-Encoding", "identity")
            connection.setRequestProperty("User-Agent", "CueLens-Android")
            connection.setRequestProperty("Content-Length", requestBody.size.toString())
            connection.setFixedLengthStreamingMode(requestBody.size)
            connection.outputStream.use { output ->
                output.write(requestBody)
            }

            val responseCode = connection.responseCode
            if (responseCode != expectedStatus) {
                throw ActivationHttpException(responseCode)
            }
            if (expectedStatus == 204) return ""
            return connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
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
        val UUID_V4 = Regex(
            "^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[89aAbB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$"
        )
    }
}

sealed class ActivationException(message: String, cause: Throwable? = null) :
    IOException(message, cause)

class ActivationHttpException(val statusCode: Int) :
    ActivationException("Unexpected HTTP status $statusCode")

class ActivationNetworkException(cause: IOException) :
    ActivationException("Activation request failed.", cause)

class ActivationConfirmationTimeoutException(cause: SocketTimeoutException) :
    ActivationException("Activation confirmation timed out.", cause)

class ActivationProtocolException(cause: Throwable? = null) :
    ActivationException("Invalid activation response.", cause)
