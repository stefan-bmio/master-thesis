package de.eachandevery.cuelens.prestudy

import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

sealed interface PreStudyRoute {
    data object Home : PreStudyRoute
    data object EmailActivation : PreStudyRoute
    data object DemoImageMatching : PreStudyRoute
    data object DemoWordLabeling : PreStudyRoute
    data object DemoCraving : PreStudyRoute
    data object DemoComplete : PreStudyRoute
    data object Feedback : PreStudyRoute
    data object ProductiveStudy : PreStudyRoute
}

sealed interface ActivationState {
    data object Idle : ActivationState
    data object RequestingToken : ActivationState
    data object ConfirmingToken : ActivationState
    data object Activated : ActivationState
    data object Error : ActivationState
}

fun interface StudyTransferRetryService {
    suspend fun retry()
}

data class PreStudyUiState(
    val route: PreStudyRoute = PreStudyRoute.Home,
    val hasAppToken: Boolean = false,
    val tokenStorageFailed: Boolean = false,
    val activationState: ActivationState = ActivationState.Idle,
    val activationNeedsSupport: Boolean = false,
    val nextStudyRunVisible: Boolean = false,
    val nextStudyRunEligible: Boolean = false,
    val nextStudyRunAvailable: Boolean = false,
    val nextStudyRunAvailableAtMillis: Long = 0L,
    val studyTransferPending: Boolean = false,
    val studyTransferRetrying: Boolean = false,
    val studyTransferRetryFailed: Boolean = false,
    val studyCompleted: Boolean = false,
    val compensationCode: String? = null,
    val feedbackSubmitting: Boolean = false,
    val feedbackSubmitted: Boolean = false,
    val feedbackFailed: Boolean = false
)

class PreStudyController(
    private val activationService: ActivationService,
    private val appTokenStore: AppTokenStore,
    private val feedbackService: FeedbackService = FeedbackService { _, _, _ ->
        throw IllegalStateException("Feedback service is not configured.")
    },
    private val featureConfigService: FeatureConfigService = FeatureConfigService { false },
    private val studyProgressStore: StudyProgressStore = StudyProgressStore { StudyProgress() },
    private val nowMillis: () -> Long = System::currentTimeMillis,
    private val studyTransferRetryService: StudyTransferRetryService = StudyTransferRetryService {
        throw IllegalStateException("Study transfer retry service is not configured.")
    }
) {
    private val mutableState = MutableStateFlow(
        runCatching { appTokenStore.getAppToken() }
            .fold(
                onSuccess = { token ->
                    val progress = runCatching { studyProgressStore.read() }.getOrNull()
                    PreStudyUiState(
                        hasAppToken = token != null,
                        studyCompleted = progress?.completed == true,
                        compensationCode = progress?.compensationCode,
                        activationState = if (token == null) {
                            ActivationState.Idle
                        } else {
                            ActivationState.Activated
                        }
                    )
                },
                onFailure = { PreStudyUiState(tokenStorageFailed = true) }
            )
    )
    val state: StateFlow<PreStudyUiState> = mutableState.asStateFlow()

    fun openEmailActivation() {
        if (
            !mutableState.value.studyCompleted &&
            !mutableState.value.hasAppToken &&
            !mutableState.value.tokenStorageFailed
        ) {
            mutableState.value = mutableState.value.copy(
                route = PreStudyRoute.EmailActivation,
                activationState = ActivationState.Idle,
                activationNeedsSupport = false
            )
        }
    }

    fun backToHome() {
        val progress = runCatching { studyProgressStore.read() }.getOrNull()
        mutableState.value = mutableState.value.copy(
            route = PreStudyRoute.Home,
            studyCompleted = progress?.completed == true,
            compensationCode = progress?.compensationCode,
            activationState = if (mutableState.value.hasAppToken) {
                ActivationState.Activated
            } else {
                ActivationState.Idle
            },
            activationNeedsSupport = false
        )
    }

    fun openDemo() {
        if (!mutableState.value.studyCompleted) {
            mutableState.value = mutableState.value.copy(route = PreStudyRoute.DemoImageMatching)
        }
    }

    fun openFeedback() {
        mutableState.value = mutableState.value.copy(
            route = PreStudyRoute.Feedback,
            feedbackSubmitting = false,
            feedbackSubmitted = false,
            feedbackFailed = false
        )
    }

    suspend fun refreshNextStudyRun() {
        val current = mutableState.value
        val progress = runCatching { studyProgressStore.read() }.getOrNull()
        if (progress?.completed == true) {
            mutableState.value = current.copy(
                studyCompleted = true,
                compensationCode = progress.compensationCode,
                nextStudyRunVisible = false,
                nextStudyRunEligible = false,
                nextStudyRunAvailable = false,
                nextStudyRunAvailableAtMillis = 0L,
                studyTransferPending = false,
                studyTransferRetrying = false,
                studyTransferRetryFailed = false
            )
            return
        }
        if (current.route != PreStudyRoute.Home || !current.hasAppToken) {
            mutableState.value = current.copy(
                studyCompleted = false,
                compensationCode = null,
                nextStudyRunVisible = false,
                nextStudyRunEligible = false,
                nextStudyRunAvailable = false,
                nextStudyRunAvailableAtMillis = 0L,
                studyTransferPending = false,
                studyTransferRetrying = false,
                studyTransferRetryFailed = false
            )
            return
        }
        val enabled = runCatching { featureConfigService.nextStudyRunEnabled() }
            .getOrDefault(false)
        val latest = mutableState.value
        val validStudyState = progress?.let {
            !it.completed && it.confirmedSituationCount < TOTAL_STUDY_SITUATIONS
        } == true &&
            latest.route == PreStudyRoute.Home &&
            latest.hasAppToken
        val visible = enabled && validStudyState
        val eligible = visible && progress?.hasPendingSubmission == false
        val transferPending = validStudyState && progress?.hasPendingSubmission == true
        mutableState.value = latest.copy(
            studyCompleted = false,
            compensationCode = null,
            nextStudyRunVisible = visible,
            nextStudyRunEligible = eligible,
            nextStudyRunAvailable = eligible && progress?.canStart(nowMillis()) == true,
            nextStudyRunAvailableAtMillis = if (visible) {
                progress?.nextSituationAvailableAtMillis ?: 0L
            } else {
                0L
            },
            studyTransferPending = transferPending,
            studyTransferRetryFailed = latest.studyTransferRetryFailed && transferPending
        )
    }

    suspend fun retryPendingStudyTransfer() {
        val current = mutableState.value
        if (
            current.route != PreStudyRoute.Home ||
            !current.studyTransferPending ||
            current.studyTransferRetrying
        ) return

        mutableState.value = current.copy(
            studyTransferRetrying = true,
            studyTransferRetryFailed = false
        )
        val result = runCatching { studyTransferRetryService.retry() }
        if (result.isFailure) {
            mutableState.value = mutableState.value.copy(
                studyTransferRetrying = false,
                studyTransferRetryFailed = true
            )
            return
        }

        mutableState.value = mutableState.value.copy(
            studyTransferRetrying = false,
            studyTransferRetryFailed = false
        )
        refreshNextStudyRun()
    }

    suspend fun openNextStudyRun() {
        refreshNextStudyRun()
        if (mutableState.value.nextStudyRunAvailable) {
            mutableState.value = mutableState.value.copy(
                route = PreStudyRoute.ProductiveStudy,
                nextStudyRunVisible = false,
                nextStudyRunEligible = false,
                nextStudyRunAvailable = false
            )
        }
    }

    fun advanceDemo() {
        val nextRoute = when (mutableState.value.route) {
            PreStudyRoute.DemoImageMatching -> PreStudyRoute.DemoWordLabeling
            PreStudyRoute.DemoWordLabeling -> PreStudyRoute.DemoCraving
            PreStudyRoute.DemoCraving -> PreStudyRoute.DemoComplete
            PreStudyRoute.DemoComplete,
            PreStudyRoute.Home,
            PreStudyRoute.EmailActivation,
            PreStudyRoute.Feedback,
            PreStudyRoute.ProductiveStudy -> return
        }
        mutableState.value = mutableState.value.copy(route = nextRoute)
    }

    suspend fun activate(email: String) {
        val current = mutableState.value
        if (
            current.hasAppToken ||
            current.tokenStorageFailed ||
            current.activationState == ActivationState.RequestingToken ||
            current.activationState == ActivationState.ConfirmingToken ||
            !isValidEmail(email)
        ) return
        mutableState.value = current.copy(
            activationState = ActivationState.RequestingToken,
            activationNeedsSupport = false
        )
        try {
            val normalizedEmail = email.trim()
            val appToken = activationService.requestToken(normalizedEmail)
            mutableState.value = mutableState.value.copy(
                activationState = ActivationState.ConfirmingToken
            )
            activationService.confirmToken(normalizedEmail, appToken)
            appTokenStore.saveAppToken(appToken)
            mutableState.value = PreStudyUiState(
                route = PreStudyRoute.Home,
                hasAppToken = true,
                activationState = ActivationState.Activated
            )
        } catch (error: Throwable) {
            mutableState.value = current.copy(
                route = PreStudyRoute.EmailActivation,
                activationState = ActivationState.Error,
                activationNeedsSupport = error is ActivationConfirmationTimeoutException
            )
        }
    }

    suspend fun submitFeedback(source: String, comment: String, appVersion: String) {
        val current = mutableState.value
        if (
            current.route != PreStudyRoute.Feedback ||
            current.feedbackSubmitting ||
            !isValidFeedback(source, comment)
        ) {
            return
        }
        mutableState.value = current.copy(feedbackSubmitting = true, feedbackFailed = false)
        runCatching {
            feedbackService.submit(source.trim(), comment.trim(), appVersion)
        }.onSuccess {
            mutableState.value = current.copy(
                feedbackSubmitting = false,
                feedbackSubmitted = true,
                feedbackFailed = false
            )
        }.onFailure {
            mutableState.value = current.copy(
                feedbackSubmitting = false,
                feedbackSubmitted = false,
                feedbackFailed = true
            )
        }
    }

    companion object {
        fun isValidEmail(email: String): Boolean = EMAIL_PATTERN.matches(email.trim())

        fun isValidFeedback(source: String, comment: String): Boolean {
            val trimmedSource = source.trim()
            val trimmedComment = comment.trim()
            return (trimmedSource.isNotEmpty() || trimmedComment.isNotEmpty()) &&
                trimmedSource.length <= MAX_FEEDBACK_SOURCE_LENGTH &&
                trimmedComment.length <= MAX_FEEDBACK_COMMENT_LENGTH
        }

        private val EMAIL_PATTERN = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
        const val MAX_FEEDBACK_SOURCE_LENGTH = 500
        const val MAX_FEEDBACK_COMMENT_LENGTH = 5_000
    }
}
