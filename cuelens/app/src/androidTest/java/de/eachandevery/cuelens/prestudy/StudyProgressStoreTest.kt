package de.eachandevery.cuelens.prestudy

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class StudyProgressStoreTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val preferences by lazy {
        context.getSharedPreferences(STUDY_PREFERENCES_NAME, Context.MODE_PRIVATE)
    }

    @Before
    fun clearBeforeTest() {
        assertTrue(preferences.edit().clear().commit())
    }

    @After
    fun clearAfterTest() {
        preferences.edit().clear().commit()
    }

    @Test
    fun legacyCompensationCodeIsMigratedAndSurvivesStoreRecreation() {
        val code = "123e4567-e89b-42d3-a456-426614174000"
        assertTrue(
            preferences.edit()
                .putString(KEY_COMPENSATION_CODE, code)
                .putBoolean(KEY_STUDY_COMPLETED, true)
                .commit()
        )

        val firstRead = SharedPreferencesStudyProgressStore(context).read()
        val secondRead = SharedPreferencesStudyProgressStore(context).read()

        assertEquals(CompletionState.DirectCompleted(code), firstRead.completionState)
        assertEquals(firstRead, secondRead)
        assertEquals(
            CompletionMode.CompensationCode.persistedValue,
            preferences.getString(KEY_COMPLETION_MODE, null)
        )
    }

    @Test
    fun prolificCompletionIsPersistedAtomicallyAcrossStoreRecreation() {
        assertTrue(
            preferences.edit()
                .putInt(KEY_CONFIRMED_SITUATION_COUNT, 19)
                .putInt(KEY_PENDING_SUBMISSION_CRAVING, 50)
                .commit()
        )

        persistProlificCompletion(preferences)

        val progress = SharedPreferencesStudyProgressStore(context).read()
        assertSame(CompletionState.ProlificCompleted, progress.completionState)
        assertTrue(progress.completed)
        assertFalse(progress.hasPendingSubmission)
        assertEquals(TOTAL_STUDY_SITUATIONS, progress.confirmedSituationCount)
        assertFalse(preferences.contains(KEY_COMPENSATION_CODE))
        assertFalse(preferences.contains(KEY_PENDING_SUBMISSION_CRAVING))
    }

    @Test
    fun completedStateWithPendingSubmissionFailsClosed() {
        assertTrue(
            preferences.edit()
                .putString(KEY_COMPLETION_MODE, CompletionMode.ProlificManual.persistedValue)
                .putBoolean(KEY_STUDY_COMPLETED, true)
                .putInt(KEY_PENDING_SUBMISSION_CRAVING, 50)
                .commit()
        )

        val progress = SharedPreferencesStudyProgressStore(context).read()

        assertSame(CompletionState.Invalid, progress.completionState)
        assertFalse(progress.completed)
        assertTrue(progress.hasPendingSubmission)
    }
}
