package de.eachandevery.cuelens.prestudy

import kotlinx.coroutines.runBlocking
import java.net.SocketTimeoutException
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
        val service = FakeActivationService(requestResult = Result.success("new-token"))
        val controller = PreStudyController(service, tokenStore)
        controller.openEmailActivation()

        controller.activate("person@example.org")

        assertEquals("new-token", tokenStore.token)
        assertEquals(PreStudyRoute.Home, controller.state.value.route)
        assertTrue(controller.state.value.hasAppToken)
        assertEquals(ActivationState.Activated, controller.state.value.activationState)
        assertEquals(listOf("person@example.org"), service.requestedEmails)
        assertEquals(listOf("person@example.org" to "new-token"), service.confirmations)
    }

    @Test
    fun failedActivationStaysOnActivationWithNeutralErrorState() = runBlocking {
        val controller = PreStudyController(
            FakeActivationService(
                requestResult = Result.failure(java.io.IOException("server detail"))
            ),
            FakeAppTokenStore()
        )
        controller.openEmailActivation()

        controller.activate("person@example.org")

        assertEquals(PreStudyRoute.EmailActivation, controller.state.value.route)
        assertFalse(controller.state.value.hasAppToken)
        assertEquals(ActivationState.Error, controller.state.value.activationState)
        assertFalse(controller.state.value.activationNeedsSupport)
    }

    @Test
    fun failedConfirmationDoesNotPersistTokenAndAllowsFreshAttempt() = runBlocking {
        val tokenStore = FakeAppTokenStore()
        val service = FakeActivationService(
            requestResult = Result.success("new-token"),
            confirmResult = Result.failure(ActivationHttpException(400))
        )
        val controller = PreStudyController(service, tokenStore)
        controller.openEmailActivation()

        controller.activate("person@example.org")

        assertEquals(null, tokenStore.token)
        assertEquals(ActivationState.Error, controller.state.value.activationState)
        assertFalse(controller.state.value.activationNeedsSupport)

        controller.activate("person@example.org")
        assertEquals(2, service.callCount)
    }

    @Test
    fun confirmationTimeoutRequiresSupportAndDoesNotPersistToken() = runBlocking {
        val tokenStore = FakeAppTokenStore()
        val controller = PreStudyController(
            FakeActivationService(
                requestResult = Result.success("new-token"),
                confirmResult = Result.failure(
                    ActivationConfirmationTimeoutException(SocketTimeoutException())
                )
            ),
            tokenStore
        )
        controller.openEmailActivation()

        controller.activate("person@example.org")

        assertEquals(null, tokenStore.token)
        assertEquals(ActivationState.Error, controller.state.value.activationState)
        assertTrue(controller.state.value.activationNeedsSupport)
    }

    @Test
    fun unreadableTokenDisablesActivation() {
        val service = FakeActivationService()
        val controller = PreStudyController(
            service,
            object : AppTokenStore {
                override fun getAppToken(): String? = throw AppTokenStorageException()
                override fun saveAppToken(appToken: String) = Unit
                override fun clear() = Unit
            }
        )

        controller.openEmailActivation()

        assertTrue(controller.state.value.tokenStorageFailed)
        assertEquals(PreStudyRoute.Home, controller.state.value.route)
        assertEquals(0, service.callCount)
    }

    @Test
    fun failedEncryptedStorageDoesNotMarkActivationComplete() = runBlocking {
        val controller = PreStudyController(
            FakeActivationService(requestResult = Result.success("new-token")),
            object : AppTokenStore {
                override fun getAppToken(): String? = null
                override fun saveAppToken(appToken: String) = throw AppTokenStorageException()
                override fun clear() = Unit
            }
        )
        controller.openEmailActivation()

        controller.activate("person@example.org")

        assertEquals(PreStudyRoute.EmailActivation, controller.state.value.route)
        assertFalse(controller.state.value.hasAppToken)
        assertEquals(ActivationState.Error, controller.state.value.activationState)
    }

    @Test
    fun invalidEmailDoesNotStartRequest() = runBlocking {
        val service = FakeActivationService()
        val controller = PreStudyController(service, FakeAppTokenStore())
        controller.openEmailActivation()

        controller.activate("invalid")

        assertEquals(0, service.callCount)
        assertEquals(ActivationState.Idle, controller.state.value.activationState)
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
        assertEquals(ActivationState.Idle, controller.state.value.activationState)
    }

    @Test
    fun enabledNextStudyRunIsShownOnlyForEligibleActivatedApp() = runBlocking {
        val controller = PreStudyController(
            activationService = FakeActivationService(),
            appTokenStore = FakeAppTokenStore("existing-token"),
            featureConfigService = FeatureConfigService { true },
            studyProgressStore = StudyProgressStore {
                StudyProgress(nextSituationAvailableAtMillis = 1_000L)
            },
            nowMillis = { 1_000L }
        )

        controller.refreshNextStudyRun()
        assertTrue(controller.state.value.nextStudyRunVisible)
        assertTrue(controller.state.value.nextStudyRunEligible)
        assertTrue(controller.state.value.nextStudyRunAvailable)

        controller.openNextStudyRun()
        assertEquals(PreStudyRoute.ProductiveStudy, controller.state.value.route)
    }

    @Test
    fun nextStudyRunFailsClosedWhenDisabledOrCooldownIsActive() = runBlocking {
        val disabled = PreStudyController(
            activationService = FakeActivationService(),
            appTokenStore = FakeAppTokenStore("existing-token"),
            featureConfigService = FeatureConfigService { false },
            studyProgressStore = StudyProgressStore { StudyProgress() }
        )
        disabled.refreshNextStudyRun()
        assertFalse(disabled.state.value.nextStudyRunVisible)
        assertFalse(disabled.state.value.nextStudyRunAvailable)

        val coolingDown = PreStudyController(
            activationService = FakeActivationService(),
            appTokenStore = FakeAppTokenStore("existing-token"),
            featureConfigService = FeatureConfigService { true },
            studyProgressStore = StudyProgressStore {
                StudyProgress(nextSituationAvailableAtMillis = 1_001L)
            },
            nowMillis = { 1_000L }
        )
        coolingDown.refreshNextStudyRun()
        assertTrue(coolingDown.state.value.nextStudyRunVisible)
        assertTrue(coolingDown.state.value.nextStudyRunEligible)
        assertFalse(coolingDown.state.value.nextStudyRunAvailable)
        assertEquals(1_001L, coolingDown.state.value.nextStudyRunAvailableAtMillis)
    }

    @Test
    fun nextStudyRunRemainsHiddenWithoutAppToken() = runBlocking {
        var configRequests = 0
        val controller = PreStudyController(
            activationService = FakeActivationService(),
            appTokenStore = FakeAppTokenStore(),
            featureConfigService = FeatureConfigService {
                configRequests += 1
                true
            },
            studyProgressStore = StudyProgressStore { StudyProgress() }
        )

        controller.refreshNextStudyRun()

        assertFalse(controller.state.value.nextStudyRunAvailable)
        assertEquals(0, configRequests)
    }

    @Test
    fun completedStudyExposesOnlyItsCompensationStateWithoutFeatureRequest() = runBlocking {
        var configRequests = 0
        val controller = PreStudyController(
            activationService = FakeActivationService(),
            appTokenStore = FakeAppTokenStore("existing-token"),
            featureConfigService = FeatureConfigService {
                configRequests += 1
                true
            },
            studyProgressStore = StudyProgressStore {
                StudyProgress(
                    completed = true,
                    compensationCode = "COMP-1234"
                )
            }
        )

        assertTrue(controller.state.value.studyCompleted)
        assertEquals("COMP-1234", controller.state.value.compensationCode)

        controller.openDemo()
        controller.openEmailActivation()
        controller.refreshNextStudyRun()

        assertEquals(PreStudyRoute.Home, controller.state.value.route)
        assertFalse(controller.state.value.nextStudyRunVisible)
        assertFalse(controller.state.value.studyTransferPending)
        assertEquals(0, configRequests)
    }

    @Test
    fun studyCooldownUsesRoundedUpHoursMinutesAndSeconds() {
        assertEquals("00:00:01", formatStudyCooldown(1L))
        assertEquals("00:00:02", formatStudyCooldown(1_001L))
        assertEquals("03:00:00", formatStudyCooldown(10_800_000L))
    }

    @Test
    fun pendingStudyTransferCanBeRetriedFromHome() = runBlocking {
        var progress = StudyProgress(hasPendingSubmission = true)
        var retryCount = 0
        val controller = PreStudyController(
            activationService = FakeActivationService(),
            appTokenStore = FakeAppTokenStore("existing-token"),
            featureConfigService = FeatureConfigService { true },
            studyProgressStore = StudyProgressStore { progress },
            studyTransferRetryService = StudyTransferRetryService {
                retryCount += 1
                progress = StudyProgress(
                    confirmedSituationCount = 1,
                    nextSituationAvailableAtMillis = 2_000L
                )
            },
            nowMillis = { 1_000L }
        )
        controller.refreshNextStudyRun()
        assertTrue(controller.state.value.studyTransferPending)
        assertFalse(controller.state.value.nextStudyRunEligible)

        controller.retryPendingStudyTransfer()

        assertEquals(1, retryCount)
        assertFalse(controller.state.value.studyTransferPending)
        assertFalse(controller.state.value.studyTransferRetryFailed)
        assertTrue(controller.state.value.nextStudyRunEligible)
    }

    @Test
    fun failedStudyTransferRetryRemainsAvailable() = runBlocking {
        val controller = PreStudyController(
            activationService = FakeActivationService(),
            appTokenStore = FakeAppTokenStore("existing-token"),
            featureConfigService = FeatureConfigService { true },
            studyProgressStore = StudyProgressStore {
                StudyProgress(hasPendingSubmission = true)
            },
            studyTransferRetryService = StudyTransferRetryService {
                throw java.io.IOException("network unavailable")
            }
        )
        controller.refreshNextStudyRun()

        controller.retryPendingStudyTransfer()

        assertTrue(controller.state.value.studyTransferPending)
        assertFalse(controller.state.value.studyTransferRetrying)
        assertTrue(controller.state.value.studyTransferRetryFailed)
    }

    @Test
    fun pendingStudyTransferRemainsVisibleWhenFeatureConfigFailsClosed() = runBlocking {
        val controller = PreStudyController(
            activationService = FakeActivationService(),
            appTokenStore = FakeAppTokenStore("existing-token"),
            featureConfigService = FeatureConfigService { false },
            studyProgressStore = StudyProgressStore {
                StudyProgress(hasPendingSubmission = true)
            }
        )

        controller.refreshNextStudyRun()

        assertFalse(controller.state.value.nextStudyRunVisible)
        assertTrue(controller.state.value.studyTransferPending)
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
        private val requestResult: Result<String> = Result.success("token"),
        private val confirmResult: Result<Unit> = Result.success(Unit)
    ) : ActivationService {
        val requestedEmails = mutableListOf<String>()
        val confirmations = mutableListOf<Pair<String, String>>()
        val callCount: Int
            get() = requestedEmails.size

        override suspend fun requestToken(email: String): String {
            requestedEmails += email
            return requestResult.getOrThrow()
        }

        override suspend fun confirmToken(email: String, appToken: String) {
            confirmations += email to appToken
            confirmResult.getOrThrow()
        }
    }

    private class FakeAppTokenStore(initialToken: String? = null) : AppTokenStore {
        var token = initialToken
        override fun getAppToken(): String? = token
        override fun saveAppToken(appToken: String) {
            token = appToken
        }
        override fun clear() {
            token = null
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
