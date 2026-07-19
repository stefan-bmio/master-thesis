package de.eachandevery.cuelens.infofeed

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class InfoFeedRepositoryTest {
    @Test
    fun loadMessagesFetchesAllMessagesAndFiltersAndSortsDefensively() = runBlocking {
        val store = FakeDismissedMessageStore(setOf(2L))
        var fetchCount = 0
        val service = object : InfoFeedService {
            override suspend fun fetchMessages(): List<InfoMessage> {
                fetchCount += 1
                return listOf(
                    message(3L, "2026-07-08T10:00:00Z"),
                    message(2L, "2026-07-06T10:00:00Z"),
                    message(4L, "2026-07-07T10:00:00Z"),
                    message(1L, "2026-07-07T10:00:00Z")
                )
            }
        }
        val repository = InfoFeedRepository(service, store)

        val result = repository.loadMessages()

        assertTrue(result.isSuccess)
        assertEquals(1, fetchCount)
        assertEquals(listOf(1L, 4L, 3L), result.getOrThrow().map(InfoMessage::id))
    }

    @Test
    fun loadMessagesReturnsNetworkFailure() = runBlocking {
        val expected = InfoFeedNetworkException(java.io.IOException("offline"))
        val service = object : InfoFeedService {
            override suspend fun fetchMessages(): List<InfoMessage> {
                throw expected
            }
        }
        val repository = InfoFeedRepository(service, FakeDismissedMessageStore())

        val result = repository.loadMessages()

        assertTrue(result.isFailure)
        assertEquals(expected, result.exceptionOrNull())
    }

    @Test
    fun dismissDelegatesToPersistentStore() = runBlocking {
        val store = FakeDismissedMessageStore()
        val repository = InfoFeedRepository(
            service = object : InfoFeedService {
                override suspend fun fetchMessages() = emptyList<InfoMessage>()
            },
            dismissedMessageStore = store
        )

        repository.dismiss(7L)

        assertEquals(setOf(7L), store.getDismissedIds())
    }

    private fun message(id: Long, createdAtUtc: String) = InfoMessage(
        id = id,
        createdAtUtc = createdAtUtc,
        textDe = "Deutsch $id",
        textEn = "English $id"
    )

    private class FakeDismissedMessageStore(
        initialIds: Set<Long> = emptySet()
    ) : DismissedMessageStore {
        private val state = MutableStateFlow(initialIds)

        override val dismissedIds: Flow<Set<Long>> = state

        override suspend fun getDismissedIds(): Set<Long> = state.value

        override suspend fun dismiss(messageId: Long) {
            state.value += messageId
        }
    }
}
