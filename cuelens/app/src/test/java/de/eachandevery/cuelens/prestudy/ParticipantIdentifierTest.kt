package de.eachandevery.cuelens.prestudy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ParticipantIdentifierTest {
    @Test
    fun acceptsProlificIdsAndPreservesCase() {
        val cases = listOf(
            "AbCdEf1234567890GhIjKlMn" to "AbCdEf1234567890GhIjKlMn",
            " \tAbCdEf1234567890GhIjKlMn\r\n" to "AbCdEf1234567890GhIjKlMn",
            "123456789012345678901234" to "123456789012345678901234"
        )

        cases.forEach { (input, expected) ->
            val identifier = ParticipantIdentifier.parse(input)

            assertTrue(identifier is ParticipantIdentifier.ProlificId)
            assertEquals(expected, identifier?.value)
        }
    }

    @Test
    fun acceptsEmailWithoutChangingItsSpelling() {
        val identifier = ParticipantIdentifier.parse("  Participant@Example.ORG  ")

        assertTrue(identifier is ParticipantIdentifier.DirectEmail)
        assertEquals("Participant@Example.ORG", identifier?.value)
    }

    @Test
    fun rejectsSameInvalidValuesAsServerParser() {
        val invalidIdentifiers = listOf(
            "",
            "   ",
            "AbCdEf1234567890GhIjKlM",
            "AbCdEf1234567890GhIjKlMnO",
            "AbCdEf123456 7890GhIjKlM",
            "AbCdEf1234567890GhIjKlM-",
            "AbCdEf1234567890GhIjKlMö",
            "AbCdEf123456\n890GhIjKlMn",
            "participant@example"
        )

        invalidIdentifiers.forEach { input ->
            assertNull("Expected rejection for: $input", ParticipantIdentifier.parse(input))
        }
    }
}
