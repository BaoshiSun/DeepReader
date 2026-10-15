import XCTest
@testable import DeepReaderCore

final class QuestionCreditTests: XCTestCase {
    func testQuestionBudgetPreservesQuestionAndUnicodeBoundaries() {
        let source = OrdinaryQuestions.source(selection: String(repeating: "选文🙂", count: 2000), context: String(repeating: "语境", count: 5000), previous: String(repeating: "旧答案", count: 5000), question: "耗能较高是有多高？")
        XCTAssertLessThanOrEqual(source.utf8.count, OrdinaryQuestions.maximumSourceBytes)
        XCTAssertTrue(source.hasPrefix("Current question:\n耗能较高是有多高？"))
        XCTAssertFalse(source.contains("�"))
        let explain = OrdinaryQuestions.source(selection: String(repeating: "x", count: 5000), context: String(repeating: "🙂", count: 5000))
        XCTAssertLessThanOrEqual(explain.utf8.count, OrdinaryQuestions.maximumSourceBytes)
    }
    func testGatewayRequiresHTTPSAndHasNoCredentialFallback() throws {
        for url in [nil, "", "http://gateway.test", "https://secret@gateway.test", "https://gateway.test/path", "https://gateway.test?key=x", "https://gateway.invalid"] {
            XCTAssertThrowsError(try OrdinaryQuestions.endpoint(url))
        }
        XCTAssertEqual(try OrdinaryQuestions.endpoint("https://gateway.test").host, "gateway.test")
        XCTAssertThrowsError(try AIClient.request(settings: Settings(), key: "leaked-key", task: .explain, source: "question", appStore: true))
    }
    func testStoreMigrationPinsOrdinaryModelAndChangesConsentRecipient() {
        var settings = Settings(); settings.provider = .qwen; settings.models[Provider.deepSeek.rawValue] = "deepseek-v4-pro"
        let old = settings.recipientID
        settings.applyProviderAvailability(appStore: true)
        XCTAssertEqual(settings.provider, .deepSeek)
        XCTAssertEqual(settings.model, "deepseek-flash")
        XCTAssertNotEqual(settings.sharingRecipient(appStore: true), old)
        XCTAssertEqual(Provider.available(appStore: true), [.deepSeek])
        XCTAssertEqual(Provider.available(appStore: false), Provider.allCases)
    }
    @MainActor func testHostedUnavailableFailsClosedWithoutDirectRequest() async {
        do {
            _ = try await AIClient(hosted: true).complete(settings: Settings(), key: "must-not-be-used", task: .explain, source: "question")
            XCTFail("Unconfigured gateway must not send or charge")
        } catch let error as ReaderError { XCTAssertEqual(error.chinese, OrdinaryQuestions.unavailable.chinese) }
        catch { XCTFail("Expected a safe configuration error") }
    }
}
