package de.eachAndEvery.cueLens.infofeed

import android.annotation.SuppressLint
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import de.eachAndEvery.cueLens.BuildConfig
import de.eachAndEvery.cueLens.MainActivity
import de.eachAndEvery.cueLens.R
import java.util.concurrent.TimeUnit

interface InfoFeedNotifier {
    fun canPostNotifications(): Boolean

    fun postNewInformationNotification()
}

enum class InfoFeedCheckResult {
    Success,
    Retry
}

class InfoFeedNotificationChecker(
    private val service: InfoFeedService,
    private val dismissedMessageStore: DismissedMessageStore,
    private val notificationPreferenceStore: InfoNotificationPreferenceStore,
    private val notifier: InfoFeedNotifier
) {
    suspend fun check(): InfoFeedCheckResult {
        val preferences = notificationPreferenceStore.getPreferences()
        if (!preferences.enabled) return InfoFeedCheckResult.Success

        val dismissedIds = dismissedMessageStore.getDismissedIds()
        val messages = try {
            service.fetchMessages()
        } catch (_: InfoFeedNetworkException) {
            return InfoFeedCheckResult.Retry
        } catch (error: InfoFeedHttpException) {
            return if (error.statusCode >= 500) {
                InfoFeedCheckResult.Retry
            } else {
                InfoFeedCheckResult.Success
            }
        } catch (_: InfoFeedProtocolException) {
            return InfoFeedCheckResult.Success
        }

        val newMessages = messages.filterNot { message ->
            message.id in preferences.knownMessageIds || message.id in dismissedIds
        }
        notificationPreferenceStore.markMessagesKnown(
            messages.mapTo(mutableSetOf(), InfoMessage::id)
        )
        if (newMessages.isNotEmpty() && notifier.canPostNotifications()) {
            notifier.postNewInformationNotification()
        }
        return InfoFeedCheckResult.Success
    }
}

class InfoFeedNotificationWorker(
    appContext: Context,
    workerParameters: WorkerParameters
) : CoroutineWorker(appContext, workerParameters) {
    override suspend fun doWork(): Result {
        val checker = InfoFeedNotificationChecker(
            service = HttpInfoFeedService(BuildConfig.MESSAGES_URL),
            dismissedMessageStore = DataStoreDismissedMessageStore(applicationContext),
            notificationPreferenceStore = DataStoreInfoNotificationPreferenceStore(
                applicationContext
            ),
            notifier = AndroidInfoFeedNotifier(applicationContext)
        )
        return try {
            when (checker.check()) {
                InfoFeedCheckResult.Success -> Result.success()
                InfoFeedCheckResult.Retry -> Result.retry()
            }
        } catch (error: Exception) {
            Log.w(TAG, "Info feed background check failed", error)
            Result.retry()
        }
    }

    private companion object {
        const val TAG = "CueLensInfoWorker"
    }
}

class AndroidInfoFeedNotifier(
    private val context: Context
) : InfoFeedNotifier {
    override fun canPostNotifications(): Boolean {
        val permissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        return permissionGranted && NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    @SuppressLint("MissingPermission")
    override fun postNewInformationNotification() {
        if (!canPostNotifications()) return
        ensureChannel()
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN_INFO_FEED
            putExtra(EXTRA_OPEN_INFO_FEED, true)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(context.getString(R.string.notification_title))
            .setContentText(context.getString(R.string.notification_text))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = context.getString(R.string.notification_channel_description)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val EXTRA_OPEN_INFO_FEED = "open_info_feed"
        const val ACTION_OPEN_INFO_FEED = "de.eachAndEvery.cueLens.OPEN_INFO_FEED"
        private const val CHANNEL_ID = "info_messages"
        private const val NOTIFICATION_ID = 1001
    }
}

object InfoFeedNotificationScheduler {
    private const val UNIQUE_WORK_NAME = "info_feed_periodic_check"

    fun schedule(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = PeriodicWorkRequestBuilder<InfoFeedNotificationWorker>(
            repeatInterval = 24,
            repeatIntervalTimeUnit = TimeUnit.HOURS,
            flexTimeInterval = 6,
            flexTimeIntervalUnit = TimeUnit.HOURS
        )
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            UNIQUE_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(UNIQUE_WORK_NAME)
    }
}
