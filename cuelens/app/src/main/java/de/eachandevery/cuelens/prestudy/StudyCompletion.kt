package de.eachandevery.cuelens.prestudy

import org.json.JSONObject

enum class CompletionMode(val persistedValue: String) {
    CompensationCode("COMPENSATION_CODE"),
    ProlificManual("PROLIFIC_MANUAL")
}

sealed interface CompletionState {
    data object Incomplete : CompletionState
    data object Invalid : CompletionState
    data class DirectPendingConfirmation(val code: String) : CompletionState
    data class DirectCompleted(val code: String) : CompletionState
    data object ProlificCompleted : CompletionState
}

val CompletionState.isCompleted: Boolean
    get() = this is CompletionState.DirectCompleted || this is CompletionState.ProlificCompleted

val CompletionState.completionMode: CompletionMode?
    get() = when (this) {
        is CompletionState.DirectPendingConfirmation,
        is CompletionState.DirectCompleted -> CompletionMode.CompensationCode
        CompletionState.ProlificCompleted -> CompletionMode.ProlificManual
        CompletionState.Incomplete,
        CompletionState.Invalid -> null
    }

val CompletionState.compensationCode: String?
    get() = when (this) {
        is CompletionState.DirectPendingConfirmation -> code
        is CompletionState.DirectCompleted -> code
        CompletionState.Incomplete,
        CompletionState.Invalid,
        CompletionState.ProlificCompleted -> null
    }

val CompletionState.requiresRecovery: Boolean
    get() = this is CompletionState.DirectPendingConfirmation || this is CompletionState.Invalid

internal fun decodeCompletionState(
    completed: Boolean,
    rawCompensationCode: String?,
    rawCompletionMode: String?
): CompletionState {
    if (rawCompensationCode != null && rawCompensationCode.isBlank()) {
        return CompletionState.Invalid
    }
    val code = rawCompensationCode?.takeIf(String::isNotBlank)
    if (code != null && !COMPENSATION_UUID_V4.matches(code)) {
        return CompletionState.Invalid
    }

    return when (rawCompletionMode) {
        null -> when {
            code != null && completed -> CompletionState.DirectCompleted(code)
            code != null -> CompletionState.DirectPendingConfirmation(code)
            completed -> CompletionState.Invalid
            else -> CompletionState.Incomplete
        }
        CompletionMode.CompensationCode.persistedValue -> when {
            code == null -> CompletionState.Invalid
            completed -> CompletionState.DirectCompleted(code)
            else -> CompletionState.DirectPendingConfirmation(code)
        }
        CompletionMode.ProlificManual.persistedValue -> when {
            code != null || !completed -> CompletionState.Invalid
            else -> CompletionState.ProlificCompleted
        }
        else -> CompletionState.Invalid
    }
}

internal sealed interface SelfReportResponse {
    data class Next(val situationIndex: Int) : SelfReportResponse
    data class DirectComplete(val compensationCode: String) : SelfReportResponse
    data object ProlificComplete : SelfReportResponse
}

internal class StudyProtocolException : IllegalStateException("Unexpected study response.")

internal object SelfReportResponseParser {
    fun parse(response: JSONObject): SelfReportResponse {
        if (response.opt("success") != true) throw StudyProtocolException()

        val situationIndex = response.requiredInteger("situation_index")
        val conditionCode = response.requiredString("condition_code")
        val hasStatus = response.has("status")
        val hasCompletionMode = response.has("completion_mode")
        val hasCompensationCode = response.has("compensation_code")
        val status = response.optionalString("status")
        val completionMode = response.optionalString("completion_mode")
        val compensationCode = response.optionalString("compensation_code")

        if (status == "complete") {
            if (situationIndex != TOTAL_STUDY_SITUATIONS || conditionCode != "CUE_LABELING") {
                throw StudyProtocolException()
            }
            return when {
                hasCompletionMode &&
                    completionMode == CompletionMode.ProlificManual.persistedValue &&
                    !hasCompensationCode -> SelfReportResponse.ProlificComplete
                !hasCompletionMode && hasCompensationCode && compensationCode != null &&
                    COMPENSATION_UUID_V4.matches(compensationCode) ->
                    SelfReportResponse.DirectComplete(compensationCode.lowercase())
                else -> throw StudyProtocolException()
            }
        }

        if (
            hasStatus ||
            hasCompletionMode ||
            hasCompensationCode ||
            situationIndex !in 1 until TOTAL_STUDY_SITUATIONS ||
            conditionCode != expectedConditionCode(situationIndex)
        ) {
            throw StudyProtocolException()
        }
        return SelfReportResponse.Next(situationIndex)
    }

    private fun JSONObject.requiredInteger(key: String): Int {
        val value = opt(key) as? Number ?: throw StudyProtocolException()
        val integer = value.toInt()
        if (value.toDouble() != integer.toDouble()) throw StudyProtocolException()
        return integer
    }

    private fun JSONObject.requiredString(key: String): String =
        optionalString(key) ?: throw StudyProtocolException()

    private fun JSONObject.optionalString(key: String): String? {
        if (!has(key) || isNull(key)) return null
        return (opt(key) as? String)?.takeIf(String::isNotBlank)
            ?: throw StudyProtocolException()
    }

    private fun expectedConditionCode(situationIndex: Int): String =
        if (situationIndex <= 10) "CUE_MATCHING" else "CUE_LABELING"

}

private val COMPENSATION_UUID_V4 = Regex(
    "^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-4[a-fA-F0-9]{3}-[89aAbB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$"
)
