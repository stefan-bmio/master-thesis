package de.eachandevery.cuelens.prestudy

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class DataProtectionConsentStoreTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @After
    fun tearDown() {
        scope.cancel()
    }

    @Test
    fun dataprotStartsFalseAndCanOnlyBeMarkedAccepted() = runBlocking {
        val dataStore = PreferenceDataStoreFactory.create(
            scope = scope,
            produceFile = {
                File(temporaryFolder.root, "data_protection.preferences_pb")
            }
        )
        val store = DataStoreDataProtectionConsentStore(dataStore)

        assertFalse(store.isAccepted())

        store.markAccepted()
        assertTrue(store.isAccepted())

        store.markAccepted()
        assertTrue(store.isAccepted())
    }
}
