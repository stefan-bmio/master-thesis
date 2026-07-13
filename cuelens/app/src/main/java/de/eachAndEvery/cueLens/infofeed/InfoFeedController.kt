package de.eachAndEvery.cueLens.infofeed

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class InfoFeedNoticeType {
    LoadFailed,
    DismissFailed
}

data class InfoFeedNotice(
    val id: Long,
    val type: InfoFeedNoticeType
)

sealed interface InfoFeedUiState {
    data object Loading : InfoFeedUiState

    data class ShowingMessage(
        val messages: List<InfoMessage>,
        val index: Int,
        val hidePermanently: Boolean = false,
        val isConfirming: Boolean = false,
        val notice: InfoFeedNotice? = null
    ) : InfoFeedUiState {
        val currentMessage: InfoMessage
            get() = messages[index]
    }

    data class Finished(
        val feedLoaded: Boolean,
        val observedMessageIds: Set<Long> = emptySet(),
        val notice: InfoFeedNotice? = null
    ) : InfoFeedUiState
}

class InfoFeedController(
    private val repository: InfoFeedRepository
) {
    private val mutableState = MutableStateFlow<InfoFeedUiState>(InfoFeedUiState.Loading)
    val state: StateFlow<InfoFeedUiState> = mutableState.asStateFlow()
    private var nextNoticeId = 1L

    suspend fun load() {
        mutableState.value = InfoFeedUiState.Loading
        repository.loadMessages().fold(
            onSuccess = { messages ->
                mutableState.value = if (messages.isEmpty()) {
                    InfoFeedUiState.Finished(feedLoaded = true)
                } else {
                    InfoFeedUiState.ShowingMessage(messages = messages, index = 0)
                }
            },
            onFailure = {
                mutableState.value = InfoFeedUiState.Finished(
                    feedLoaded = false,
                    notice = notice(InfoFeedNoticeType.LoadFailed)
                )
            }
        )
    }

    fun setHidePermanently(checked: Boolean) {
        val current = mutableState.value as? InfoFeedUiState.ShowingMessage ?: return
        if (!current.isConfirming) {
            mutableState.value = current.copy(hidePermanently = checked)
        }
    }

    suspend fun confirm() {
        val current = mutableState.value as? InfoFeedUiState.ShowingMessage ?: return
        if (current.isConfirming) return
        mutableState.value = current.copy(isConfirming = true, notice = null)

        val dismissFailed = current.hidePermanently && runCatching {
            repository.dismiss(current.currentMessage.id)
        }.isFailure
        val nextNotice = if (dismissFailed) notice(InfoFeedNoticeType.DismissFailed) else null
        mutableState.value = if (current.index + 1 < current.messages.size) {
            current.copy(
                index = current.index + 1,
                hidePermanently = false,
                isConfirming = false,
                notice = nextNotice
            )
        } else {
            InfoFeedUiState.Finished(
                feedLoaded = true,
                observedMessageIds = current.messages.mapTo(mutableSetOf(), InfoMessage::id),
                notice = nextNotice
            )
        }
    }

    fun back() {
        val current = mutableState.value as? InfoFeedUiState.ShowingMessage ?: return
        if (current.isConfirming) return
        mutableState.value = if (current.index > 0) {
            current.copy(
                index = current.index - 1,
                hidePermanently = false,
                isConfirming = false,
                notice = null
            )
        } else {
            InfoFeedUiState.Finished(
                feedLoaded = true,
                observedMessageIds = current.messages.mapTo(mutableSetOf(), InfoMessage::id)
            )
        }
    }

    private fun notice(type: InfoFeedNoticeType) = InfoFeedNotice(
        id = nextNoticeId++,
        type = type
    )
}
