package de.eachandevery.cuelens.prestudy

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HttpActivationServiceTest {
    @Test
    fun tokenRequestSendsExplicitNegotiationAndJsonHeaders() = runBlocking {
        val connection = SuccessfulHttpConnection(
            URL("https://example.invalid/activate.php"),
            """{"app_token":"$TOKEN"}"""
        )
        val service = HttpActivationService("https://example.invalid/activate.php") { connection }

        service.requestToken("  Participant@Example.ORG  ")

        assertEquals("PUT", connection.requestMethod)
        assertTrue(connection.doOutput)
        assertEquals("application/json; charset=UTF-8", connection.getRequestProperty("Content-Type"))
        assertEquals("application/json, */*;q=0.8", connection.getRequestProperty("Accept"))
        assertEquals("UTF-8, *;q=0.5", connection.getRequestProperty("Accept-Charset"))
        assertEquals("de, en;q=0.8, *;q=0.5", connection.getRequestProperty("Accept-Language"))
        assertEquals("identity", connection.getRequestProperty("Accept-Encoding"))
        assertEquals("CueLens-Android", connection.getRequestProperty("User-Agent"))
        assertEquals(
            connection.output.size().toString(),
            connection.getRequestProperty("Content-Length")
        )
        assertEquals(
            "Participant@Example.ORG",
            org.json.JSONObject(connection.output.toString(Charsets.UTF_8.name()))
                .getString("identifier")
        )
        assertHasOnlyAllowedProperties(connection, setOf("identifier"))
    }

    @Test
    fun prolificRequestAndConfirmationUseSameCasePreservingIdentifier() = runBlocking {
        val request = SuccessfulHttpConnection(
            URL("https://example.invalid/activate.php"),
            """{"app_token":"$TOKEN"}"""
        )
        val confirmation = SuccessfulHttpConnection(
            URL("https://example.invalid/activate.php"),
            responseBody = "",
            statusCode = HttpURLConnection.HTTP_NO_CONTENT
        )
        val connections = ArrayDeque(listOf(request, confirmation))
        val service = HttpActivationService("https://example.invalid/activate.php") {
            connections.removeFirst()
        }

        val identifier = "AbCdEf1234567890GhIjKlMn"
        val token = service.requestToken("  $identifier  ")
        service.confirmToken("\t$identifier\n", token)

        val requestBody = org.json.JSONObject(request.output.toString(Charsets.UTF_8.name()))
        val confirmationBody = org.json.JSONObject(
            confirmation.output.toString(Charsets.UTF_8.name())
        )
        assertEquals(identifier, requestBody.getString("identifier"))
        assertEquals(identifier, confirmationBody.getString("identifier"))
        assertEquals(TOKEN, confirmationBody.getString("app_token"))
        assertHasOnlyAllowedProperties(request, setOf("identifier"))
        assertHasOnlyAllowedProperties(confirmation, setOf("identifier", "app_token"))
    }

    @Test
    fun confirmationTimeoutHasDedicatedException() = runBlocking {
        val service = HttpActivationService("https://example.invalid/activate") { url ->
            TimeoutHttpConnection(url)
        }

        val error = runCatching {
            service.confirmToken("participant@example.org", TOKEN)
        }.exceptionOrNull()

        assertTrue(error is ActivationConfirmationTimeoutException)
    }

    @Test
    fun tokenRequestTimeoutRemainsGeneralNetworkFailure() = runBlocking {
        val service = HttpActivationService("https://example.invalid/activate") { url ->
            TimeoutHttpConnection(url)
        }

        val error = runCatching {
            service.requestToken("participant@example.org")
        }.exceptionOrNull()

        assertTrue(error is ActivationNetworkException)
        assertTrue(error !is ActivationConfirmationTimeoutException)
    }

    private class TimeoutHttpConnection(url: URL) : HttpURLConnection(url) {
        override fun connect() = Unit
        override fun disconnect() = Unit
        override fun usingProxy(): Boolean = false
        override fun getOutputStream() = ByteArrayOutputStream()
        override fun getResponseCode(): Int = throw SocketTimeoutException("test timeout")
    }

    private fun assertHasOnlyAllowedProperties(
        connection: SuccessfulHttpConnection,
        allowed: Set<String>
    ) {
        val body = org.json.JSONObject(connection.output.toString(Charsets.UTF_8.name()))
        assertEquals(allowed, body.keys().asSequence().toSet())
        listOf("email", "prolific_id", "iban", "bic", "name").forEach { prohibited ->
            assertFalse(body.has(prohibited))
        }
    }

    private class SuccessfulHttpConnection(
        url: URL,
        private val responseBody: String,
        private val statusCode: Int = HTTP_OK
    ) :
        HttpURLConnection(url) {
        val output = ByteArrayOutputStream()

        override fun connect() = Unit
        override fun disconnect() = Unit
        override fun usingProxy(): Boolean = false
        override fun getOutputStream() = output
        override fun getResponseCode(): Int = statusCode
        override fun getInputStream() = ByteArrayInputStream(responseBody.toByteArray(Charsets.UTF_8))
    }

    private companion object {
        const val TOKEN = "550e8400-e29b-41d4-a716-446655440000"
    }
}
