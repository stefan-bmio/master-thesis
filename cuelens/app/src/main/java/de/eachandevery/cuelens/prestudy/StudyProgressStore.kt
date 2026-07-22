package de.eachandevery.cuelens.prestudy

import android.content.Context

data class StudyProgress(
    val confirmedSituationCount: Int = 0,
    val nextSituationAvailableAtMillis: Long = 0L,
    val hasPendingSubmission: Boolean = false,
    val completed: Boolean = false,
    val compensationCode: String? = null
) {
    fun canStart(nowMillis: Long): Boolean =
        !completed &&
            confirmedSituationCount < TOTAL_STUDY_SITUATIONS &&
            !hasPendingSubmission &&
            nextSituationAvailableAtMillis <= nowMillis
}

fun interface StudyProgressStore {
    fun read(): StudyProgress
}

class SharedPreferencesStudyProgressStore(context: Context) : StudyProgressStore {
    private val preferences = context.getSharedPreferences(STUDY_PREFERENCES_NAME, Context.MODE_PRIVATE)

    override fun read(): StudyProgress {
        val compensationCode = preferences.getString(KEY_COMPENSATION_CODE, null)
        val completed = preferences.getBoolean(KEY_STUDY_COMPLETED, false)
        return StudyProgress(
            confirmedSituationCount = preferences.getInt(KEY_CONFIRMED_SITUATION_COUNT, 0),
            nextSituationAvailableAtMillis = preferences.getLong(
                KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS,
                0L
            ),
            hasPendingSubmission = preferences.getInt(
                KEY_PENDING_SUBMISSION_CRAVING,
                NO_PENDING_CRAVING
            ) != NO_PENDING_CRAVING || (!compensationCode.isNullOrBlank() && !completed),
            completed = completed,
            compensationCode = compensationCode?.takeIf { it.isNotBlank() }
        )
    }
}

const val STUDY_PREFERENCES_NAME = "cue_lens_state"
const val KEY_CONFIRMED_SITUATION_COUNT = "confirmed_situation_count"
const val KEY_NEXT_SITUATION_AVAILABLE_AT_MILLIS = "next_situation_available_at_millis"
const val KEY_MATCHING_ORDER = "matching_order"
const val KEY_PENDING_SUBMISSION_CRAVING = "pending_submission_craving"
const val KEY_COMPENSATION_CODE = "compensation_code"
const val KEY_STUDY_COMPLETED = "study_completed"
const val NO_PENDING_CRAVING = -1
const val TOTAL_STUDY_SITUATIONS = 20
