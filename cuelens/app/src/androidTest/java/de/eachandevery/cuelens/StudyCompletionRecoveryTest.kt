package de.eachandevery.cuelens

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import de.eachandevery.cuelens.prestudy.AppTokenStore
import de.eachandevery.cuelens.prestudy.CompletionState
import de.eachandevery.cuelens.prestudy.KEY_CONFIRMED_SITUATION_COUNT
import de.eachandevery.cuelens.prestudy.KEY_PENDING_SUBMISSION_CRAVING
import de.eachandevery.cuelens.prestudy.SelfReportResponse
import de.eachandevery.cuelens.prestudy.STUDY_PREFERENCES_NAME
import de.eachandevery.cuelens.prestudy.SharedPreferencesStudyProgressStore
import java.io.IOException
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class StudyCompletionRecoveryTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val preferences by lazy {
        context.getSharedPreferences(STUDY_PREFERENCES_NAME, Context.MODE_PRIVATE)
    }

    @Before
    fun clearBeforeTest() {
        assertTrue(preferences.edit().clear().commit())
        assertTrue(
            preferences.edit()
                .putInt(KEY_CONFIRMED_SITUATION_COUNT, 19)
                .putInt(KEY_PENDING_SUBMISSION_CRAVING, 50)
                .commit()
        )
    }

    @After
    fun clearAfterTest() {
        preferences.edit().clear().commit()
    }

    @Test
    fun prolificCompletionDoesNotSendCompensationConfirmation() = runBlocking {
        val service = FakeStudySubmissionService(SelfReportResponse.ProlificComplete)

        val result = recoverPendingNetworkWork(
            preferences = preferences,
            appTokenStore = FakeAppTokenStore,
            submissionService = service,
            onStudyStateChanged = {}
        )

        assertTrue(result.isSuccess)
        assertEquals(1, service.submissionCount)
        assertEquals(0, service.confirmationCount)
        val progress = SharedPreferencesStudyProgressStore(context).read()
        assertSame(CompletionState.ProlificCompleted, progress.completionState)
        assertFalse(progress.hasPendingSubmission)
    }

    @Test
    fun pendingFinalProlificSubmissionSurvivesFailureAndCanBeRetried() = runBlocking {
        val failure = FakeStudySubmissionService(failure = IOException("offline"))

        val firstResult = recoverPendingNetworkWork(
            preferences = preferences,
            appTokenStore = FakeAppTokenStore,
            submissionService = failure,
            onStudyStateChanged = {}
        )

        assertTrue(firstResult.isFailure)
        assertTrue(SharedPreferencesStudyProgressStore(context).read().hasPendingSubmission)

        val retry = FakeStudySubmissionService(SelfReportResponse.ProlificComplete)
        val retryResult = recoverPendingNetworkWork(
            preferences = preferences,
            appTokenStore = FakeAppTokenStore,
            submissionService = retry,
            onStudyStateChanged = {}
        )

        assertTrue(retryResult.isSuccess)
        assertSame(
            CompletionState.ProlificCompleted,
            SharedPreferencesStudyProgressStore(context).read().completionState
        )
    }

    @Test
    fun directCompletionStillConfirmsAndPersistsCode() = runBlocking {
        val code = "123e4567-e89b-42d3-a456-426614174000"
        val service = FakeStudySubmissionService(SelfReportResponse.DirectComplete(code))

        val result = recoverPendingNetworkWork(
            preferences = preferences,
            appTokenStore = FakeAppTokenStore,
            submissionService = service,
            onStudyStateChanged = {}
        )

        assertTrue(result.isSuccess)
        assertEquals(1, service.confirmationCount)
        assertEquals(
            CompletionState.DirectCompleted(code),
            SharedPreferencesStudyProgressStore(context).read().completionState
        )
    }

    @Test
    fun directConfirmationFailureRetriesConfirmationWithoutResubmittingReport() = runBlocking {
        val code = "123e4567-e89b-42d3-a456-426614174000"
        val failure = FakeStudySubmissionService(
            response = SelfReportResponse.DirectComplete(code),
            confirmationFailure = IOException("offline")
        )

        val firstResult = recoverPendingNetworkWork(
            preferences = preferences,
            appTokenStore = FakeAppTokenStore,
            submissionService = failure,
            onStudyStateChanged = {}
        )

        assertTrue(firstResult.isFailure)
        assertEquals(
            CompletionState.DirectPendingConfirmation(code),
            SharedPreferencesStudyProgressStore(context).read().completionState
        )

        val retry = FakeStudySubmissionService()
        val retryResult = recoverPendingNetworkWork(
            preferences = preferences,
            appTokenStore = FakeAppTokenStore,
            submissionService = retry,
            onStudyStateChanged = {}
        )

        assertTrue(retryResult.isSuccess)
        assertEquals(0, retry.submissionCount)
        assertEquals(1, retry.confirmationCount)
        assertEquals(
            CompletionState.DirectCompleted(code),
            SharedPreferencesStudyProgressStore(context).read().completionState
        )
    }

    private class FakeStudySubmissionService(
        private val response: SelfReportResponse? = null,
        private val failure: Throwable? = null,
        private val confirmationFailure: Throwable? = null
    ) : StudySubmissionService {
        var submissionCount = 0
        var confirmationCount = 0

        override suspend fun submitSelfReport(appToken: String, craving: Int): SelfReportResponse {
            submissionCount += 1
            failure?.let { throw it }
            return requireNotNull(response)
        }

        override suspend fun confirmCompensation(compensationCode: String) {
            confirmationCount += 1
            confirmationFailure?.let { throw it }
        }
    }

    private data object FakeAppTokenStore : AppTokenStore {
        override fun getAppToken(): String = "550e8400-e29b-41d4-a716-446655440000"
        override fun saveAppToken(appToken: String) = Unit
        override fun clear() = Unit
    }
}
