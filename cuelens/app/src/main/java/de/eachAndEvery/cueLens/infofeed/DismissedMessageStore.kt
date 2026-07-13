package de.eachAndEvery.cueLens.infofeed

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import java.io.IOException
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

internal val Context.infoFeedDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "info_feed"
)

interface DismissedMessageStore {
    val dismissedIds: Flow<Set<Long>>

    suspend fun getDismissedIds(): Set<Long>

    suspend fun dismiss(messageId: Long)
}

enum class AppLanguage(val languageTag: String) {
    German("de"),
    English("en")
}

interface LanguageStore {
    suspend fun getSelectedLanguage(): AppLanguage?

    suspend fun setSelectedLanguage(language: AppLanguage)
}

class DataStoreLanguageStore(
    private val dataStore: DataStore<Preferences>
) : LanguageStore {
    constructor(context: Context) : this(context.infoFeedDataStore)

    override suspend fun getSelectedLanguage(): AppLanguage? {
        val storedValue = dataStore.data
            .catch { cause ->
                if (cause is IOException) {
                    emit(androidx.datastore.preferences.core.emptyPreferences())
                } else {
                    throw cause
                }
            }
            .first()[SELECTED_LANGUAGE]
        return AppLanguage.entries.firstOrNull { it.languageTag == storedValue }
    }

    override suspend fun setSelectedLanguage(language: AppLanguage) {
        dataStore.edit { preferences ->
            preferences[SELECTED_LANGUAGE] = language.languageTag
        }
    }

    private companion object {
        val SELECTED_LANGUAGE = stringPreferencesKey("selected_language")
    }
}

class DataStoreDismissedMessageStore(
    private val dataStore: DataStore<Preferences>
) : DismissedMessageStore {
    constructor(context: Context) : this(context.infoFeedDataStore)

    override val dismissedIds: Flow<Set<Long>> = dataStore.data
        .catch { cause ->
            if (cause is IOException) {
                emit(androidx.datastore.preferences.core.emptyPreferences())
            } else {
                throw cause
            }
        }
        .map { preferences ->
            preferences[DISMISSED_IDS]
                .orEmpty()
                .mapNotNull(String::toLongOrNull)
                .filter { it > 0L }
                .toSet()
        }

    override suspend fun getDismissedIds(): Set<Long> = dismissedIds.first()

    override suspend fun dismiss(messageId: Long) {
        require(messageId > 0L) { "Message ID must be positive." }
        dataStore.edit { preferences ->
            val updatedIds = preferences[DISMISSED_IDS].orEmpty().toMutableSet()
            updatedIds += messageId.toString()
            preferences[DISMISSED_IDS] = updatedIds
        }
    }

    private companion object {
        val DISMISSED_IDS = stringSetPreferencesKey("dismissed_message_ids")
    }
}
