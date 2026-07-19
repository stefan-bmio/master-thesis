package de.eachandevery.cuelens.infofeed

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InfoFeedControllerTest {
    @Test
    fun emptyFeedFinishesImmediately() = runBlocking {
        val controller = controllerWith(messages = emptyList())

        controller.load()

        val finished = controller.state.value as InfoFeedUiState.Finished
        assertTrue(finished.feedLoaded)
        assertTrue(finished.observedMessageIds.isEmpty())
    }

    @Test
    fun loadFailureFinishesWithNotice() = runBlocking {
        val store = FakeStore()
        val service = object : InfoFeedService {
            override suspend fun fetchMessages(): List<InfoMessage> {
                throw InfoFeedNetworkException(java.io.IOException("offline"))
            }
        }
        val controller = InfoFeedController(InfoFeedRepository(service, store))

        controller.load()

        val finished = controller.state.value as InfoFeedUiState.Finished
        assertFalse(finished.feedLoaded)
        assertEquals(InfoFeedNoticeType.LoadFailed, finished.notice?.type)
    }

    @Test
    fun confirmWithoutCheckboxAdvancesWithoutPersistingId() = runBlocking {
        val store = FakeStore()
        val controller = controllerWith(messages = listOf(message(1L), message(2L)), store = store)
        controller.load()

        controller.confirm()

        val showing = controller.state.value as InfoFeedUiState.ShowingMessage
        assertEquals(2L, showing.currentMessage.id)
        assertTrue(store.ids.value.isEmpty())
    }

    @Test
    fun confirmWithCheckboxPersistsIdAndFinishes() = runBlocking {
        val store = FakeStore()
        val controller = controllerWith(messages = listOf(message(7L)), store = store)
        controller.load()
        controller.setHidePermanently(true)

        controller.confirm()

        assertEquals(setOf(7L), store.ids.value)
        val finished = controller.state.value as InfoFeedUiState.Finished
        assertEquals(setOf(7L), finished.observedMessageIds)
    }

    @Test
    fun backShowsPreviousMessageThenFinishesFeed() = runBlocking {
        val controller = controllerWith(messages = listOf(message(1L), message(2L)))
        controller.load()
        controller.confirm()

        controller.back()

        val firstMessage = controller.state.value as InfoFeedUiState.ShowingMessage
        assertEquals(1L, firstMessage.currentMessage.id)
        assertFalse(firstMessage.hidePermanently)

        controller.back()

        val finished = controller.state.value as InfoFeedUiState.Finished
        assertEquals(setOf(1L, 2L), finished.observedMessageIds)
    }

    @Test
    fun persistenceFailureStillAdvancesAndShowsNotice() = runBlocking {
        val store = FakeStore(failOnDismiss = true)
        val controller = controllerWith(messages = listOf(message(1L), message(2L)), store = store)
        controller.load()
        controller.setHidePermanently(true)

        controller.confirm()

        val showing = controller.state.value as InfoFeedUiState.ShowingMessage
        assertEquals(2L, showing.currentMessage.id)
        assertEquals(InfoFeedNoticeType.DismissFailed, showing.notice?.type)
    }

    private fun controllerWith(
        messages: List<InfoMessage>,
        store: FakeStore = FakeStore()
    ): InfoFeedController {
        val service = object : InfoFeedService {
            override suspend fun fetchMessages(): List<InfoMessage> = messages
        }
        return InfoFeedController(InfoFeedRepository(service, store))
    }

    private fun message(id: Long) = InfoMessage(
        id = id,
        createdAtUtc = "2026-07-%02dT10:00:00Z".format(id),
        textDe = "Deutsch $id",
        textEn = "English $id"
    )

    private class FakeStore(
        initialIds: Set<Long> = emptySet(),
        private val failOnDismiss: Boolean = false
    ) : DismissedMessageStore {
        val ids = MutableStateFlow(initialIds)

        override val dismissedIds: Flow<Set<Long>> = ids

        override suspend fun getDismissedIds(): Set<Long> = ids.value

        override suspend fun dismiss(messageId: Long) {
            if (failOnDismiss) throw java.io.IOException("write failed")
            ids.value += messageId
        }
    }
}
