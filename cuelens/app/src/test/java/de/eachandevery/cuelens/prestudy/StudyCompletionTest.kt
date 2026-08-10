package de.eachandevery.cuelens.prestudy

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class StudyCompletionTest {
    @Test
    fun parsesExistingDirectCompletionResponse() {
        val response = SelfReportResponseParser.parse(
            JSONObject(
                """{
                    "success":true,
                    "status":"complete",
                    "situation_index":20,
                    "condition_code":"CUE_LABELING",
                    "compensation_code":"123E4567-E89B-42D3-A456-426614174000"
                }""".trimIndent()
            )
        )

        assertEquals(
            SelfReportResponse.DirectComplete("123e4567-e89b-42d3-a456-426614174000"),
            response
        )
    }

    @Test
    fun parsesProlificCompletionWithoutCompensationCode() {
        val response = SelfReportResponseParser.parse(
            JSONObject(
                """{
                    "success":true,
                    "status":"complete",
                    "situation_index":20,
                    "condition_code":"CUE_LABELING",
                    "completion_mode":"PROLIFIC_MANUAL"
                }""".trimIndent()
            )
        )

        assertSame(SelfReportResponse.ProlificComplete, response)
    }

    @Test
    fun parsesOngoingResponseOnlyWithConsistentSituationAndCondition() {
        assertEquals(
            SelfReportResponse.Next(10),
            SelfReportResponseParser.parse(
                JSONObject(
                    """{
                        "success":true,
                        "situation_index":10,
                        "condition_code":"CUE_MATCHING"
                    }""".trimIndent()
                )
            )
        )
        assertEquals(
            SelfReportResponse.Next(11),
            SelfReportResponseParser.parse(
                JSONObject(
                    """{
                        "success":true,
                        "situation_index":11,
                        "condition_code":"CUE_LABELING"
                    }""".trimIndent()
                )
            )
        )
    }

    @Test
    fun rejectsInconsistentOrUnsuccessfulResponses() {
        val invalidResponses = listOf(
            // Direct completion without a code.
            """{"success":true,"status":"complete","situation_index":20,"condition_code":"CUE_LABELING"}""",
            // Prolific completion with a code.
            """{"success":true,"status":"complete","situation_index":20,"condition_code":"CUE_LABELING","completion_mode":"PROLIFIC_MANUAL","compensation_code":"123e4567-e89b-42d3-a456-426614174000"}""",
            // Unknown completion mode.
            """{"success":true,"status":"complete","situation_index":20,"condition_code":"CUE_LABELING","completion_mode":"OTHER"}""",
            """{"success":true,"status":"complete","situation_index":20,"condition_code":"CUE_LABELING","completion_mode":"PROLIFIC_MANUAL","compensation_code":null}""",
            // Failed and malformed ongoing responses.
            """{"success":false,"situation_index":1,"condition_code":"CUE_MATCHING"}""",
            """{"success":true,"situation_index":11,"condition_code":"CUE_MATCHING"}""",
            """{"success":true,"situation_index":20,"condition_code":"CUE_LABELING"}"""
        )

        invalidResponses.forEach { json ->
            assertTrue(
                runCatching { SelfReportResponseParser.parse(JSONObject(json)) }
                    .exceptionOrNull() is StudyProtocolException
            )
        }
    }

    @Test
    fun legacyCodeIsMigratedInMemoryToDirectCompletionMode() {
        val completed = decodeCompletionState(
            completed = true,
            rawCompensationCode = "123e4567-e89b-42d3-a456-426614174000",
            rawCompletionMode = null
        )
        val pending = decodeCompletionState(
            completed = false,
            rawCompensationCode = "123e4567-e89b-42d3-a456-426614174000",
            rawCompletionMode = null
        )

        assertTrue(completed is CompletionState.DirectCompleted)
        assertEquals(CompletionMode.CompensationCode, completed.completionMode)
        assertTrue(pending is CompletionState.DirectPendingConfirmation)
        assertTrue(pending.requiresRecovery)
    }

    @Test
    fun missingOrContradictoryCompletionStateFailsClosed() {
        val invalidStates = listOf(
            decodeCompletionState(true, null, null),
            decodeCompletionState(true, null, "COMPENSATION_CODE"),
            decodeCompletionState(true, "code", "PROLIFIC_MANUAL"),
            decodeCompletionState(false, null, "PROLIFIC_MANUAL"),
            decodeCompletionState(true, null, "UNKNOWN"),
            decodeCompletionState(true, "not-a-code", "COMPENSATION_CODE")
        )

        invalidStates.forEach { state ->
            assertSame(CompletionState.Invalid, state)
            assertFalse(state.isCompleted)
            assertTrue(state.requiresRecovery)
        }
    }

    @Test
    fun explicitProlificCompletionStateIsRecognized() {
        val state = decodeCompletionState(
            completed = true,
            rawCompensationCode = null,
            rawCompletionMode = "PROLIFIC_MANUAL"
        )

        assertSame(CompletionState.ProlificCompleted, state)
        assertEquals(CompletionMode.ProlificManual, state.completionMode)
        assertTrue(state.isCompleted)
    }
}
