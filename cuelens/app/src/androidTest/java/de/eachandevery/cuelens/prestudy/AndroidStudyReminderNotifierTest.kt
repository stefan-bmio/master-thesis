package de.eachandevery.cuelens.prestudy

import android.app.NotificationManager
import android.os.Build
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import de.eachandevery.cuelens.infofeed.AppLanguage
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidStudyReminderNotifierTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val notificationManager = context.getSystemService(NotificationManager::class.java)

    @After
    fun tearDown() {
        notificationManager.cancelAll()
    }

    @Test
    fun postsNeutralPrivateEnglishContentWithGenericPublicVersion() {
        val notifier = AndroidStudyReminderNotifier(context)

        assertTrue(notifier.canPostNotifications())
        notifier.postSituationAvailableNotification(AppLanguage.English)

        var activeNotification = notificationManager.activeNotifications.singleOrNull()
        var attempts = 0
        while (activeNotification == null && attempts < 20) {
            Thread.sleep(50)
            activeNotification = notificationManager.activeNotifications.singleOrNull()
            attempts += 1
        }
        val notification = requireNotNull(activeNotification).notification
        assertEquals("CueLens", notification.extras.getCharSequence("android.title"))
        assertEquals(
            "A new task is available.",
            notification.extras.getCharSequence("android.text")
        )
        assertEquals(
            "New information is available.",
            requireNotNull(notification.publicVersion).extras.getCharSequence("android.text")
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            assertEquals(
                "CueLens reminders",
                notificationManager.getNotificationChannel(notification.channelId).name
            )
        }
    }
}
