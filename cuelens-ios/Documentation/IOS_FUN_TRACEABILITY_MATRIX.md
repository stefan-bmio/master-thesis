# CueLens iOS – Rückverfolgbarkeit der Funktionsanforderungen

Stand: 24.08.2026. Source Candidate: `e66270a93a74fa435af03a8b2054f8f8738756cf`. Die Tabelle ordnet jede verbindliche Anforderung einer Implementierung und mindestens einem automatisierten Nachweis zu. Manuelle Distributionstests sind zusätzlich in der DoD-Prüfung ausgewiesen.

| ID | Implementierung | Automatisierter Nachweis |
|---|---|---|
| IOS-FUN-001 | `Config/Release.xcconfig`, `Info.plist` | `verify_release_configuration.sh` |
| IOS-FUN-002 | `StudyViewportPolicy.swift`, produktive Viewport-Sperre | `StudyViewportPolicyTests`, iPhone-/iPad-UI-Suite |
| IOS-FUN-003 | `AppLanguage`, `AppSettingsStore`, `LanguageButton` | `AppShellTests.testPersistedLanguageWinsAndToggleIsSavedWithoutRestart`, UI-Neustarttest |
| IOS-FUN-004 | `InfoFeedService`, `InfoFeedRepository`, `InfoMessageView` | `InfoMessageTests`, `NetworkServiceContractTests.testInfoFeedUsesGETAndExistingStrictDomainDecoder`, Feed-UI-Test |
| IOS-FUN-005 | positive Dismissed-ID-Menge in `AppSettingsStore` | `AppShellTests.testRepositoryFiltersOnlyDismissedIDsAndDoesNotPersistText` |
| IOS-FUN-006 | `NotificationConsentView`, App-Shell-Reihenfolge | `AppShellTests.testSuccessfulFeedShowsAppConsentBeforeAnySystemRequest`, Consent-UI-Test |
| IOS-FUN-007 | `BackgroundRefreshCoordinator` | `BackgroundRefreshCoordinatorTests` |
| IOS-FUN-008 | `NotificationCoordinator` und Reminder-Policy | `NotificationCoordinatorTests.testEligibleReminderUsesDeterministicIdentifierAndNeutralLocalizedText` |
| IOS-FUN-009 | `ActivationCoordinator`, `ActivationView` | `ActivationCoordinatorTests`, Aktivierungs-UI-Szenarien |
| IOS-FUN-010 | `KeychainAppTokenStore` | `KeychainAppTokenStoreTests`, `verify_persistence_security.sh` |
| IOS-FUN-011 | Aktivierung setzt externe Web-Einwilligung voraus; kein iOS-Gate | `verify_prestudy_security.sh`, Home-/Aktivierungs-UI-Tests |
| IOS-FUN-012 | `ExternalLinkCoordinator` mit sprachabhängiger HTTPS-Allowlist | `ExternalLinkCoordinatorTests.testCoordinatorOpensLanguageSpecificAllowlistedLinks` |
| IOS-FUN-013 | nackter `mailto:`-Rechtekontakt | `ExternalLinkCoordinatorTests.testConfigurationAllowsOnlyConfiguredPrivacyAndBareMailtoURLs`, Home-UI-Test |
| IOS-FUN-014 | `DemoSession` Matching mit Cue 000 und fünf sichtbaren Sekunden | `DemoSessionTests.testMatchingContainsBothChoicesExactlyOnceAndWaitsFiveVisibleTicks`, Demo-UI-Test |
| IOS-FUN-015 | `DemoSession` Labeling mit Cue 001 und lokalisierten Labels | `PreStudyAppModelTests.testDemoRunsLocallyThroughAllStepsAndIsDiscardedOnExit`, Demo-UI-Test |
| IOS-FUN-016 | flüchtiger Demo-Craving-Wert `0...100`, Start 50 | `DemoSessionTests.testDemoTransitionsDiscardSelectionsAndClampCraving`, Demo-UI-Test |
| IOS-FUN-017 | `FeedbackDraft`, `FeedbackCoordinator`, minimales Payload | `FeedbackCoordinatorTests`, `NetworkServiceContractTests.testFeedbackOmitsAbsentFieldAndSendsNoIdentityOrPlatformData` |
| IOS-FUN-018 | strikter boolescher Feature-Parser, fail-closed Start Gate | `NetworkServiceContractTests.testFeatureConfigOnlyExplicitBooleanTrueEnablesStudy`, `StartGateTests` |
| IOS-FUN-019 | `StudyStartGate` | `StartGateTests.testEveryPreconditionBlocksFailClosed` |
| IOS-FUN-020 | `ProductiveStudySession`, persistierte Matching-Permutation | `StudyRulesTests.testAllTwentySituationsHaveExpectedConditionAndFiveTrials`, Matching-UI-Test |
| IOS-FUN-021 | sichtzeitbasierter Vier-Sekunden-Countdown | `StudyRulesTests.testProductiveMatchingRequiresFourVisibleSecondsForEveryTrial` |
| IOS-FUN-022 | feste Labeling-Blöcke mit fünf Trials | `StudyRulesTests.testProductiveLabelingUsesFiveFixedTrialsWithoutPersistingAChoice`, Labeling-UI-Test |
| IOS-FUN-023 | injizierbare native Zufälligkeit und Invariantenprüfung | `StudyRulesTests.testMatchingOrderGenerationChecksInvariantNotConcreteOrder` |
| IOS-FUN-024 | `CravingValue`, produktiver Slider | `StudyRulesTests.testCravingAndSituationBoundaries`, Craving-UI-Tests |
| IOS-FUN-025 | `ProductiveStudyCoordinator` speichert Pending vor Request | `ProductiveStudyCoordinatorTests.testPendingPersistenceFailurePreventsFirstNetworkRequest` |
| IOS-FUN-026 | Pending-Retry aus geschütztem Zustand | `ProductiveStudyCoordinatorTests.testPendingRetryUsesStoredValueAndPersistsThreeHourProgress`, Retry-UI-Test |
| IOS-FUN-027 | `SelfReportResponse` und strikte Service-Decoder | `SelfReportResponseTests.testInvalidProtocolFixturesAreRejected`, `NetworkServiceContractTests.testSelfReportUsesMinimalPayloadAndStrictExistingDecoder` |
| IOS-FUN-028 | Release-Konfiguration `10800`, `Cooldown` | `StudyRulesTests.testCooldownRoundsUpAndUnlocksExactlyAtAvailability`, `verify_release_configuration.sh` |
| IOS-FUN-029 | zweiphasiger direkter Abschluss mit geschütztem Code | `ProductiveStudyCoordinatorTests.testFailedDirectConfirmationSurvivesRestartAndRetriesOnlyConfirmation`, Abschluss-UI-Test |
| IOS-FUN-030 | Prolific-Abschluss ohne Code | `ProductiveStudyCoordinatorTests.testProlificCompletionPersistsNoCodeAndNoCooldown`, Prolific-UI-Test |
| IOS-FUN-031 | explizite lokale Pasteboard-Aktion | UI-Test `testDirectCompletionShowsCodeAndCopiesOnlyAfterTap` |
| IOS-FUN-032 | zustandsabhängige Home-Ansicht lässt Feedback erreichbar | `PreStudyAppModelTests.testCompletionHidesDemoButKeepsFeedbackAvailable`, Abschluss-UI-Tests |
| IOS-FUN-033 | keine KI-, Kamera-, Foto- oder Medien-API/Berechtigung | `verify_hardening_security.sh`, `verify_release_configuration.sh` |
| IOS-FUN-034 | unverändertes minimales Submission-Payload und App-Version | `NetworkServiceContractTests.testSelfReportUsesMinimalPayloadAndStrictExistingDecoder`, `verify_submission_security.sh` |
| IOS-FUN-035 | keine CloudKit-/iCloud-/App-Group-Nutzung | `verify_hardening_security.sh`, `verify_release_archive.sh` |

## Interpretation

Die Zuordnung weist Implementierungs- und Testabdeckung nach, nicht automatisch eine reale Studienfreigabe. Insbesondere Notification-Verhalten, Data Protection bei Gerätesperre, beide Staging-Abschlüsse, TestFlight und Langzeitstabilität benötigen weiterhin die in `DEFINITION_OF_DONE_AUDIT.md` genannten externen Nachweise.
