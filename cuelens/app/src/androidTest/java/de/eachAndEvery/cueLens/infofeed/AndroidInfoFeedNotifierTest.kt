package de.eachAndEvery.cueLens.infofeed

import android.app.NotificationManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import de.eachAndEvery.cueLens.R
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidInfoFeedNotifierTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val notificationManager = context.getSystemService(NotificationManager::class.java)

    @After
    fun tearDown() {
        notificationManager.cancelAll()
    }

    @Test
    fun postsOnlyNeutralConfiguredContent() {
        val notifier = AndroidInfoFeedNotifier(context)

        assertTrue(notifier.canPostNotifications())
        notifier.postNewInformationNotification()

        var activeNotification = notificationManager.activeNotifications.singleOrNull()
        var attempts = 0
        while (activeNotification == null && attempts < 20) {
            Thread.sleep(50)
            activeNotification = notificationManager.activeNotifications.singleOrNull()
            attempts += 1
        }
        val notification = requireNotNull(activeNotification).notification
        assertEquals(
            context.getString(R.string.notification_title),
            notification.extras.getCharSequence("android.title")
        )
        assertEquals(
            context.getString(R.string.notification_text),
            notification.extras.getCharSequence("android.text")
        )
    }
}
