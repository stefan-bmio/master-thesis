package de.eachAndEvery.cueLens.prestudy

import android.content.Context
import androidx.core.content.edit

interface AppTokenStore {
    fun getAppToken(): String?

    fun saveAppToken(appToken: String)
}

class SharedPreferencesAppTokenStore(context: Context) : AppTokenStore {
    private val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    override fun getAppToken(): String? = preferences.getString(KEY_APP_TOKEN, null)
        ?.takeIf(String::isNotBlank)

    override fun saveAppToken(appToken: String) {
        require(appToken.isNotBlank()) { "App token must not be blank." }
        preferences.edit {
            putString(KEY_APP_TOKEN, appToken)
        }
    }

    private companion object {
        const val PREFERENCES_NAME = "cue_lens_state"
        const val KEY_APP_TOKEN = "app_token"
    }
}
