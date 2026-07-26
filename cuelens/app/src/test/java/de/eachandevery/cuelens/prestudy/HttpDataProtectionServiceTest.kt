package de.eachandevery.cuelens.prestudy

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HttpDataProtectionServiceTest {
    @Test
    fun statusUsesPostWithAppTokenAndReadsFalseStatus() = runBlocking {
        val connection = StubHttpConnection(
            URL("https://example.invalid/dataprot.php"),
            200,
            """{"dataprot":false}"""
        )
        val service = HttpDataProtectionService("https://example.invalid/dataprot.php") {
            connection
        }

        assertFalse(service.getStatus(TOKEN))

        assertEquals("POST", connection.requestMethod)
        assertEquals(null, connection.getRequestProperty("Authorization"))
        assertEquals("application/json", connection.getRequestProperty("Accept"))
        assertEquals("identity", connection.getRequestProperty("Accept-Encoding"))
        assertEquals("CueLens-Android", connection.getRequestProperty("User-Agent"))
        assertTrue(connection.doOutput)
        val payload = JSONObject(connection.output.toString(Charsets.UTF_8.name()))
        assertEquals(1, payload.length())
        assertEquals(TOKEN, payload.getString("app_token"))
    }

    @Test
    fun putSendsAppTokenAndExplicitConsentAndReadsTrueStatus() = runBlocking {
        val connection = StubHttpConnection(
            URL("https://example.invalid/dataprot.php"),
            200,
            """{"dataprot":true}"""
        )
        val service = HttpDataProtectionService("https://example.invalid/dataprot.php") {
            connection
        }

        assertTrue(service.accept(TOKEN))

        assertEquals("PUT", connection.requestMethod)
        assertEquals(null, connection.getRequestProperty("Authorization"))
        val payload = JSONObject(connection.output.toString(Charsets.UTF_8.name()))
        assertEquals(2, payload.length())
        assertEquals(TOKEN, payload.getString("app_token"))
        assertTrue(payload.has("dataprot"))
        assertTrue(payload.getBoolean("dataprot"))
    }

    @Test
    fun invalidResponseAndHttpFailureUseDedicatedExceptions() = runBlocking {
        val malformed = HttpDataProtectionService("https://example.invalid/dataprot.php") { url ->
            StubHttpConnection(url, 200, """{"dataprot":"true"}""")
        }
        val unauthorized = HttpDataProtectionService("https://example.invalid/dataprot.php") { url ->
            StubHttpConnection(url, 401, """{"error":"Unauthorized."}""")
        }

        assertTrue(
            runCatching { malformed.getStatus(TOKEN) }.exceptionOrNull()
                is DataProtectionProtocolException
        )
        val httpError = runCatching { unauthorized.getStatus(TOKEN) }.exceptionOrNull()
        assertTrue(httpError is DataProtectionHttpException)
        assertEquals(401, (httpError as DataProtectionHttpException).statusCode)
    }

    private class StubHttpConnection(
        url: URL,
        private val status: Int,
        private val body: String
    ) : HttpURLConnection(url) {
        val output = ByteArrayOutputStream()

        override fun connect() = Unit
        override fun disconnect() = Unit
        override fun usingProxy(): Boolean = false
        override fun getResponseCode(): Int = status
        override fun getInputStream() = ByteArrayInputStream(body.toByteArray(Charsets.UTF_8))
        override fun getOutputStream() = output
    }

    private companion object {
        const val TOKEN = "550e8400-e29b-41d4-a716-446655440000"
    }
}
