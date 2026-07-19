package de.eachandevery.cuelens.infofeed

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InfoFeedNotificationCheckerTest {
    @Test
    fun disabledNotificationsDoNotFetchMessages() = runBlocking {
        var fetched = false
        val checker = checker(
            preferences = preferences(enabled = false),
            service = service { fetched = true; emptyList() }
        )

        assertEquals(InfoFeedCheckResult.Success, checker.check())
        assertFalse(fetched)
    }

    @Test
    fun onlyUnknownAndNonDismissedMessagesTriggerOneNotification() = runBlocking {
        val preferenceStore = FakeNotificationStore(
            preferences(enabled = true, knownIds = setOf(1L))
        )
        val dismissedStore = FakeDismissedStore(setOf(2L))
        val notifier = FakeNotifier(canPost = true)
        val checker = checker(
            preferenceStore = preferenceStore,
            dismissedStore = dismissedStore,
            notifier = notifier,
            service = service {
                listOf(message(1L), message(2L), message(3L), message(4L))
            }
        )

        assertEquals(InfoFeedCheckResult.Success, checker.check())
        assertEquals(1, notifier.postCount)
        assertEquals(setOf(1L, 2L, 3L, 4L), preferenceStore.value.knownMessageIds)
    }

    @Test
    fun missingSystemPermissionStillMarksMessagesKnown() = runBlocking {
        val preferenceStore = FakeNotificationStore(preferences(enabled = true))
        val notifier = FakeNotifier(canPost = false)
        val checker = checker(
            preferenceStore = preferenceStore,
            notifier = notifier,
            service = service { listOf(message(5L)) }
        )

        assertEquals(InfoFeedCheckResult.Success, checker.check())
        assertEquals(0, notifier.postCount)
        assertEquals(setOf(5L), preferenceStore.value.knownMessageIds)
    }

    @Test
    fun alreadyKnownMessagesDoNotNotifyAgain() = runBlocking {
        val notifier = FakeNotifier(canPost = true)
        val checker = checker(
            preferences = preferences(enabled = true, knownIds = setOf(8L)),
            notifier = notifier,
            service = service { listOf(message(8L)) }
        )

        assertEquals(InfoFeedCheckResult.Success, checker.check())
        assertEquals(0, notifier.postCount)
    }

    @Test
    fun networkAndServerErrorsRequestRetry() = runBlocking {
        val networkChecker = checker(
            preferences = preferences(enabled = true),
            service = failingService(InfoFeedNetworkException(java.io.IOException("offline")))
        )
        val serverChecker = checker(
            preferences = preferences(enabled = true),
            service = failingService(InfoFeedHttpException(500, "Server error."))
        )

        assertEquals(InfoFeedCheckResult.Retry, networkChecker.check())
        assertEquals(InfoFeedCheckResult.Retry, serverChecker.check())
    }

    @Test
    fun clientAndProtocolErrorsWaitForNextPeriodicRun() = runBlocking {
        val clientChecker = checker(
            preferences = preferences(enabled = true),
            service = failingService(InfoFeedHttpException(400, "Bad request."))
        )
        val protocolChecker = checker(
            preferences = preferences(enabled = true),
            service = failingService(InfoFeedProtocolException("invalid"))
        )

        assertEquals(InfoFeedCheckResult.Success, clientChecker.check())
        assertEquals(InfoFeedCheckResult.Success, protocolChecker.check())
    }

    private fun checker(
        preferences: InfoNotificationPreferences = preferences(enabled = true),
        preferenceStore: FakeNotificationStore = FakeNotificationStore(preferences),
        dismissedStore: FakeDismissedStore = FakeDismissedStore(),
        notifier: FakeNotifier = FakeNotifier(canPost = true),
        service: InfoFeedService
    ) = InfoFeedNotificationChecker(
        service = service,
        dismissedMessageStore = dismissedStore,
        notificationPreferenceStore = preferenceStore,
        notifier = notifier
    )

    private fun preferences(
        enabled: Boolean,
        knownIds: Set<Long> = emptySet()
    ) = InfoNotificationPreferences(
        promptCompleted = true,
        enabled = enabled,
        knownMessageIds = knownIds
    )

    private fun service(block: suspend () -> List<InfoMessage>) =
        object : InfoFeedService {
            override suspend fun fetchMessages() = block()
        }

    private fun failingService(error: InfoFeedException) = service { throw error }

    private fun message(id: Long) = InfoMessage(
        id = id,
        createdAtUtc = "2026-07-07T20:00:00Z",
        textDe = "Deutsch",
        textEn = "English"
    )

    private class FakeDismissedStore(initialIds: Set<Long> = emptySet()) :
        DismissedMessageStore {
        private val state = MutableStateFlow(initialIds)
        override val dismissedIds: Flow<Set<Long>> = state
        override suspend fun getDismissedIds(): Set<Long> = state.value
        override suspend fun dismiss(messageId: Long) {
            state.value += messageId
        }
    }

    private class FakeNotificationStore(
        initialPreferences: InfoNotificationPreferences
    ) : InfoNotificationPreferenceStore {
        var value = initialPreferences
        override suspend fun getPreferences() = value
        override suspend fun completePrompt(enabled: Boolean) {
            value = value.copy(promptCompleted = true, enabled = enabled)
        }
        override suspend fun markMessagesKnown(messageIds: Set<Long>) {
            value = value.copy(knownMessageIds = value.knownMessageIds + messageIds)
        }
    }

    private class FakeNotifier(private val canPost: Boolean) : InfoFeedNotifier {
        var postCount = 0
        override fun canPostNotifications() = canPost
        override fun postNewInformationNotification() {
            postCount += 1
        }
    }
}
