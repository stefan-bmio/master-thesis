package de.eachandevery.cuelens.prestudy

import android.content.Context
import android.util.Base64
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.security.KeyStore
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidKeystoreAppTokenStoreTest {
    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    private lateinit var store: AndroidKeystoreAppTokenStore

    @Before
    fun setUp() {
        store = AndroidKeystoreAppTokenStore(context)
        store.clear()
    }

    @After
    fun tearDown() {
        store.clear()
    }

    @Test
    fun encryptsAndDecryptsToken() {
        store.saveAppToken(APP_TOKEN)

        assertEquals(APP_TOKEN, store.getAppToken())
        assertFalse(securePreferences().all.values.contains(APP_TOKEN))
    }

    @Test
    fun repeatedEncryptionUsesDifferentCiphertextAndIv() {
        store.saveAppToken(APP_TOKEN)
        val firstCiphertext = securePreferences().getString(
            AndroidKeystoreAppTokenStore.KEY_CIPHERTEXT,
            null
        )
        val firstIv = securePreferences().getString(AndroidKeystoreAppTokenStore.KEY_IV, null)

        store.saveAppToken(APP_TOKEN)

        assertNotEquals(
            firstCiphertext,
            securePreferences().getString(AndroidKeystoreAppTokenStore.KEY_CIPHERTEXT, null)
        )
        assertNotEquals(
            firstIv,
            securePreferences().getString(AndroidKeystoreAppTokenStore.KEY_IV, null)
        )
    }

    @Test
    fun rejectsManipulatedCiphertext() {
        store.saveAppToken(APP_TOKEN)
        val encoded = securePreferences().getString(
            AndroidKeystoreAppTokenStore.KEY_CIPHERTEXT,
            null
        )!!
        val ciphertext = Base64.decode(encoded, Base64.NO_WRAP)
        ciphertext[0] = (ciphertext[0].toInt() xor 1).toByte()
        securePreferences().edit()
            .putString(
                AndroidKeystoreAppTokenStore.KEY_CIPHERTEXT,
                Base64.encodeToString(ciphertext, Base64.NO_WRAP)
            )
            .commit()

        assertStorageFailure { store.getAppToken() }
    }

    @Test
    fun rejectsCiphertextWhenKeyIsMissing() {
        store.saveAppToken(APP_TOKEN)
        KeyStore.getInstance("AndroidKeyStore").apply {
            load(null)
            deleteEntry(AndroidKeystoreAppTokenStore.KEY_ALIAS)
        }

        assertStorageFailure { store.getAppToken() }
    }

    @Test
    fun removesLegacyCleartextWithoutMigratingIt() {
        context.getSharedPreferences("cue_lens_state", Context.MODE_PRIVATE)
            .edit()
            .putString("app_token", APP_TOKEN)
            .commit()

        val freshStore = AndroidKeystoreAppTokenStore(context)

        assertNull(
            context.getSharedPreferences("cue_lens_state", Context.MODE_PRIVATE)
                .getString("app_token", null)
        )
        assertNull(freshStore.getAppToken())
        assertTrue(securePreferences().all.isEmpty())
    }

    private fun securePreferences() = context.getSharedPreferences(
        AndroidKeystoreAppTokenStore.PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

    private fun assertStorageFailure(action: () -> Unit) {
        try {
            action()
            throw AssertionError("Expected AppTokenStorageException")
        } catch (_: AppTokenStorageException) {
            // Expected: corrupt or orphaned ciphertext must never be used.
        }
    }

    private companion object {
        const val APP_TOKEN = "550e8400-e29b-41d4-a716-446655440000"
    }
}
