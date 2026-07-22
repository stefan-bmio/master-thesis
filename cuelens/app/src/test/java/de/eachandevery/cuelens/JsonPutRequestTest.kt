package de.eachandevery.cuelens

import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class JsonPutRequestTest {
    @Test
    fun writesBodyWithExplicitNegotiationAndJsonHeaders() {
        val connection = RecordingHttpConnection(URL("https://example.invalid/submit.php"))
        val body = """{"craving":42}""".toByteArray(Charsets.UTF_8)

        writeJsonPutRequest(connection, body)

        assertEquals("PUT", connection.requestMethod)
        assertTrue(connection.doOutput)
        assertEquals("application/json; charset=UTF-8", connection.getRequestProperty("Content-Type"))
        assertEquals("application/json, */*;q=0.8", connection.getRequestProperty("Accept"))
        assertEquals("UTF-8, *;q=0.5", connection.getRequestProperty("Accept-Charset"))
        assertEquals("de, en;q=0.8, *;q=0.5", connection.getRequestProperty("Accept-Language"))
        assertEquals("identity", connection.getRequestProperty("Accept-Encoding"))
        assertEquals("CueLens-Android", connection.getRequestProperty("User-Agent"))
        assertEquals(body.size.toString(), connection.getRequestProperty("Content-Length"))
        assertArrayEquals(body, connection.output.toByteArray())
    }

    private class RecordingHttpConnection(url: URL) : HttpURLConnection(url) {
        val output = ByteArrayOutputStream()

        override fun connect() = Unit
        override fun disconnect() = Unit
        override fun usingProxy(): Boolean = false
        override fun getOutputStream() = output
    }
}
