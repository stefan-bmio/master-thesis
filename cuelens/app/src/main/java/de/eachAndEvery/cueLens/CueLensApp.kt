package de.eachAndEvery.cueLens

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.LocaleList
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import de.eachAndEvery.cueLens.infofeed.AndroidInfoFeedNotifier
import de.eachAndEvery.cueLens.infofeed.AppLanguage
import de.eachAndEvery.cueLens.infofeed.DataStoreInfoNotificationPreferenceStore
import de.eachAndEvery.cueLens.infofeed.DataStoreLanguageStore
import de.eachAndEvery.cueLens.infofeed.InfoFeedController
import de.eachAndEvery.cueLens.infofeed.InfoFeedLoadingScreen
import de.eachAndEvery.cueLens.infofeed.InfoFeedNotice
import de.eachAndEvery.cueLens.infofeed.InfoFeedNoticeType
import de.eachAndEvery.cueLens.infofeed.InfoFeedNotificationScheduler
import de.eachAndEvery.cueLens.infofeed.InfoFeedRepository
import de.eachAndEvery.cueLens.infofeed.InfoFeedUiState
import de.eachAndEvery.cueLens.infofeed.InfoMessageScreen
import de.eachAndEvery.cueLens.infofeed.NotificationConsentScreen
import de.eachAndEvery.cueLens.infofeed.localizedStrings
import de.eachAndEvery.cueLens.prestudy.PreStudyApp
import kotlinx.coroutines.launch

private enum class NotificationGateState {
    Waiting,
    Prompt,
    RequestingSystemPermission,
    Done
}

@Composable
internal fun CueLensApp(infoFeedOpenRequest: Long = 0L) {
    val context = LocalContext.current.applicationContext
    val repository = remember(context) { InfoFeedRepository.create(context) }
    val controller = remember(repository) { InfoFeedController(repository) }
    val languageStore = remember(context) { DataStoreLanguageStore(context) }
    val notificationStore = remember(context) {
        DataStoreInfoNotificationPreferenceStore(context)
    }
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }
    val state by controller.state.collectAsState()
    var language by remember { mutableStateOf(systemLanguage()) }
    var languageReady by remember { mutableStateOf(false) }
    var notificationGate by remember { mutableStateOf(NotificationGateState.Waiting) }
    var notificationOptionEnabled by remember { mutableStateOf(true) }
    var hasEnteredApp by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        scope.launch {
            val consentStored = runCatching {
                notificationStore.completePrompt(granted)
            }.isSuccess
            if (granted && consentStored) {
                runCatching { InfoFeedNotificationScheduler.schedule(context) }
            } else {
                runCatching { InfoFeedNotificationScheduler.cancel(context) }
            }
            notificationGate = NotificationGateState.Done
            hasEnteredApp = true
        }
    }

    LaunchedEffect(languageStore) {
        language = runCatching { languageStore.getSelectedLanguage() }
            .getOrNull()
            ?: systemLanguage()
        languageReady = true
    }
    LaunchedEffect(controller, infoFeedOpenRequest, languageReady) {
        if (languageReady) {
            notificationGate = NotificationGateState.Waiting
            controller.load()
        }
    }

    val finishedState = state as? InfoFeedUiState.Finished
    LaunchedEffect(
        finishedState?.feedLoaded,
        finishedState?.observedMessageIds,
        infoFeedOpenRequest
    ) {
        val finished = finishedState ?: return@LaunchedEffect
        if (!finished.feedLoaded) {
            notificationGate = NotificationGateState.Done
            hasEnteredApp = true
            return@LaunchedEffect
        }

        val preferences = runCatching {
            notificationStore.markMessagesKnown(finished.observedMessageIds)
            notificationStore.getPreferences()
        }.getOrNull()
        if (preferences == null) {
            notificationGate = NotificationGateState.Done
            hasEnteredApp = true
            return@LaunchedEffect
        }

        if (preferences.promptCompleted) {
            if (preferences.enabled) {
                runCatching { InfoFeedNotificationScheduler.schedule(context) }
            } else {
                runCatching { InfoFeedNotificationScheduler.cancel(context) }
            }
            notificationGate = NotificationGateState.Done
            hasEnteredApp = true
        } else {
            notificationOptionEnabled = true
            notificationGate = NotificationGateState.Prompt
        }
    }

    val toggleLanguage = {
        val selectedLanguage = language.toggled()
        language = selectedLanguage
        scope.launch {
            runCatching { languageStore.setSelectedLanguage(selectedLanguage) }
        }
        Unit
    }
    val completeNotificationConsent = { enabled: Boolean ->
        notificationGate = NotificationGateState.RequestingSystemPermission
        scope.launch {
            if (!enabled) {
                runCatching { notificationStore.completePrompt(false) }
                runCatching { InfoFeedNotificationScheduler.cancel(context) }
                notificationGate = NotificationGateState.Done
                hasEnteredApp = true
            } else {
                AndroidInfoFeedNotifier(context).ensureChannel()
                val permissionAlreadyGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                    ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.POST_NOTIFICATIONS
                    ) == PackageManager.PERMISSION_GRANTED
                if (permissionAlreadyGranted) {
                    val consentStored = runCatching {
                        notificationStore.completePrompt(true)
                    }.isSuccess
                    if (consentStored) {
                        runCatching { InfoFeedNotificationScheduler.schedule(context) }
                    } else {
                        runCatching { InfoFeedNotificationScheduler.cancel(context) }
                    }
                    notificationGate = NotificationGateState.Done
                    hasEnteredApp = true
                } else {
                    permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
        }
        Unit
    }

    val notice = when (val current = state) {
        is InfoFeedUiState.ShowingMessage -> current.notice
        is InfoFeedUiState.Finished -> current.notice
        InfoFeedUiState.Loading -> null
    }
    val strings = localizedStrings(language)
    LaunchedEffect(notice?.id, language) {
        notice ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(notice.message(strings))
    }

    Box(modifier = Modifier.fillMaxSize()) {
        if (hasEnteredApp) {
            PreStudyApp(
                language = language,
                onLanguageChange = toggleLanguage
            )
        }
        when (val current = state) {
            InfoFeedUiState.Loading -> InfoFeedLoadingScreen(language = language)
            is InfoFeedUiState.ShowingMessage -> {
                BackHandler { controller.back() }
                InfoMessageScreen(
                    state = current,
                    language = language,
                    onLanguageChange = toggleLanguage,
                    onHidePermanentlyChange = controller::setHidePermanently,
                    onConfirm = { scope.launch { controller.confirm() } }
                )
            }
            is InfoFeedUiState.Finished -> when (notificationGate) {
                NotificationGateState.Waiting -> InfoFeedLoadingScreen(language = language)
                NotificationGateState.Prompt,
                NotificationGateState.RequestingSystemPermission -> {
                    val controlsEnabled = notificationGate == NotificationGateState.Prompt
                    BackHandler {
                        if (controlsEnabled) completeNotificationConsent(false)
                    }
                    NotificationConsentScreen(
                        language = language,
                        notificationsEnabled = notificationOptionEnabled,
                        onNotificationsEnabledChange = { notificationOptionEnabled = it },
                        onLanguageChange = toggleLanguage,
                        onContinue = {
                            completeNotificationConsent(notificationOptionEnabled)
                        },
                        enabled = controlsEnabled
                    )
                }
                NotificationGateState.Done -> Unit
            }
        }
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .padding(16.dp)
        )
    }
}

private fun AppLanguage.toggled(): AppLanguage = when (this) {
    AppLanguage.German -> AppLanguage.English
    AppLanguage.English -> AppLanguage.German
}

private fun systemLanguage(): AppLanguage =
    if (LocaleList.getDefault().get(0)?.language == AppLanguage.English.languageTag) {
        AppLanguage.English
    } else {
        AppLanguage.German
    }

private fun InfoFeedNotice.message(strings: de.eachAndEvery.cueLens.infofeed.InfoFeedStrings): String =
    when (type) {
        InfoFeedNoticeType.LoadFailed -> strings.loadFailed
        InfoFeedNoticeType.DismissFailed -> strings.dismissFailed
    }
