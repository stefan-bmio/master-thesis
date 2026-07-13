package de.eachAndEvery.cueLens.infofeed

import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONException
import org.json.JSONObject

interface InfoFeedService {
    suspend fun fetchMessages(excludedIds: Set<Long>): List<InfoMessage>
}

class HttpInfoFeedService(
    private val endpointUrl: String,
    private val connectionFactory: (URL) -> HttpURLConnection = {
        it.openConnection() as HttpURLConnection
    }
) : InfoFeedService {
    override suspend fun fetchMessages(excludedIds: Set<Long>): List<InfoMessage> =
        withContext(Dispatchers.IO) {
            val connection = try {
                connectionFactory(buildRequestUrl(excludedIds))
            } catch (error: IOException) {
                throw InfoFeedNetworkException(error)
            }
            try {
                connection.connectTimeout = NETWORK_TIMEOUT_MILLIS
                connection.readTimeout = NETWORK_TIMEOUT_MILLIS
                connection.requestMethod = "GET"
                connection.setRequestProperty("Accept", "application/json")

                val responseCode = connection.responseCode
                if (responseCode !in 200..299) {
                    throw InfoFeedHttpException(
                        statusCode = responseCode,
                        serverMessage = readServerErrorMessage(connection)
                    )
                }

                val responseBody = connection.inputStream
                    .bufferedReader(Charsets.UTF_8)
                    .use { it.readText() }
                parseResponse(responseBody)
            } catch (error: InfoFeedException) {
                throw error
            } catch (error: IOException) {
                throw InfoFeedNetworkException(error)
            } finally {
                connection.disconnect()
            }
        }

    private fun buildRequestUrl(excludedIds: Set<Long>): URL {
        val validIds = excludedIds
            .onEach { require(it > 0L) { "Excluded message IDs must be positive." } }
            .sorted()
        if (validIds.isEmpty()) {
            return URL(endpointUrl)
        }

        val separator = if ('?' in endpointUrl) '&' else '?'
        return URL(endpointUrl + separator + "exclude_ids=" + validIds.joinToString(","))
    }

    private fun parseResponse(responseBody: String): List<InfoMessage> {
        try {
            val root = JSONObject(responseBody)
            val messagesJson = root.getJSONArray("messages")
            val seenIds = mutableSetOf<Long>()
            return buildList(messagesJson.length()) {
                for (index in 0 until messagesJson.length()) {
                    val item = messagesJson.getJSONObject(index)
                    val rawId = item.get("id")
                    if (rawId !is Byte && rawId !is Short && rawId !is Int && rawId !is Long) {
                        throw InfoFeedProtocolException("Message ID must be an integer.")
                    }
                    val id = (rawId as Number).toLong()
                    if (id <= 0L || !seenIds.add(id)) {
                        throw InfoFeedProtocolException("Message IDs must be positive and unique.")
                    }

                    val createdAtUtc = item.getString("created_at")
                    if (!ISO_8601_UTC.matches(createdAtUtc)) {
                        throw InfoFeedProtocolException("created_at must use ISO 8601 UTC.")
                    }

                    add(
                        InfoMessage(
                            id = id,
                            createdAtUtc = createdAtUtc,
                            textDe = item.getString("text_de"),
                            textEn = item.getString("text_en")
                        )
                    )
                }
            }
        } catch (error: InfoFeedProtocolException) {
            throw error
        } catch (error: JSONException) {
            throw InfoFeedProtocolException("Invalid messages response.", error)
        }
    }

    private fun readServerErrorMessage(connection: HttpURLConnection): String? {
        val errorBody = connection.errorStream
            ?.bufferedReader(Charsets.UTF_8)
            ?.use { it.readText() }
            ?: return null
        return try {
            JSONObject(errorBody).optString("error").takeIf(String::isNotBlank)
        } catch (_: JSONException) {
            null
        }
    }

    private companion object {
        const val NETWORK_TIMEOUT_MILLIS = 10_000
        val ISO_8601_UTC = Regex("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
    }
}

sealed class InfoFeedException(message: String, cause: Throwable? = null) :
    IOException(message, cause)

class InfoFeedHttpException(
    val statusCode: Int,
    val serverMessage: String?
) : InfoFeedException("Unexpected HTTP status $statusCode")

class InfoFeedNetworkException(cause: IOException) :
    InfoFeedException("Info feed request failed.", cause)

class InfoFeedProtocolException(message: String, cause: Throwable? = null) :
    InfoFeedException(message, cause)
