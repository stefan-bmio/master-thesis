package de.eachandevery.cuelens.prestudy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

class StudyReminderDecisionTest {
    @Test
    fun noReminderIsCreatedBeforeFirstSituation() {
        val decision = decide(StudyProgress())

        assertSame(StudyReminderDecision.Skip, decision)
    }

    @Test
    fun firstConfirmedSituationSchedulesReminderForSecondSituation() {
        val decision = decide(
            StudyProgress(
                confirmedSituationCount = 1,
                nextSituationAvailableAtMillis = 11_000L
            ),
            expectedSituationNumber = 2
        )

        assertEquals(StudyReminderDecision.Reschedule(1_000L), decision)
    }

    @Test
    fun nineteenthConfirmedSituationSchedulesReminderForTwentiethSituation() {
        val decision = decide(
            StudyProgress(
                confirmedSituationCount = 19,
                nextSituationAvailableAtMillis = 12_000L
            ),
            expectedSituationNumber = 20
        )

        assertEquals(StudyReminderDecision.Reschedule(2_000L), decision)
    }

    @Test
    fun noReminderIsCreatedAfterTwentiethSituation() {
        val decision = decide(
            StudyProgress(
                confirmedSituationCount = 20,
                nextSituationAvailableAtMillis = 12_000L
            ),
            expectedSituationNumber = 20
        )

        assertSame(StudyReminderDecision.Skip, decision)
    }

    @Test
    fun earlyWorkerRunIsRescheduledForRemainingTime() {
        val decision = decide(
            StudyProgress(
                confirmedSituationCount = 4,
                nextSituationAvailableAtMillis = 15_500L
            ),
            expectedSituationNumber = 5
        )

        assertEquals(StudyReminderDecision.Reschedule(5_500L), decision)
    }

    @Test
    fun dueWorkerNotifiesOnlyForCurrentNextSituation() {
        val decision = decide(
            StudyProgress(
                confirmedSituationCount = 4,
                nextSituationAvailableAtMillis = 9_000L
            ),
            expectedSituationNumber = 5
        )

        assertEquals(StudyReminderDecision.Notify(5), decision)
    }

    @Test
    fun staleWorkerForPreviousSituationIsIgnored() {
        val decision = decide(
            StudyProgress(
                confirmedSituationCount = 5,
                nextSituationAvailableAtMillis = 9_000L
            ),
            expectedSituationNumber = 5
        )

        assertSame(StudyReminderDecision.Skip, decision)
    }

    @Test
    fun alreadyNotifiedSituationIsNotScheduledAgainWhenAppOpens() {
        val decision = decide(
            StudyProgress(
                confirmedSituationCount = 4,
                nextSituationAvailableAtMillis = 9_000L,
                lastNotifiedSituationNumber = 5
            ),
            expectedSituationNumber = 5
        )

        assertSame(StudyReminderDecision.Skip, decision)
    }

    @Test
    fun deniedNotificationsPendingTransferAndMissingActivationEachPreventReminder() {
        val progress = StudyProgress(
            confirmedSituationCount = 1,
            nextSituationAvailableAtMillis = 11_000L
        )

        assertSame(
            StudyReminderDecision.Skip,
            decide(progress, expectedSituationNumber = 2, notificationsAllowed = false)
        )
        assertSame(
            StudyReminderDecision.Skip,
            decide(progress.copy(hasPendingSubmission = true), expectedSituationNumber = 2)
        )
        assertSame(
            StudyReminderDecision.Skip,
            decide(progress, expectedSituationNumber = 2, appActivated = false)
        )
    }

    private fun decide(
        progress: StudyProgress,
        expectedSituationNumber: Int = 1,
        notificationsAllowed: Boolean = true,
        appActivated: Boolean = true
    ): StudyReminderDecision = studyReminderDecision(
        progress = progress,
        expectedSituationNumber = expectedSituationNumber,
        nowMillis = 10_000L,
        notificationsAllowed = notificationsAllowed,
        appActivated = appActivated
    )
}
