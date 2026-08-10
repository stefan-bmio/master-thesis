package de.eachandevery.cuelens.prestudy

import android.content.Context
import android.content.SharedPreferences

data class StudyProgress(
    val confirmedSituationCount: Int = 0,
    val nextSituationAvailableAtMillis: Long = 0L,
    val lastNotifiedSituationNumber: Int = 0,
    val hasPendingSubmission: Boolean = false,
    val completionState: CompletionState = CompletionState.Incomplete
) {
    val completed: Boolean
        get() = completionState.isCompleted

    val compensationCode: String?
        get() = completionState.compensationCode

    val completionMode: CompletionMode?
        get() = completionState.completionMode

    fun canStart(nowMillis: Long): Boolean =
        !completed &&
            confirmedSituationCount < TOTAL_STUDY_SITUATIONS &&
            !hasPendingSubmission &&
            nextSituationAvailableAtMillis <= nowMillis
}

fun interface StudyProgressStore {
    fun read(): StudyProgress
}

class SharedPreferencesStudyProgressStore internal constructor(
    private val preferences: SharedPreferences
) : StudyProgressStore {
    constructor(context: Context) : this(
        context.getSharedPreferences(STUDY_PREFERENCES_NAME, Context.MODE_PRIVATE)
    )

    override fun read(): StudyProgress {
        val compensationCode = preferences.getString(KEY_COMPENSATION_CODE, null)
        val completed = preferences.getBoolean(KEY_STUDY_COMPLETED, false)
        val rawCompletionMode = preferences.getString(KEY_COMPLETION_MODE, null)
        val pendingCraving = preferences.getInt(
            KEY_PENDING_SUBMISSION_CRAVING,
            NO_PENDING_CRAVING
        )
        val decodedCompletionState = decodeCompletionState(
            completed = completed,
            rawCompensationCode = compensationCode,
            rawCompletionMode = rawCompletionMode
        )
        val completionState = if (
            pendingCraving != NO_PENDING_CRAVING && decodedCompletionState.isCompleted
        ) {
            CompletionState.Invalid
        } else {
            decodedCompletionState
        }
        if (
            rawCompletionMode == null &&
            decodedCompletionState.completionMode == CompletionMode.CompensationCode
        ) {
            requireStudyProgressCommit(
                preferences.edit()
                    .putString(
                        KEY_COMPLETION_MODE,
                        CompletionMode.CompensationCode.persistedValue
                    )
                    .commit()
            )
        }
        return StudyProgress(
            confirmedSituationCount = preferences.getInt(KEY_CONFIRMED_SITUATION_COUNT, 0),
            nextSituationAvailableAtMillis = preferences.getLong(
                KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS,
                0L
            ),
            lastNotifiedSituationNumber = preferences.getInt(
                KEY_LAST_NOTIFIED_SITUATION_NUMBER,
                0
            ),
            hasPendingSubmission = pendingCraving != NO_PENDING_CRAVING ||
                completionState.requiresRecovery,
            completionState = completionState
        )
    }
}

const val STUDY_PREFERENCES_NAME = "cue_lens_state"
const val KEY_CONFIRMED_SITUATION_COUNT = "confirmed_situation_count"
const val KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS = "next_situation_available_at_millis"
const val KEY_LAST_NOTIFIED_SITUATION_NUMBER = "last_notified_situation_number"
const val KEY_MATCHING_ORDER = "matching_order"
const val KEY_PENDING_SUBMISSION_CRAVING = "pending_submission_craving"
const val KEY_COMPENSATION_CODE = "compensation_code"
const val KEY_STUDY_COMPLETED = "study_completed"
const val KEY_COMPLETION_MODE = "completion_mode"
const val NO_PENDING_CRAVING = -1
const val TOTAL_STUDY_SITUATIONS = 20

internal class StudyProgressPersistenceException : IllegalStateException(
    "Study progress could not be persisted."
)

internal fun persistDirectCompletionPending(
    preferences: SharedPreferences,
    compensationCode: String
) {
    requireStudyProgressCommit(
        preferences.edit()
            .putString(KEY_COMPLETION_MODE, CompletionMode.CompensationCode.persistedValue)
            .putString(KEY_COMPENSATION_CODE, compensationCode)
            .putBoolean(KEY_STUDY_COMPLETED, false)
            .remove(KEY_PENDING_SUBMISSION_CRAVING)
            .commit()
    )
}

internal fun persistDirectCompletionConfirmed(
    preferences: SharedPreferences,
    compensationCode: String
) {
    requireStudyProgressCommit(
        preferences.edit()
            .putString(KEY_COMPLETION_MODE, CompletionMode.CompensationCode.persistedValue)
            .putString(KEY_COMPENSATION_CODE, compensationCode)
            .putBoolean(KEY_STUDY_COMPLETED, true)
            .putInt(KEY_CONFIRMED_SITUATION_COUNT, TOTAL_STUDY_SITUATIONS)
            .remove(KEY_PENDING_SUBMISSION_CRAVING)
            .commit()
    )
}

internal fun persistProlificCompletion(preferences: SharedPreferences) {
    requireStudyProgressCommit(
        preferences.edit()
            .putString(KEY_COMPLETION_MODE, CompletionMode.ProlificManual.persistedValue)
            .remove(KEY_COMPENSATION_CODE)
            .putBoolean(KEY_STUDY_COMPLETED, true)
            .putInt(KEY_CONFIRMED_SITUATION_COUNT, TOTAL_STUDY_SITUATIONS)
            .remove(KEY_PENDING_SUBMISSION_CRAVING)
            .commit()
    )
}

private fun requireStudyProgressCommit(committed: Boolean) {
    if (!committed) throw StudyProgressPersistenceException()
}
