package de.eachandevery.cuelens.prestudy

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
}

sealed interface ActivationState {
    data object Idle : ActivationState
    data object RequestingToken : ActivationState
    data object ConfirmingToken : ActivationState
    data object Activated : ActivationState
    data object Error : ActivationState
}

data class PreStudyUiState(
    val route: PreStudyRoute = PreStudyRoute.Home,
    val hasAppToken: Boolean = false,
    val tokenStorageFailed: Boolean = false,
    val activationState: ActivationState = ActivationState.Idle,
    val activationNeedsSupport: Boolean = false,
    val feedbackSubmitting: Boolean = false,
    val feedbackSubmitted: Boolean = false,
    val feedbackFailed: Boolean = false
)

class PreStudyController(
    private val activationService: ActivationService,
    private val appTokenStore: AppTokenStore,
    private val feedbackService: FeedbackService = FeedbackService { _, _, _ ->
        throw IllegalStateException("Feedback service is not configured.")
    }
) {
    private val mutableState = MutableStateFlow(
        runCatching { appTokenStore.getAppToken() }
            .fold(
                onSuccess = { token ->
                    PreStudyUiState(
                        hasAppToken = token != null,
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
        if (!mutableState.value.hasAppToken && !mutableState.value.tokenStorageFailed) {
            mutableState.value = mutableState.value.copy(
                route = PreStudyRoute.EmailActivation,
                activationState = ActivationState.Idle,
                activationNeedsSupport = false
            )
        }
    }

    fun backToHome() {
        mutableState.value = mutableState.value.copy(
            route = PreStudyRoute.Home,
            activationState = if (mutableState.value.hasAppToken) {
                ActivationState.Activated
            } else {
                ActivationState.Idle
            },
            activationNeedsSupport = false
        )
    }

    fun openDemo() {
        mutableState.value = mutableState.value.copy(route = PreStudyRoute.DemoImageMatching)
    }

    fun openFeedback() {
        mutableState.value = mutableState.value.copy(
            route = PreStudyRoute.Feedback,
            feedbackSubmitting = false,
            feedbackSubmitted = false,
            feedbackFailed = false
        )
    }

    fun advanceDemo() {
        val nextRoute = when (mutableState.value.route) {
            PreStudyRoute.DemoImageMatching -> PreStudyRoute.DemoWordLabeling
            PreStudyRoute.DemoWordLabeling -> PreStudyRoute.DemoCraving
            PreStudyRoute.DemoCraving -> PreStudyRoute.DemoComplete
            PreStudyRoute.DemoComplete,
            PreStudyRoute.Home,
            PreStudyRoute.EmailActivation,
            PreStudyRoute.Feedback -> return
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
