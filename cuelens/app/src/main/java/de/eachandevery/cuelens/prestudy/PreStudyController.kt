package de.eachandevery.cuelens.prestudy

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

sealed interface PreStudyRoute {
    data object Home : PreStudyRoute
    data object EmailActivation : PreStudyRoute
    data object DataProtectionConsent : PreStudyRoute
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

sealed interface DataProtectionConsentState {
    data object NotApplicable : DataProtectionConsentState
    data object Unchecked : DataProtectionConsentState
    data object Checking : DataProtectionConsentState
    data object Required : DataProtectionConsentState
    data object Submitting : DataProtectionConsentState
    data object Granted : DataProtectionConsentState
    data object Error : DataProtectionConsentState
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
    val dataProtectionConsentState: DataProtectionConsentState =
        DataProtectionConsentState.NotApplicable,
    val nextStudyRunVisible: Boolean = false,
    val nextStudyRunEligible: Boolean = false,
    val nextStudyRunAvailable: Boolean = false,
    val nextStudyRunAvailableAtMillis: Long = 0L,
    val studyTransferPending: Boolean = false,
    val studyTransferRetrying: Boolean = false,
    val studyTransferRetryFailed: Boolean = false,
    val completionState: CompletionState = CompletionState.Incomplete,
    val feedbackSubmitting: Boolean = false,
    val feedbackSubmitted: Boolean = false,
    val feedbackFailed: Boolean = false
) {
    val studyCompleted: Boolean
        get() = completionState.isCompleted

    val compensationCode: String?
        get() = completionState.compensationCode
}

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
    },
    private val dataProtectionService: DataProtectionService = FailClosedDataProtectionService,
    private val dataProtectionConsentStore: DataProtectionConsentStore =
        FailClosedDataProtectionConsentStore
) {
    private val mutableState = MutableStateFlow(
        runCatching { appTokenStore.getAppToken() }
            .fold(
                onSuccess = { token ->
                    val progress = runCatching { studyProgressStore.read() }.getOrElse {
                        StudyProgress(
                            hasPendingSubmission = true,
                            completionState = CompletionState.Invalid
                        )
                    }
                    PreStudyUiState(
                        hasAppToken = token != null,
                        completionState = progress.completionState,
                        activationState = if (token == null) {
                            ActivationState.Idle
                        } else {
                            ActivationState.Activated
                        },
                        dataProtectionConsentState = if (token == null) {
                            DataProtectionConsentState.NotApplicable
                        } else {
                            DataProtectionConsentState.Unchecked
                        },
                    )
                },
                onFailure = { PreStudyUiState(tokenStorageFailed = true) }
            )
    )
    val state: StateFlow<PreStudyUiState> = mutableState.asStateFlow()
    private val dataProtectionMutex = Mutex()

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
        val progress = runCatching { studyProgressStore.read() }.getOrElse {
            StudyProgress(
                hasPendingSubmission = true,
                completionState = CompletionState.Invalid
            )
        }
        mutableState.value = mutableState.value.copy(
            route = PreStudyRoute.Home,
            completionState = progress.completionState,
            activationState = if (mutableState.value.hasAppToken) {
                ActivationState.Activated
            } else {
                ActivationState.Idle
            },
            activationNeedsSupport = false
        )
    }

    suspend fun refreshDataProtectionConsent(openScreenWhenRequired: Boolean = true): Boolean =
        dataProtectionMutex.withLock {
            val current = mutableState.value
            if (!current.hasAppToken || current.tokenStorageFailed) return@withLock false
            if (current.dataProtectionConsentState == DataProtectionConsentState.Granted) {
                return@withLock true
            }
            if (current.dataProtectionConsentState == DataProtectionConsentState.Required) {
                if (openScreenWhenRequired) {
                    mutableState.value = current.copy(
                        route = PreStudyRoute.DataProtectionConsent
                    )
                }
                return@withLock false
            }

            val locallyAccepted = runCatching {
                dataProtectionConsentStore.isAccepted()
            }.getOrElse {
                mutableState.value = current.copy(
                    route = if (openScreenWhenRequired) {
                        PreStudyRoute.DataProtectionConsent
                    } else {
                        current.route
                    },
                    dataProtectionConsentState = DataProtectionConsentState.Error
                )
                return@withLock false
            }
            if (locallyAccepted) {
                mutableState.value = current.copy(
                    route = if (current.route == PreStudyRoute.DataProtectionConsent) {
                        PreStudyRoute.Home
                    } else {
                        current.route
                    },
                    dataProtectionConsentState = DataProtectionConsentState.Granted
                )
                return@withLock true
            }

            mutableState.value = current.copy(
                dataProtectionConsentState = DataProtectionConsentState.Checking
            )
            val appToken = runCatching { appTokenStore.getAppToken() }.getOrNull()
            if (appToken == null) {
                mutableState.value = mutableState.value.copy(
                    route = if (openScreenWhenRequired) {
                        PreStudyRoute.DataProtectionConsent
                    } else {
                        mutableState.value.route
                    },
                    dataProtectionConsentState = DataProtectionConsentState.Error
                )
                return@withLock false
            }

            val serverAccepted = runCatching {
                dataProtectionService.getStatus(appToken)
            }.getOrElse {
                mutableState.value = mutableState.value.copy(
                    route = if (openScreenWhenRequired) {
                        PreStudyRoute.DataProtectionConsent
                    } else {
                        mutableState.value.route
                    },
                    dataProtectionConsentState = DataProtectionConsentState.Error
                )
                return@withLock false
            }
            if (!serverAccepted) {
                mutableState.value = mutableState.value.copy(
                    route = if (openScreenWhenRequired) {
                        PreStudyRoute.DataProtectionConsent
                    } else {
                        mutableState.value.route
                    },
                    dataProtectionConsentState = DataProtectionConsentState.Required
                )
                return@withLock false
            }

            if (runCatching { dataProtectionConsentStore.markAccepted() }.isFailure) {
                mutableState.value = mutableState.value.copy(
                    route = if (openScreenWhenRequired) {
                        PreStudyRoute.DataProtectionConsent
                    } else {
                        mutableState.value.route
                    },
                    dataProtectionConsentState = DataProtectionConsentState.Error
                )
                return@withLock false
            }
            mutableState.value = mutableState.value.copy(
                route = if (mutableState.value.route == PreStudyRoute.DataProtectionConsent) {
                    PreStudyRoute.Home
                } else {
                    mutableState.value.route
                },
                dataProtectionConsentState = DataProtectionConsentState.Granted
            )
            true
        }

    suspend fun acceptDataProtection() {
        dataProtectionMutex.withLock {
            val current = mutableState.value
            if (
                current.route != PreStudyRoute.DataProtectionConsent ||
                current.dataProtectionConsentState == DataProtectionConsentState.Submitting ||
                current.dataProtectionConsentState == DataProtectionConsentState.Granted
            ) return@withLock

            val appToken = runCatching { appTokenStore.getAppToken() }.getOrNull()
            if (appToken == null) {
                mutableState.value = current.copy(
                    dataProtectionConsentState = DataProtectionConsentState.Error
                )
                return@withLock
            }
            mutableState.value = current.copy(
                dataProtectionConsentState = DataProtectionConsentState.Submitting
            )
            val accepted = runCatching {
                if (!dataProtectionService.accept(appToken)) {
                    throw DataProtectionProtocolException()
                }
                dataProtectionConsentStore.markAccepted()
            }.isSuccess
            mutableState.value = if (accepted) {
                mutableState.value.copy(
                    route = PreStudyRoute.Home,
                    dataProtectionConsentState = DataProtectionConsentState.Granted
                )
            } else {
                mutableState.value.copy(
                    dataProtectionConsentState = DataProtectionConsentState.Error
                )
            }
        }
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
        val progress = runCatching { studyProgressStore.read() }.getOrElse {
            StudyProgress(
                hasPendingSubmission = true,
                completionState = CompletionState.Invalid
            )
        }
        if (progress.completed) {
            mutableState.value = current.copy(
                completionState = progress.completionState,
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
                completionState = CompletionState.Incomplete,
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
        val validStudyState = progress.let {
            it.completionState == CompletionState.Incomplete &&
                it.confirmedSituationCount < TOTAL_STUDY_SITUATIONS
        } &&
            latest.route == PreStudyRoute.Home &&
            latest.hasAppToken
        val visible = enabled && validStudyState
        val eligible = visible && !progress.hasPendingSubmission
        val transferPending = latest.route == PreStudyRoute.Home &&
            latest.hasAppToken &&
            !progress.completed &&
            progress.hasPendingSubmission
        mutableState.value = latest.copy(
            completionState = progress.completionState,
            nextStudyRunVisible = visible,
            nextStudyRunEligible = eligible,
            nextStudyRunAvailable = eligible && progress.canStart(nowMillis()),
            nextStudyRunAvailableAtMillis = if (visible) {
                progress.nextSituationAvailableAtMillis
            } else {
                0L
            },
            studyTransferPending = transferPending,
            studyTransferRetryFailed = latest.studyTransferRetryFailed && transferPending
        )
    }

    suspend fun retryPendingStudyTransfer() {
        if (!refreshDataProtectionConsent(openScreenWhenRequired = true)) return
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
        if (!refreshDataProtectionConsent(openScreenWhenRequired = true)) return
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
            PreStudyRoute.DataProtectionConsent,
            PreStudyRoute.Feedback,
            PreStudyRoute.ProductiveStudy -> return
        }
        mutableState.value = mutableState.value.copy(route = nextRoute)
    }

    suspend fun activate(identifierInput: String) {
        val current = mutableState.value
        val identifier = ParticipantIdentifier.parse(identifierInput) ?: return
        if (
            current.hasAppToken ||
            current.tokenStorageFailed ||
            current.activationState == ActivationState.RequestingToken ||
            current.activationState == ActivationState.ConfirmingToken
        ) return
        mutableState.value = current.copy(
            activationState = ActivationState.RequestingToken,
            activationNeedsSupport = false
        )
        try {
            val appToken = activationService.requestToken(identifier.value)
            mutableState.value = mutableState.value.copy(
                activationState = ActivationState.ConfirmingToken
            )
            activationService.confirmToken(identifier.value, appToken)
            appTokenStore.saveAppToken(appToken)
            mutableState.value = PreStudyUiState(
                route = PreStudyRoute.Home,
                hasAppToken = true,
                activationState = ActivationState.Activated,
                dataProtectionConsentState = DataProtectionConsentState.Unchecked
            )
        } catch (error: Throwable) {
            mutableState.value = current.copy(
                route = PreStudyRoute.EmailActivation,
                activationState = ActivationState.Error,
                activationNeedsSupport = error is ActivationConfirmationTimeoutException
            )
            return
        }
        refreshDataProtectionConsent(openScreenWhenRequired = true)
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
        fun isValidParticipantIdentifier(input: String): Boolean =
            ParticipantIdentifier.parse(input) != null

        fun isValidFeedback(source: String, comment: String): Boolean {
            val trimmedSource = source.trim()
            val trimmedComment = comment.trim()
            return (trimmedSource.isNotEmpty() || trimmedComment.isNotEmpty()) &&
                trimmedSource.length <= MAX_FEEDBACK_SOURCE_LENGTH &&
                trimmedComment.length <= MAX_FEEDBACK_COMMENT_LENGTH
        }

        const val MAX_FEEDBACK_SOURCE_LENGTH = 500
        const val MAX_FEEDBACK_COMMENT_LENGTH = 5_000
    }
}

private object FailClosedDataProtectionService : DataProtectionService {
    override suspend fun getStatus(appToken: String): Boolean {
        throw IllegalStateException("Data protection service is not configured.")
    }

    override suspend fun accept(appToken: String): Boolean {
        throw IllegalStateException("Data protection service is not configured.")
    }
}

private object FailClosedDataProtectionConsentStore : DataProtectionConsentStore {
    override suspend fun isAccepted(): Boolean = false

    override suspend fun markAccepted() {
        throw IllegalStateException("Data protection store is not configured.")
    }
}
