package de.eachandevery.cuelens.prestudy

import android.annotation.SuppressLint
import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

interface AppTokenStore {
    fun getAppToken(): String?

    fun saveAppToken(appToken: String)

    fun clear()
}

class AppTokenStorageException(cause: Throwable? = null) : IllegalStateException(
    "The app token could not be accessed securely.",
    cause
)

@SuppressLint("ApplySharedPref")
class AndroidKeystoreAppTokenStore(context: Context) : AppTokenStore {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE
    )

    init {
        // Never migrate the obsolete cleartext value into the secure store.
        val legacyPreferences = context.applicationContext.getSharedPreferences(
            LEGACY_PREFERENCES_NAME,
            Context.MODE_PRIVATE
        )
        if (
            legacyPreferences.contains(LEGACY_KEY_APP_TOKEN) &&
            !legacyPreferences.edit().remove(LEGACY_KEY_APP_TOKEN).commit()
        ) {
            throw AppTokenStorageException()
        }
    }

    override fun getAppToken(): String? {
        val version = preferences.getInt(KEY_FORMAT_VERSION, NO_FORMAT_VERSION)
        val encodedIv = preferences.getString(KEY_IV, null)
        val encodedCiphertext = preferences.getString(KEY_CIPHERTEXT, null)
        if (version == NO_FORMAT_VERSION && encodedIv == null && encodedCiphertext == null) {
            return null
        }
        if (version != FORMAT_VERSION || encodedIv == null || encodedCiphertext == null) {
            throw AppTokenStorageException()
        }

        return try {
            val key = existingKey() ?: throw AppTokenStorageException()
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                key,
                GCMParameterSpec(GCM_TAG_LENGTH_BITS, Base64.decode(encodedIv, BASE64_FLAGS))
            )
            cipher.updateAAD(AUTHENTICATED_DATA)
            val plaintext = cipher.doFinal(Base64.decode(encodedCiphertext, BASE64_FLAGS))
            plaintext.toString(Charsets.UTF_8).takeIf(String::isNotBlank)
                ?: throw AppTokenStorageException()
        } catch (error: AppTokenStorageException) {
            throw error
        } catch (error: AEADBadTagException) {
            throw AppTokenStorageException(error)
        } catch (error: Exception) {
            throw AppTokenStorageException(error)
        }
    }

    override fun saveAppToken(appToken: String) {
        require(appToken.isNotBlank()) { "App token must not be blank." }
        try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
            cipher.updateAAD(AUTHENTICATED_DATA)
            val ciphertext = cipher.doFinal(appToken.toByteArray(Charsets.UTF_8))
            val persisted = preferences.edit()
                .putInt(KEY_FORMAT_VERSION, FORMAT_VERSION)
                .putString(KEY_IV, Base64.encodeToString(cipher.iv, BASE64_FLAGS))
                .putString(KEY_CIPHERTEXT, Base64.encodeToString(ciphertext, BASE64_FLAGS))
                .commit()
            if (!persisted) throw AppTokenStorageException()
        } catch (error: AppTokenStorageException) {
            throw error
        } catch (error: Exception) {
            throw AppTokenStorageException(error)
        }
    }

    override fun clear() {
        try {
            val preferencesCleared = preferences.edit().clear().commit()
            val keyStore = loadKeyStore()
            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.deleteEntry(KEY_ALIAS)
            }
            if (!preferencesCleared) throw AppTokenStorageException()
        } catch (error: AppTokenStorageException) {
            throw error
        } catch (error: Exception) {
            throw AppTokenStorageException(error)
        }
    }

    private fun existingKey(): SecretKey? = loadKeyStore().getKey(KEY_ALIAS, null) as? SecretKey

    private fun getOrCreateKey(): SecretKey = existingKey() ?: KeyGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_AES,
        ANDROID_KEYSTORE
    ).run {
        init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(KEY_SIZE_BITS)
                .setRandomizedEncryptionRequired(true)
                .setUserAuthenticationRequired(false)
                .build()
        )
        generateKey()
    }

    private fun loadKeyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply {
        load(null)
    }

    internal companion object {
        const val PREFERENCES_NAME = "cuelens_secure_token"
        const val KEY_FORMAT_VERSION = "format_version"
        const val KEY_IV = "iv"
        const val KEY_CIPHERTEXT = "ciphertext"
        const val KEY_ALIAS = "cuelens_app_token_aes_v1"
        private const val LEGACY_PREFERENCES_NAME = "cue_lens_state"
        private const val LEGACY_KEY_APP_TOKEN = "app_token"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val FORMAT_VERSION = 1
        private const val NO_FORMAT_VERSION = -1
        private const val KEY_SIZE_BITS = 256
        private const val GCM_TAG_LENGTH_BITS = 128
        private const val BASE64_FLAGS = Base64.NO_WRAP
        private val AUTHENTICATED_DATA = "cuelens:app-token:v1".toByteArray(Charsets.UTF_8)
    }
}
