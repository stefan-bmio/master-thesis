package de.eachandevery.cuelens.prestudy

sealed interface ParticipantIdentifier {
    val value: String

    data class DirectEmail(override val value: String) : ParticipantIdentifier

    data class ProlificId(override val value: String) : ParticipantIdentifier

    companion object {
        fun parse(input: String): ParticipantIdentifier? {
            val value = input.trim()
            if (PROLIFIC_ID_PATTERN.matches(value)) {
                return ProlificId(value)
            }
            if (EMAIL_PATTERN.matches(value)) {
                return DirectEmail(value)
            }
            return null
        }

        private val PROLIFIC_ID_PATTERN = Regex("^[A-Za-z0-9]{24}$")
        private val EMAIL_PATTERN = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
    }
}
