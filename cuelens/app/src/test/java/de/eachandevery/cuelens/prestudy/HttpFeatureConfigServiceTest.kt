package de.eachandevery.cuelens.prestudy

import java.io.ByteArrayInputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HttpFeatureConfigServiceTest {
    @Test
    fun readsEnabledFlagFromExactResponseShape() = runBlocking {
        val service = serviceFor(200, """{"features":{"next_study_run_enabled":true}}""")

        assertTrue(service.nextStudyRunEnabled())
    }

    @Test
    fun failsClosedForDisabledMalformedAndErrorResponses() = runBlocking {
        assertFalse(
            serviceFor(200, """{"features":{"next_study_run_enabled":false}}""")
                .nextStudyRunEnabled()
        )
        assertFalse(serviceFor(200, """{"next_study_run_enabled":true}""").nextStudyRunEnabled())
        assertFalse(serviceFor(500, "").nextStudyRunEnabled())
    }

    private fun serviceFor(status: Int, body: String): HttpFeatureConfigService =
        HttpFeatureConfigService("https://example.invalid/features") { url ->
            StubHttpConnection(url, status, body)
        }

    private class StubHttpConnection(
        url: URL,
        private val status: Int,
        private val body: String
    ) : HttpURLConnection(url) {
        override fun connect() = Unit
        override fun disconnect() = Unit
        override fun usingProxy(): Boolean = false
        override fun getResponseCode(): Int = status
        override fun getInputStream() = ByteArrayInputStream(body.toByteArray(Charsets.UTF_8))
    }
}
