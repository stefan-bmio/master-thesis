package de.eachandevery.cuelens.infofeed

import java.io.ByteArrayInputStream
import java.io.InputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class HttpInfoFeedServiceTest {
    @Test
    fun fetchMessagesUsesEndpointUrlAndParsesResponse() = runBlocking {
        var requestedUrl: URL? = null
        val response = """
            {
              "messages": [
                {
                  "id": 4,
                  "created_at": "2026-07-07T20:00:00Z",
                  "text_de": "Information",
                  "text_en": "Information"
                }
              ]
            }
        """.trimIndent()
        val service = HttpInfoFeedService("https://example.test/messages.php") { url ->
            requestedUrl = url
            FakeHttpURLConnection(url, 200, response)
        }

        val messages = service.fetchMessages()

        assertEquals("https://example.test/messages.php", requestedUrl.toString())
        assertEquals(
            listOf(
                InfoMessage(
                    id = 4L,
                    createdAtUtc = "2026-07-07T20:00:00Z",
                    textDe = "Information",
                    textEn = "Information"
                )
            ),
            messages
        )
    }

    @Test
    fun fetchMessagesAcceptsEmptyFeedWithoutQueryParameter() = runBlocking {
        var requestedUrl: URL? = null
        val service = HttpInfoFeedService("https://example.test/messages.php") { url ->
            requestedUrl = url
            FakeHttpURLConnection(url, 200, """{"messages":[]}""")
        }

        assertTrue(service.fetchMessages().isEmpty())
        assertEquals("https://example.test/messages.php", requestedUrl.toString())
    }

    @Test
    fun fetchMessagesReportsHttpErrorAndGenericServerMessage() {
        val service = HttpInfoFeedService("https://example.test/messages.php") { url ->
            FakeHttpURLConnection(
                url = url,
                statusCode = 500,
                errorBody = """{"success":false,"error":"Server error."}"""
            )
        }

        val error = assertThrows(InfoFeedHttpException::class.java) {
            runBlocking { service.fetchMessages() }
        }

        assertEquals(500, error.statusCode)
        assertEquals("Server error.", error.serverMessage)
    }

    @Test
    fun fetchMessagesRejectsMalformedJson() {
        val service = HttpInfoFeedService("https://example.test/messages.php") { url ->
            FakeHttpURLConnection(url, 200, "not-json")
        }

        assertThrows(InfoFeedProtocolException::class.java) {
            runBlocking { service.fetchMessages() }
        }
    }

    @Test
    fun fetchMessagesRejectsDuplicateIds() {
        val response = """
            {"messages":[
              {"id":1,"created_at":"2026-07-07T20:00:00Z","text_de":"A","text_en":"A"},
              {"id":1,"created_at":"2026-07-08T20:00:00Z","text_de":"B","text_en":"B"}
            ]}
        """.trimIndent()
        val service = HttpInfoFeedService("https://example.test/messages.php") { url ->
            FakeHttpURLConnection(url, 200, response)
        }

        assertThrows(InfoFeedProtocolException::class.java) {
            runBlocking { service.fetchMessages() }
        }
    }

    @Test
    fun fetchMessagesWrapsConnectionFailure() {
        val service = HttpInfoFeedService("https://example.test/messages.php") {
            throw IOException("offline")
        }

        assertThrows(InfoFeedNetworkException::class.java) {
            runBlocking { service.fetchMessages() }
        }
    }

    private class FakeHttpURLConnection(
        url: URL,
        private val statusCode: Int,
        responseBody: String = "",
        private val errorBody: String? = null
    ) : HttpURLConnection(url) {
        private val responseBytes = responseBody.toByteArray(Charsets.UTF_8)

        override fun getResponseCode(): Int = statusCode

        override fun getInputStream(): InputStream = ByteArrayInputStream(responseBytes)

        override fun getErrorStream(): InputStream? = errorBody
            ?.toByteArray(Charsets.UTF_8)
            ?.let(::ByteArrayInputStream)

        override fun disconnect() = Unit

        override fun usingProxy(): Boolean = false

        override fun connect() = Unit
    }
}
