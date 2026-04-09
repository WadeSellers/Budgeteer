import XCTest
@testable import Runway

final class HintManagerTests: XCTestCase {

    private var sut: HintManager!

    /// All UserDefaults keys that HintManager reads/writes.
    private static let allKeys: [String] = HintType.allCases.map(\.rawValue) + [
        "hintPurchaseCount",
        "hintAppOpenCount"
    ]

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // Wipe every HintManager-related key so each test starts from a
        // "fresh install" state.
        for key in Self.allKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        sut = HintManager()
    }

    override func tearDown() {
        // Clean up after ourselves so we don't leak state into other test
        // classes that may also use UserDefaults.standard.
        for key in Self.allKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        sut = nil
        super.tearDown()
    }

    // MARK: - Fresh install (defaults)

    func testFreshInstall_allHintsUnseen() {
        for hint in HintType.allCases {
            XCTAssertFalse(
                sut.shouldShow(hint),
                "\(hint) should NOT show on fresh install because thresholds have not been met"
            )
        }
    }

    func testFreshInstall_countersAreZero() {
        XCTAssertEqual(sut.purchaseCount, 0)
        XCTAssertEqual(sut.appOpenCount, 0)
    }

    // MARK: - shouldShow visibility conditions

    func testShouldShow_budget_requiresTwoAppOpens() {
        // Not visible with 0 opens
        XCTAssertFalse(sut.shouldShow(.budget))

        // Not visible with 1 open
        sut.trackAppOpen()
        XCTAssertFalse(sut.shouldShow(.budget))

        // Visible at exactly 2 opens
        sut.trackAppOpen()
        XCTAssertTrue(sut.shouldShow(.budget))

        // Still visible with more opens
        sut.trackAppOpen()
        XCTAssertTrue(sut.shouldShow(.budget))
    }

    func testShouldShow_totalSpend_requiresOnePurchase() {
        XCTAssertFalse(sut.shouldShow(.totalSpend))

        sut.trackPurchase()
        XCTAssertTrue(sut.shouldShow(.totalSpend))
    }

    func testShouldShow_keyboard_requiresOnePurchase() {
        XCTAssertFalse(sut.shouldShow(.keyboard))

        sut.trackPurchase()
        XCTAssertTrue(sut.shouldShow(.keyboard))
    }

    func testShouldShow_monthlyRemaining_requiresOnePurchase() {
        XCTAssertFalse(sut.shouldShow(.monthlyRemaining))

        sut.trackPurchase()
        XCTAssertTrue(sut.shouldShow(.monthlyRemaining))
    }

    // MARK: - shouldShow returns false for seen hints

    func testShouldShow_returnsFalseAfterMarkSeen() {
        // Meet all thresholds first
        sut.trackAppOpen()
        sut.trackAppOpen()
        sut.trackPurchase()

        for hint in HintType.allCases {
            XCTAssertTrue(sut.shouldShow(hint), "\(hint) should show before being marked seen")
            sut.markSeen(hint)
            XCTAssertFalse(sut.shouldShow(hint), "\(hint) should NOT show after being marked seen")
        }
    }

    // MARK: - markSeen

    func testMarkSeen_persistsAcrossInstances() {
        sut.trackAppOpen()
        sut.trackAppOpen()
        sut.markSeen(.budget)

        // Create a brand-new HintManager that reads from UserDefaults
        let freshManager = HintManager()
        XCTAssertFalse(freshManager.shouldShow(.budget),
                       "Hint should remain dismissed after creating a new HintManager instance")
    }

    func testMarkSeen_calledMultipleTimes_doesNotCrashOrToggle() {
        sut.trackPurchase()
        sut.markSeen(.totalSpend)
        sut.markSeen(.totalSpend)
        sut.markSeen(.totalSpend)

        XCTAssertFalse(sut.shouldShow(.totalSpend),
                       "Hint should stay dismissed even after multiple markSeen calls")
    }

    // MARK: - Each hint type has unique storage

    func testMarkSeen_oneType_doesNotAffectOthers() {
        // Meet all thresholds
        sut.trackAppOpen()
        sut.trackAppOpen()
        sut.trackPurchase()

        sut.markSeen(.budget)

        XCTAssertFalse(sut.shouldShow(.budget))
        XCTAssertTrue(sut.shouldShow(.totalSpend),
                      "Marking budget seen must not affect totalSpend")
        XCTAssertTrue(sut.shouldShow(.keyboard),
                      "Marking budget seen must not affect keyboard")
        XCTAssertTrue(sut.shouldShow(.monthlyRemaining),
                      "Marking budget seen must not affect monthlyRemaining")
    }

    func testMarkSeen_purchaseHints_independentOfBudgetHint() {
        sut.trackAppOpen()
        sut.trackAppOpen()
        sut.trackPurchase()

        sut.markSeen(.totalSpend)

        XCTAssertTrue(sut.shouldShow(.budget))
        XCTAssertFalse(sut.shouldShow(.totalSpend))
        XCTAssertTrue(sut.shouldShow(.keyboard))
        XCTAssertTrue(sut.shouldShow(.monthlyRemaining))
    }

    // MARK: - trackPurchase

    func testTrackPurchase_incrementsCount() {
        XCTAssertEqual(sut.purchaseCount, 0)

        sut.trackPurchase()
        XCTAssertEqual(sut.purchaseCount, 1)

        sut.trackPurchase()
        XCTAssertEqual(sut.purchaseCount, 2)

        sut.trackPurchase()
        XCTAssertEqual(sut.purchaseCount, 3)
    }

    func testTrackPurchase_persistsAcrossInstances() {
        sut.trackPurchase()
        sut.trackPurchase()

        let freshManager = HintManager()
        XCTAssertEqual(freshManager.purchaseCount, 2)
    }

    // MARK: - trackAppOpen

    func testTrackAppOpen_incrementsCount() {
        XCTAssertEqual(sut.appOpenCount, 0)

        sut.trackAppOpen()
        XCTAssertEqual(sut.appOpenCount, 1)

        sut.trackAppOpen()
        XCTAssertEqual(sut.appOpenCount, 2)
    }

    func testTrackAppOpen_persistsAcrossInstances() {
        sut.trackAppOpen()
        sut.trackAppOpen()
        sut.trackAppOpen()

        let freshManager = HintManager()
        XCTAssertEqual(freshManager.appOpenCount, 3)
    }

    // MARK: - resetAllHints (dev tools)

    func testResetAllHints_clearsSeenFlags() {
        sut.trackAppOpen()
        sut.trackAppOpen()
        sut.trackPurchase()

        // Mark every hint as seen
        for hint in HintType.allCases {
            sut.markSeen(hint)
        }

        sut.resetAllHints()

        // After reset, thresholds are also cleared, so nothing should show
        // until thresholds are met again.
        for hint in HintType.allCases {
            XCTAssertFalse(sut.shouldShow(hint),
                           "\(hint) should not show right after reset (thresholds cleared)")
        }
    }

    func testResetAllHints_clearsCounters() {
        sut.trackPurchase()
        sut.trackPurchase()
        sut.trackAppOpen()
        sut.trackAppOpen()

        sut.resetAllHints()

        XCTAssertEqual(sut.purchaseCount, 0)
        XCTAssertEqual(sut.appOpenCount, 0)
    }

    func testResetAllHints_hintsShowAgainOnceThresholdsMet() {
        sut.trackAppOpen()
        sut.trackAppOpen()
        sut.trackPurchase()
        for hint in HintType.allCases {
            sut.markSeen(hint)
        }

        sut.resetAllHints()

        // Re-meet thresholds
        sut.trackAppOpen()
        sut.trackAppOpen()
        sut.trackPurchase()

        for hint in HintType.allCases {
            XCTAssertTrue(sut.shouldShow(hint),
                          "\(hint) should be visible again after reset + meeting thresholds")
        }
    }

    func testResetAllHints_persistsAcrossInstances() {
        sut.trackPurchase()
        sut.markSeen(.keyboard)
        sut.resetAllHints()

        let freshManager = HintManager()
        XCTAssertEqual(freshManager.purchaseCount, 0)
        XCTAssertEqual(freshManager.appOpenCount, 0)
        XCTAssertFalse(freshManager.hintKeyboardSeen)
    }

    // MARK: - Edge cases

    func testThresholdBoundary_budgetAtExactlyTwoOpens() {
        sut.trackAppOpen()
        XCTAssertFalse(sut.shouldShow(.budget), "Should not show at 1 open")

        sut.trackAppOpen()
        XCTAssertTrue(sut.shouldShow(.budget), "Should show at exactly 2 opens")
    }

    func testThresholdBoundary_purchaseHintsAtExactlyOnePurchase() {
        let purchaseHints: [HintType] = [.totalSpend, .keyboard, .monthlyRemaining]

        for hint in purchaseHints {
            XCTAssertFalse(sut.shouldShow(hint), "\(hint) should not show with 0 purchases")
        }

        sut.trackPurchase()

        for hint in purchaseHints {
            XCTAssertTrue(sut.shouldShow(hint), "\(hint) should show with exactly 1 purchase")
        }
    }

    func testAppOpensDoNotAffectPurchaseHints() {
        // Many app opens but no purchases
        for _ in 0..<10 {
            sut.trackAppOpen()
        }

        XCTAssertFalse(sut.shouldShow(.totalSpend),
                       "totalSpend needs purchases, not app opens")
        XCTAssertFalse(sut.shouldShow(.keyboard),
                       "keyboard needs purchases, not app opens")
        XCTAssertFalse(sut.shouldShow(.monthlyRemaining),
                       "monthlyRemaining needs purchases, not app opens")
    }

    func testPurchasesDoNotAffectBudgetHint() {
        // Many purchases but no app opens
        for _ in 0..<10 {
            sut.trackPurchase()
        }

        XCTAssertFalse(sut.shouldShow(.budget),
                       "budget hint needs app opens, not purchases")
    }

    // MARK: - HintType raw values (storage key uniqueness)

    func testHintType_allRawValuesAreUnique() {
        let rawValues = HintType.allCases.map(\.rawValue)
        XCTAssertEqual(rawValues.count, Set(rawValues).count,
                       "Every HintType must use a unique UserDefaults key")
    }
}
