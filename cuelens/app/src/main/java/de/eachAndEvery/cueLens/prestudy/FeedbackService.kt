package de.eachAndEvery.cueLens.prestudy

import java.io.IOException
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

fun interface FeedbackService {
    suspend fun submit(source: String, comment: String, appVersion: String)
}

class HttpFeedbackService(
    private val endpointUrl: String,
    private val connectionFactory: (URL) -> HttpURLConnection = {
        it.openConnection() as HttpURLConnection
    }
) : FeedbackService {
    override suspend fun submit(source: String, comment: String, appVersion: String) =
        withContext(Dispatchers.IO) {
            val connection = try {
                connectionFactory(URL(endpointUrl))
            } catch (error: IOException) {
                throw FeedbackNetworkException(error)
            }
            val body = JSONObject()
                .put("source", source)
                .put("comment", comment)
                .put("app_version", appVersion)
                .toString()
            try {
                connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
                connection.readTimeout = NETWORK_TIMEOUT_MILLIS
                connection.requestMethod = "POST"
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json; charset=utf-8")
                connection.setRequestProperty("Accept", "application/json")
                OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                    writer.write(body)
                }
                if (connection.responseCode !in 200..299) {
                    throw FeedbackHttpException(connection.responseCode)
                }
            } catch (error: FeedbackException) {
                throw error
            } catch (error: IOException) {
                throw FeedbackNetworkException(error)
            } finally {
                connection.disconnect()
            }
        }

    private companion object {
        const val NETWORK_TIMEOUT_MILLIS = 15_000
    }
}

sealed class FeedbackException(message: String, cause: Throwable? = null) :
    IOException(message, cause)

class FeedbackHttpException(val statusCode: Int) :
    FeedbackException("Unexpected HTTP status $statusCode")

class FeedbackNetworkException(cause: IOException) :
    FeedbackException("Feedback request failed.", cause)
