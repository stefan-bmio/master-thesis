package de.eachAndEvery.cueLens.prestudy

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PreStudyControllerTest {
    @Test
    fun existingTokenKeepsActivationUnavailable() {
        val service = FakeActivationService()
        val controller = PreStudyController(service, FakeAppTokenStore("existing-token"))

        controller.openEmailActivation()

        assertTrue(controller.state.value.hasAppToken)
        assertEquals(PreStudyRoute.Home, controller.state.value.route)
        assertEquals(0, service.callCount)
    }

    @Test
    fun successfulActivationStoresOnlyTokenAndReturnsHome() = runBlocking {
        val tokenStore = FakeAppTokenStore()
        val service = FakeActivationService(result = Result.success("new-token"))
        val controller = PreStudyController(service, tokenStore)
        controller.openEmailActivation()

        controller.activate("person@example.org")

        assertEquals("new-token", tokenStore.token)
        assertEquals(PreStudyRoute.Home, controller.state.value.route)
        assertTrue(controller.state.value.hasAppToken)
        assertFalse(controller.state.value.activationFailed)
        assertEquals(listOf("person@example.org"), service.emails)
    }

    @Test
    fun failedActivationStaysOnActivationWithNeutralErrorState() = runBlocking {
        val controller = PreStudyController(
            FakeActivationService(result = Result.failure(java.io.IOException("server detail"))),
            FakeAppTokenStore()
        )
        controller.openEmailActivation()

        controller.activate("person@example.org")

        assertEquals(PreStudyRoute.EmailActivation, controller.state.value.route)
        assertFalse(controller.state.value.hasAppToken)
        assertTrue(controller.state.value.activationFailed)
    }

    @Test
    fun invalidEmailDoesNotStartRequest() = runBlocking {
        val service = FakeActivationService()
        val controller = PreStudyController(service, FakeAppTokenStore())
        controller.openEmailActivation()

        controller.activate("invalid")

        assertEquals(0, service.callCount)
        assertFalse(controller.state.value.activationInProgress)
    }

    @Test
    fun demoProgressesLocallyWithoutActivationOrTokenChanges() {
        val service = FakeActivationService()
        val tokenStore = FakeAppTokenStore()
        val controller = PreStudyController(service, tokenStore)

        controller.openDemo()
        assertEquals(PreStudyRoute.DemoImageMatching, controller.state.value.route)
        controller.advanceDemo()
        assertEquals(PreStudyRoute.DemoWordLabeling, controller.state.value.route)
        controller.advanceDemo()
        assertEquals(PreStudyRoute.DemoCraving, controller.state.value.route)
        controller.advanceDemo()
        assertEquals(PreStudyRoute.DemoComplete, controller.state.value.route)

        assertEquals(0, service.callCount)
        assertEquals(null, tokenStore.token)
        assertFalse(controller.state.value.hasAppToken)
    }

    @Test
    fun demoCanBeAbortedWithoutPersistingState() {
        val controller = PreStudyController(FakeActivationService(), FakeAppTokenStore())

        controller.openDemo()
        controller.backToHome()

        assertEquals(PreStudyRoute.Home, controller.state.value.route)
        assertFalse(controller.state.value.activationInProgress)
        assertFalse(controller.state.value.activationFailed)
    }

    @Test
    fun feedbackSubmissionContainsOnlyFeedbackFieldsAndShowsConfirmation() = runBlocking {
        val feedbackService = FakeFeedbackService()
        val controller = PreStudyController(
            FakeActivationService(),
            FakeAppTokenStore("existing-token"),
            feedbackService
        )
        controller.openFeedback()

        controller.submitFeedback("Flyer", "The example was clear.", "1.0")

        assertEquals(PreStudyRoute.Feedback, controller.state.value.route)
        assertTrue(controller.state.value.feedbackSubmitted)
        assertFalse(controller.state.value.feedbackFailed)
        assertEquals(listOf(FeedbackPayload("Flyer", "The example was clear.", "1.0")), feedbackService.payloads)
    }

    @Test
    fun invalidFeedbackDoesNotStartRequest() = runBlocking {
        val feedbackService = FakeFeedbackService()
        val controller = PreStudyController(FakeActivationService(), FakeAppTokenStore(), feedbackService)
        controller.openFeedback()

        controller.submitFeedback("", "", "1.0")

        assertTrue(feedbackService.payloads.isEmpty())
        assertFalse(controller.state.value.feedbackSubmitting)
    }

    @Test
    fun feedbackFailureStaysOnFormWithNeutralErrorState() = runBlocking {
        val controller = PreStudyController(
            FakeActivationService(),
            FakeAppTokenStore(),
            FakeFeedbackService(result = Result.failure(java.io.IOException("server detail")))
        )
        controller.openFeedback()

        controller.submitFeedback("Flyer", "A comment", "1.0")

        assertEquals(PreStudyRoute.Feedback, controller.state.value.route)
        assertFalse(controller.state.value.feedbackSubmitted)
        assertTrue(controller.state.value.feedbackFailed)
    }

    private class FakeActivationService(
        private val result: Result<String> = Result.success("token")
    ) : ActivationService {
        val emails = mutableListOf<String>()
        val callCount: Int
            get() = emails.size

        override suspend fun activate(email: String): String {
            emails += email
            return result.getOrThrow()
        }
    }

    private class FakeAppTokenStore(initialToken: String? = null) : AppTokenStore {
        var token = initialToken
        override fun getAppToken(): String? = token
        override fun saveAppToken(appToken: String) {
            token = appToken
        }
    }

    private data class FeedbackPayload(val source: String, val comment: String, val appVersion: String)

    private class FakeFeedbackService(
        private val result: Result<Unit> = Result.success(Unit)
    ) : FeedbackService {
        val payloads = mutableListOf<FeedbackPayload>()

        override suspend fun submit(source: String, comment: String, appVersion: String) {
            payloads += FeedbackPayload(source, comment, appVersion)
            result.getOrThrow()
        }
    }
}
