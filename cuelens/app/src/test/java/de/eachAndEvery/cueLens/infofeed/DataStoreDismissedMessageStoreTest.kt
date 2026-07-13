package de.eachAndEvery.cueLens.infofeed

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class DataStoreDismissedMessageStoreTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @After
    fun tearDown() {
        scope.cancel()
    }

    @Test
    fun dismissPersistsUniqueIds() = runBlocking {
        val preferencesFile = File(temporaryFolder.root, "info_feed.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(
            scope = scope,
            produceFile = { preferencesFile }
        )
        val store = DataStoreDismissedMessageStore(dataStore)

        store.dismiss(9L)
        store.dismiss(3L)
        store.dismiss(9L)

        assertEquals(setOf(3L, 9L), store.getDismissedIds())
    }

    @Test
    fun dismissRejectsNonPositiveId() {
        val dataStore = PreferenceDataStoreFactory.create(
            scope = scope,
            produceFile = { File(temporaryFolder.root, "invalid.preferences_pb") }
        )
        val store = DataStoreDismissedMessageStore(dataStore)

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { store.dismiss(0L) }
        }
    }

    @Test
    fun languageSelectionIsInitiallyUnsetAndThenPersisted() = runBlocking {
        val dataStore = PreferenceDataStoreFactory.create(
            scope = scope,
            produceFile = { File(temporaryFolder.root, "language.preferences_pb") }
        )
        val store = DataStoreLanguageStore(dataStore)

        assertEquals(null, store.getSelectedLanguage())

        store.setSelectedLanguage(AppLanguage.English)

        assertEquals(AppLanguage.English, store.getSelectedLanguage())
    }

    @Test
    fun notificationPreferencesPersistConsentAndKnownIds() = runBlocking {
        val dataStore = PreferenceDataStoreFactory.create(
            scope = scope,
            produceFile = { File(temporaryFolder.root, "notifications.preferences_pb") }
        )
        val store = DataStoreInfoNotificationPreferenceStore(dataStore)

        assertEquals(
            InfoNotificationPreferences(
                promptCompleted = false,
                enabled = false,
                knownMessageIds = emptySet()
            ),
            store.getPreferences()
        )

        store.markMessagesKnown(setOf(3L, 9L))
        store.markMessagesKnown(setOf(9L, 12L))
        store.completePrompt(enabled = true)

        assertEquals(
            InfoNotificationPreferences(
                promptCompleted = true,
                enabled = true,
                knownMessageIds = setOf(3L, 9L, 12L)
            ),
            store.getPreferences()
        )
    }
}
