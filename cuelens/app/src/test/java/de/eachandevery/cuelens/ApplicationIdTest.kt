package de.eachandevery.cuelens

import org.junit.Assert.assertEquals
import org.junit.Test

class ApplicationIdTest {
    @Test
    fun applicationIdAndNamespaceAreLowercaseAndFlavorSpecific() {
        val expectedApplicationId = when (BuildConfig.FLAVOR) {
            "production" -> "de.eachandevery.cuelens"
            "staging" -> "de.eachandevery.cuelens.staging"
            else -> error("Unexpected flavor: ${BuildConfig.FLAVOR}")
        }

        assertEquals(expectedApplicationId, BuildConfig.APPLICATION_ID)
        assertEquals(BuildConfig.APPLICATION_ID.lowercase(), BuildConfig.APPLICATION_ID)
        assertEquals("de.eachandevery.cuelens", BuildConfig::class.java.packageName)
    }
}
