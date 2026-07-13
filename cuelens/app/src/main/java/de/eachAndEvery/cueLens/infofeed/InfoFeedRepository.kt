package de.eachAndEvery.cueLens.infofeed

import android.content.Context
import de.eachAndEvery.cueLens.BuildConfig

class InfoFeedRepository(
    private val service: InfoFeedService,
    private val dismissedMessageStore: DismissedMessageStore
) {
    suspend fun loadMessages(): Result<List<InfoMessage>> = runCatching {
        val dismissedIds = dismissedMessageStore.getDismissedIds()
        service.fetchMessages()
            .asSequence()
            .filterNot { it.id in dismissedIds }
            .sortedWith(compareBy(InfoMessage::createdAtUtc, InfoMessage::id))
            .toList()
    }

    suspend fun dismiss(messageId: Long) {
        dismissedMessageStore.dismiss(messageId)
    }

    companion object {
        fun create(context: Context): InfoFeedRepository = InfoFeedRepository(
            service = HttpInfoFeedService(BuildConfig.MESSAGES_URL),
            dismissedMessageStore = DataStoreDismissedMessageStore(context.applicationContext)
        )
    }
}
