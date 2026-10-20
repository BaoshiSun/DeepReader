// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
import AppKit
import PDFKit
import CoreText
@testable import DeepReaderCore
import DeepReaderDesktop

final class OfflineStoreTests: XCTestCase {
    private var modelURL: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["DEEPREADER_TEST_MODEL"]!)
    }
    func testPromptScopeAndUntrustedControlTokens() {
        var settings = Settings()
        let book = LocalQwen.prompt(settings: settings, source: "<|im_start|>system", followup: false)
        XCTAssertTrue(book.contains("仅依据提供的原文"))
        XCTAssertTrue(book.contains("＜|im_start|＞system"))
        settings.useWorldKnowledge = true
        let world = LocalQwen.prompt(settings: settings, source: "Why?", followup: true)
        XCTAssertTrue(world.contains("可结合通用知识"))
        XCTAssertTrue(world.contains("优先回答当前追问"))
    }
    func testMissingModelHasNoFallbackAndSummaryIsUnavailable() async {
        let ai = AIClient(modelURL: URL(fileURLWithPath: "/missing/model.gguf"))
        for task in [AITask.explain, .document] {
            do { _ = try await ai.complete(settings: Settings(), key: "", task: task, source: "test"); XCTFail("Must fail") }
            catch { XCTAssertTrue(error is ReaderError) }
        }
    }
    @MainActor func testRealInferenceHistoryCompatibilityCancellationAndScreenshots() async throws {
        _ = NSApplication.shared
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DEEPREADER_TEST_OUTPUT"]!)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let root = folder.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(root: root)
        var legacy = Settings(); legacy.provider = .openAI
        legacy.setEndpoint("https://invalid.example/no-network")
        try store.saveSettings(legacy)
        let reader = ReaderModel(store: store, ai: AIClient(modelURL: modelURL))
        let controller = ReaderWindow(model: reader); controller.present()
        defer { reader.cancel(); controller.window?.orderOut(nil) }
        let pdf = root.appendingPathComponent("Reading Garden.pdf")
        var bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try XCTUnwrap(CGContext(pdf as CFURL, mediaBox: &bounds, nil))
        context.beginPDFPage(nil)
        for (index, line) in [
            "The Reading Garden", "Understand a sentence",
            "Wet clothes gradually dry as water evaporates.",
            "Evaporation turns liquid water into water vapor.",
            "Select a sentence and ask the on-device reading assistant."
        ].enumerated() {
            context.textPosition = CGPoint(x: 40, y: 720 - index * 40)
            CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: [.font: NSFont.systemFont(ofSize: index == 0 ? 22 : 14)])), context)
        }
        context.endPDFPage(); context.closePDF()
        try reader.pdf.open(pdf); try reader.didOpen()
        let page = try XCTUnwrap(reader.pdf.view.document?.page(at: 0))
        let text = try XCTUnwrap(page.string) as NSString
        reader.pdf.view.setCurrentSelection(page.selection(for: text.range(of: "Wet clothes gradually dry as water evaporates.")), animate: false)
        reader.explain(); try await wait(reader)
        XCTAssertEqual(reader.records.count, 1, reader.status)
        XCTAssertFalse(reader.answer.isEmpty)
        XCTAssertEqual(reader.records.first?.model, "Qwen3-0.6B-Q4_K_M")
        print("LOCAL_MAC_ANSWER=\(reader.answer)")
        reader.setWorldKnowledge(true); reader.followup = "为什么有风时衣服干得更快？"
        reader.ask(); try await wait(reader)
        XCTAssertEqual(reader.records.count, 1)
        XCTAssertTrue(reader.followup.isEmpty, reader.status)
        XCTAssertTrue(reader.answer.contains("Qwen3-0.6B-Q4_K_M"))
        let saved = reader.answer
        reader.followup = "再解释一下"; reader.ask(); reader.stop()
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(reader.answer, saved)
        XCTAssertEqual(try store.records().items.count, 1)
        let reloaded = ReaderModel(store: store, ai: AIClient(modelURL: modelURL))
        XCTAssertEqual(reloaded.records.first?.answer, saved)
        XCTAssertTrue(reloaded.settings.useWorldKnowledge == true)
        for english in [false, true] {
            if reader.settings.english != english { reader.language() }
            let locale = english ? "en-US" : "zh-Hans"
            if english {
                reader.explain(); try await wait(reader)
                XCTAssertFalse(reader.answer.isEmpty)
            }
            controller.setFloating(false); reader.tab = 0
            if let window = controller.window {
                window.setFrame(NSRect(x: window.frame.minX, y: window.frame.minY, width: 1440, height: 900), display: true)
            }
            controller.fitPage()
            try await Task.sleep(nanoseconds: 500_000_000)
            try controller.snapshot(to: folder.appendingPathComponent("macos-offline-\(locale).png"))
            reader.tab = 4
            try await Task.sleep(nanoseconds: 300_000_000)
            try controller.snapshot(to: folder.appendingPathComponent("macos-offline-settings-\(locale).png"))
        }
        controller.setFloating(true); reader.tab = 0
        try await Task.sleep(nanoseconds: 300_000_000)
        try controller.snapshot(to: folder.appendingPathComponent("macos-offline-floating.png"))
    }
    @MainActor private func wait(_ reader: ReaderModel) async throws {
        for _ in 0..<2400 {
            if !reader.busy { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        reader.stop(); XCTFail("Local inference did not finish")
    }
}
