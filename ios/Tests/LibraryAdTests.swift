// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
@testable import DeepReaderMobile

final class LibraryAdTests: XCTestCase {
    func testAdNeverInterruptsReadingSearchImportOrOtherTabs() {
        XCTAssertTrue(LibraryAdPolicy.eligible(tab: 0, reading: false, bookCount: 1, searching: false, busy: false, active: true))
        XCTAssertFalse(LibraryAdPolicy.eligible(tab: 0, reading: true, bookCount: 10, searching: false, busy: false, active: true))
        for tab in [1, 2] { XCTAssertFalse(LibraryAdPolicy.eligible(tab: tab, reading: false, bookCount: 10, searching: false, busy: false, active: true)) }
        XCTAssertFalse(LibraryAdPolicy.eligible(tab: 0, reading: false, bookCount: 0, searching: false, busy: false, active: true))
        XCTAssertFalse(LibraryAdPolicy.eligible(tab: 0, reading: false, bookCount: 10, searching: true, busy: false, active: true))
        XCTAssertFalse(LibraryAdPolicy.eligible(tab: 0, reading: false, bookCount: 10, searching: false, busy: true, active: true))
        XCTAssertFalse(LibraryAdPolicy.eligible(tab: 0, reading: false, bookCount: 10, searching: false, busy: false, active: false))
    }
    func testOnlyOneAdAfterThirdOrLastBookAndNeverInSearch() {
        for count in 0...50 {
            let slots = (0..<count).filter { LibraryAdPolicy.slot(after: $0, bookCount: count, searching: false) }
            XCTAssertEqual(slots, count == 0 ? [] : [min(3, count) - 1])
            XCTAssertFalse((0..<count).contains { LibraryAdPolicy.slot(after: $0, bookCount: count, searching: true) })
        }
    }
    func testAdExpiresBeforeGoogleOneHourLimit() {
        let now = Date()
        XCTAssertFalse(LibraryAdPolicy.fresh(loadedAt: nil, now: now))
        XCTAssertTrue(LibraryAdPolicy.fresh(loadedAt: now.addingTimeInterval(-3200), now: now))
        XCTAssertFalse(LibraryAdPolicy.fresh(loadedAt: now.addingTimeInterval(-3300), now: now))
        XCTAssertFalse(LibraryAdPolicy.fresh(loadedAt: now.addingTimeInterval(5), now: now))
    }
    @MainActor func testAdConsentIsSeparatePersistentAndRevocable() throws {
        let name = "AdTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let ads = LibraryAdvertising(defaults: defaults)
        XCTAssertFalse(ads.enabled)
        ads.choose(false)
        XCTAssertEqual(LibraryAdvertising(defaults: defaults).choice, "declined")
        ads.choose(true)
        XCTAssertTrue(LibraryAdvertising(defaults: defaults).enabled)
        ads.choose(false)
        XCTAssertFalse(ads.enabled)
        XCTAssertNil(ads.nativeAd)
    }
    func testDebugUsesOfficialTestAdsAndNeverRequestsTrackingPermission() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String, "ca-app-pub-9226197175186931~9369232249")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "DeepReaderNativeAdUnitID") as? String, "ca-app-pub-3940256099942544/3986624511")
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription"))
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "GADDelayAppMeasurementInit") as? Bool, true)
    }
}
