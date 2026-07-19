package de.eachandevery.cuelens.infofeed

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringSetPreferencesKey
import java.io.IOException
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first

data class InfoNotificationPreferences(
    val promptCompleted: Boolean,
    val enabled: Boolean,
    val knownMessageIds: Set<Long>
)

interface InfoNotificationPreferenceStore {
    suspend fun getPreferences(): InfoNotificationPreferences

    suspend fun completePrompt(enabled: Boolean)

    suspend fun markMessagesKnown(messageIds: Set<Long>)
}

class DataStoreInfoNotificationPreferenceStore(
    private val dataStore: DataStore<Preferences>
) : InfoNotificationPreferenceStore {
    constructor(context: Context) : this(context.infoFeedDataStore)

    override suspend fun getPreferences(): InfoNotificationPreferences {
        val preferences = dataStore.data
            .catch { cause ->
                if (cause is IOException) emit(emptyPreferences()) else throw cause
            }
            .first()
        return InfoNotificationPreferences(
            promptCompleted = preferences[PROMPT_COMPLETED] ?: false,
            enabled = preferences[NOTIFICATIONS_ENABLED] ?: false,
            knownMessageIds = preferences[KNOWN_MESSAGE_IDS]
                .orEmpty()
                .mapNotNull(String::toLongOrNull)
                .filter { it > 0L }
                .toSet()
        )
    }

    override suspend fun completePrompt(enabled: Boolean) {
        dataStore.edit { preferences ->
            preferences[PROMPT_COMPLETED] = true
            preferences[NOTIFICATIONS_ENABLED] = enabled
        }
    }

    override suspend fun markMessagesKnown(messageIds: Set<Long>) {
        require(messageIds.all { it > 0L }) { "Message IDs must be positive." }
        if (messageIds.isEmpty()) return
        dataStore.edit { preferences ->
            val updatedIds = preferences[KNOWN_MESSAGE_IDS].orEmpty().toMutableSet()
            updatedIds += messageIds.map(Long::toString)
            preferences[KNOWN_MESSAGE_IDS] = updatedIds
        }
    }

    private companion object {
        val PROMPT_COMPLETED = booleanPreferencesKey("notification_prompt_completed")
        val NOTIFICATIONS_ENABLED = booleanPreferencesKey("info_notifications_enabled")
        val KNOWN_MESSAGE_IDS = stringSetPreferencesKey("known_notification_message_ids")
    }
}
