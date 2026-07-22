package de.eachandevery.cuelens

import com.sun.net.httpserver.HttpExchange
import com.sun.net.httpserver.HttpServer
import de.eachandevery.cuelens.infofeed.HttpInfoFeedService
import de.eachandevery.cuelens.prestudy.HttpActivationService
import de.eachandevery.cuelens.prestudy.HttpFeedbackService
import java.net.InetSocketAddress
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.CopyOnWriteArrayList
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
        val methods = CopyOnWriteArrayList<String>()
        val bodies = CopyOnWriteArrayList<String>()
        val acceptHeaders = CopyOnWriteArrayList<String>()
        val contentTypeHeaders = CopyOnWriteArrayList<String>()
        val appToken = "550e8400-e29b-41d4-a716-446655440000"
        server.createContext("/cuelens/activate") { exchange ->
            methods += exchange.requestMethod
            acceptHeaders += exchange.requestHeaders.getFirst("Accept")
            contentTypeHeaders += exchange.requestHeaders.getFirst("Content-Type")
            bodies += exchange.requestBody.bufferedReader(Charsets.UTF_8).use { it.readText() }
            if (bodies.size == 1) {
                exchange.respond(200, """{"app_token":"$appToken"}""")
            } else {
                exchange.respond(204, "")
            }
        }

        val service = HttpActivationService("$baseUrl/activate")
        val token = service.requestToken("person@example.org")
        service.confirmToken("person@example.org", token)

        assertEquals(listOf("PUT", "PUT"), methods)
        assertEquals(listOf("application/json, */*;q=0.8", "application/json, */*;q=0.8"), acceptHeaders)
        assertEquals(
            listOf("application/json; charset=UTF-8", "application/json; charset=UTF-8"),
            contentTypeHeaders
        )
        assertEquals("person@example.org", org.json.JSONObject(bodies[0]).getString("email"))
        val confirmation = org.json.JSONObject(bodies[1])
        assertEquals("person@example.org", confirmation.getString("email"))
        assertEquals(appToken, confirmation.getString("app_token"))
        assertEquals(appToken, token)
    }

    @Test
    fun feedbackEndpointIsCalledOverRealLocalHttpConnectionWithoutToken() = runBlocking {
        val method = AtomicReference<String>()
        val body = AtomicReference<String>()
        server.createContext("/cuelens/feedback") { exchange ->
            method.set(exchange.requestMethod)
            body.set(exchange.requestBody.bufferedReader(Charsets.UTF_8).use { it.readText() })
            exchange.respond(204, "")
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
