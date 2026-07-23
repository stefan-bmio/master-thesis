package de.eachandevery.cuelens.prestudy

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.os.LocaleList
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import de.eachandevery.cuelens.MainActivity
import de.eachandevery.cuelens.R
import de.eachandevery.cuelens.infofeed.AppLanguage
import de.eachandevery.cuelens.infofeed.DataStoreInfoNotificationPreferenceStore
import de.eachandevery.cuelens.infofeed.DataStoreLanguageStore
import java.util.Locale
import java.util.concurrent.TimeUnit

sealed interface StudyReminderDecision {
    data object Skip : StudyReminderDecision
    data class Reschedule(val delayMillis: Long) : StudyReminderDecision
    data class Notify(val situationNumber: Int) : StudyReminderDecision
}

internal fun studyReminderDecision(
    progress: StudyProgress,
    expectedSituationNumber: Int,
    nowMillis: Long,
    notificationsAllowed: Boolean,
    appActivated: Boolean
): StudyReminderDecision {
    val currentSituationNumber = progress.confirmedSituationCount + 1
    if (
        !notificationsAllowed ||
        !appActivated ||
        progress.completed ||
        progress.hasPendingSubmission ||
        progress.confirmedSituationCount !in 1 until TOTAL_STUDY_SITUATIONS ||
        expectedSituationNumber != currentSituationNumber ||
        progress.lastNotifiedSituationNumber == expectedSituationNumber ||
        progress.nextSituationAvailableAtMillis <= 0L
    ) return StudyReminderDecision.Skip

    val remainingMillis = progress.nextSituationAvailableAtMillis - nowMillis
    return if (remainingMillis > 0L) {
        StudyReminderDecision.Reschedule(remainingMillis)
    } else {
        StudyReminderDecision.Notify(currentSituationNumber)
    }
}

class StudyReminderWorker(
    appContext: Context,
    workerParameters: WorkerParameters
) : CoroutineWorker(appContext, workerParameters) {
    override suspend fun doWork(): Result {
        val expectedSituationNumber = inputData.getInt(KEY_SITUATION_NUMBER, 0)
        val notificationsAllowed = runCatching {
            DataStoreInfoNotificationPreferenceStore(applicationContext)
                .getPreferences().enabled &&
                AndroidStudyReminderNotifier(applicationContext).canPostNotifications()
        }.getOrDefault(false)
        val appActivated = runCatching {
            AndroidKeystoreAppTokenStore(applicationContext).getAppToken() != null
        }.getOrDefault(false)
        val progress = SharedPreferencesStudyProgressStore(applicationContext).read()

        return when (val decision = studyReminderDecision(
            progress,
            expectedSituationNumber,
            System.currentTimeMillis(),
            notificationsAllowed,
            appActivated
        )) {
            StudyReminderDecision.Skip -> Result.success()
            is StudyReminderDecision.Reschedule -> {
                StudyReminderScheduler.rescheduleAfterEarlyRun(
                    applicationContext,
                    expectedSituationNumber,
                    decision.delayMillis
                )
                Result.success()
            }
            is StudyReminderDecision.Notify -> {
                val language = runCatching {
                    DataStoreLanguageStore(applicationContext).getSelectedLanguage()
                }.getOrNull() ?: systemLanguage()
                AndroidStudyReminderNotifier(applicationContext)
                    .postSituationAvailableNotification(language)
                applicationContext
                    .getSharedPreferences(STUDY_PREFERENCES_NAME, Context.MODE_PRIVATE)
                    .edit()
                    .putInt(KEY_LAST_NOTIFIED_SITUATION_NUMBER, decision.situationNumber)
                    .apply()
                Result.success()
            }
        }
    }

    companion object {
        internal const val KEY_SITUATION_NUMBER = "study_situation_number"
    }
}

object StudyReminderScheduler {
    internal const val WORK_TAG = "study_situation_available"
    private const val WORK_NAME_PREFIX = "study_situation_available_"

    suspend fun reconcile(context: Context, featureEnabled: Boolean) {
        val appContext = context.applicationContext
        val progress = SharedPreferencesStudyProgressStore(appContext).read()
        val notificationsAllowed = runCatching {
            DataStoreInfoNotificationPreferenceStore(appContext).getPreferences().enabled &&
                AndroidStudyReminderNotifier(appContext).canPostNotifications()
        }.getOrDefault(false)
        val appActivated = runCatching {
            AndroidKeystoreAppTokenStore(appContext).getAppToken() != null
        }.getOrDefault(false)
        val situationNumber = progress.confirmedSituationCount + 1
        val decision = studyReminderDecision(
            progress,
            situationNumber,
            System.currentTimeMillis(),
            featureEnabled && notificationsAllowed,
            appActivated
        )

        when (decision) {
            StudyReminderDecision.Skip -> cancelAll(appContext)
            is StudyReminderDecision.Reschedule -> {
                cancelObsolete(appContext, situationNumber)
                schedule(appContext, situationNumber, decision.delayMillis)
            }
            is StudyReminderDecision.Notify -> {
                cancelObsolete(appContext, situationNumber)
                schedule(appContext, situationNumber, 0L)
            }
        }
    }

    internal fun schedule(context: Context, situationNumber: Int, delayMillis: Long) {
        enqueue(context, situationNumber, delayMillis, ExistingWorkPolicy.REPLACE)
    }

    internal fun rescheduleAfterEarlyRun(
        context: Context,
        situationNumber: Int,
        delayMillis: Long
    ) {
        enqueue(context, situationNumber, delayMillis, ExistingWorkPolicy.APPEND_OR_REPLACE)
    }

    private fun enqueue(
        context: Context,
        situationNumber: Int,
        delayMillis: Long,
        policy: ExistingWorkPolicy
    ) {
        if (situationNumber !in 2..TOTAL_STUDY_SITUATIONS) return
        val request = OneTimeWorkRequestBuilder<StudyReminderWorker>()
            .setInputData(workDataOf(StudyReminderWorker.KEY_SITUATION_NUMBER to situationNumber))
            .setInitialDelay(delayMillis.coerceAtLeast(0L), TimeUnit.MILLISECONDS)
            .addTag(WORK_TAG)
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(
            uniqueWorkName(situationNumber),
            policy,
            request
        )
    }

    fun cancelAll(context: Context) {
        WorkManager.getInstance(context).cancelAllWorkByTag(WORK_TAG)
        AndroidStudyReminderNotifier(context).cancel()
    }

    private fun cancelObsolete(context: Context, currentSituationNumber: Int) {
        val workManager = WorkManager.getInstance(context)
        (2..TOTAL_STUDY_SITUATIONS)
            .filter { it != currentSituationNumber }
            .forEach { workManager.cancelUniqueWork(uniqueWorkName(it)) }
    }

    internal fun uniqueWorkName(situationNumber: Int): String =
        "$WORK_NAME_PREFIX$situationNumber"
}

class AndroidStudyReminderNotifier(private val context: Context) {
    fun canPostNotifications(): Boolean {
        val permissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        return permissionGranted && NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    @SuppressLint("MissingPermission")
    fun postSituationAvailableNotification(language: AppLanguage) {
        if (!canPostNotifications()) return
        ensureChannel(language)
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN_STUDY_HOME
            putExtra(EXTRA_OPEN_STUDY_HOME, true)
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            REQUEST_CODE,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val localizedContext = context.forLanguage(language)
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(localizedContext.getString(R.string.study_reminder_title))
            .setContentText(localizedContext.getString(R.string.study_reminder_text))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(
                NotificationCompat.Builder(context, CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_notification)
                    .setContentTitle(localizedContext.getString(R.string.study_reminder_title))
                    .setContentText(localizedContext.getString(R.string.study_reminder_public_text))
                    .build()
            )
            .build()
        NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
    }

    fun ensureChannel(language: AppLanguage? = null) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val localizedContext = language?.let(context::forLanguage) ?: context
        val channel = NotificationChannel(
            CHANNEL_ID,
            localizedContext.getString(R.string.study_reminder_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = localizedContext.getString(R.string.study_reminder_channel_description)
            lockscreenVisibility = NotificationCompat.VISIBILITY_PRIVATE
        }
        manager.createNotificationChannel(channel)
    }

    fun cancel() {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    companion object {
        const val EXTRA_OPEN_STUDY_HOME = "open_study_home"
        const val ACTION_OPEN_STUDY_HOME = "de.eachandevery.cuelens.OPEN_STUDY_HOME"
        private const val CHANNEL_ID = "study_reminders"
        private const val NOTIFICATION_ID = 2001
        private const val REQUEST_CODE = 2001
    }
}

private fun Context.forLanguage(language: AppLanguage): Context {
    val configuration = Configuration(resources.configuration)
    configuration.setLocale(Locale.forLanguageTag(language.languageTag))
    return createConfigurationContext(configuration)
}

private fun systemLanguage(): AppLanguage =
    if (LocaleList.getDefault().get(0)?.language == AppLanguage.English.languageTag) {
        AppLanguage.English
    } else {
        AppLanguage.German
    }
