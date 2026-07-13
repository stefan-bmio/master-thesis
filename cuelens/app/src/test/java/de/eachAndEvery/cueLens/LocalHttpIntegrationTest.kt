package de.eachAndEvery.cueLens

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import de.eachAndEvery.cueLens.infofeed.HttpInfoFeedService
import de.eachAndEvery.cueLens.prestudy.HttpActivationService
import de.eachAndEvery.cueLens.prestudy.HttpFeedbackService
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicReference
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test

class LocalHttpIntegrationTest {
    private lateinit var server: HttpServer
    private lateinit var baseUrl: String

    @Before
    fun setUp() {
        server = HttpServer.create(InetSocketAddress("192.168.1.203", 0), 0)
        server.start()
        baseUrl = "http://192.168.1.203:${server.address.port}/cuelens"
    }

    @After
    fun tearDown() {
        server.stop(0)
    }

    @Test
    fun messagesEndpointIsCalledOverRealLocalHttpConnection() = runBlocking {
        val request = AtomicReference<String>()
        server.createContext("/cuelens/messages") { exchange ->
            request.set("${exchange.requestMethod} ${exchange.requestURI.rawQuery}")
            exchange.respond(
                200,
                """{"messages":[{"id":4,"created_at":"2026-07-07T20:00:00Z","text_de":"Information","text_en":"Information"}]}"""
            )
        }

        val messages = HttpInfoFeedService("$baseUrl/messages")
            .fetchMessages()

        assertEquals("GET null", request.get())
        assertEquals(listOf(4L), messages.map { it.id })
    }

    @Test
    fun activationEndpointIsCalledOverRealLocalHttpConnection() = runBlocking {
        val method = AtomicReference<String>()
        val body = AtomicReference<String>()
        server.createContext("/cuelens/activate") { exchange ->
            method.set(exchange.requestMethod)
            body.set(exchange.requestBody.bufferedReader(Charsets.UTF_8).use { it.readText() })
            exchange.respond(200, """{"success":true,"app_token":"local-token"}""")
        }

        val token = HttpActivationService("$baseUrl/activate")
            .activate("person@example.org")

        assertEquals("PUT", method.get())
        assertEquals("person@example.org", org.json.JSONObject(body.get()).getString("email"))
        assertEquals("local-token", token)
    }

    @Test
    fun feedbackEndpointIsCalledOverRealLocalHttpConnectionWithoutToken() = runBlocking {
        val method = AtomicReference<String>()
        val body = AtomicReference<String>()
        server.createContext("/cuelens/feedback") { exchange ->
            method.set(exchange.requestMethod)
            body.set(exchange.requestBody.bufferedReader(Charsets.UTF_8).use { it.readText() })
            exchange.respond(201, """{"success":true}""")
        }

        HttpFeedbackService("$baseUrl/feedback")
            .submit("Flyer", "The example was clear.", "1.0")

        val payload = org.json.JSONObject(body.get())
        assertEquals("POST", method.get())
        assertEquals("Flyer", payload.getString("source"))
        assertEquals("The example was clear.", payload.getString("comment"))
        assertEquals("1.0", payload.getString("app_version"))
        assertFalse(payload.has("app_token"))
    }

    private fun HttpExchange.respond(statusCode: Int, bodyText: String) {
        val bytes = bodyText.toByteArray(Charsets.UTF_8)
        responseHeaders.set("Content-Type", "application/json; charset=utf-8")
        sendResponseHeaders(statusCode, bytes.size.toLong())
        responseBody.use { output -> output.write(bytes) }
    }
}
