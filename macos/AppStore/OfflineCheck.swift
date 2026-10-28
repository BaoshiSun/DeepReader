// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import DeepReaderCore

/// Opt-in packaged-build QA. Uses an isolated profile, also inside the sandbox for store builds.
@MainActor enum OfflineCheck {
    static func run(_ controller: ReaderWindow) async throws {
        let model = controller.model
        let folder = model.store.root.deletingLastPathComponent()
        let pdf = folder.appendingPathComponent("sample.pdf")
        try SmokeTest.makePDF(at: pdf)
        controller.open(pdf)
        guard let page = model.pdf.view.document?.page(at: 0), let text = page.string else {
            throw ReaderError("测试文件未打开。", "QA file did not open.")
        }
        model.pdf.view.setCurrentSelection(page.selection(for: (text as NSString).range(of: "The bank approved the loan.")), animate: false)
        model.explain(); try await wait(model)
        guard !model.answer.isEmpty, model.records.count == 1 else {
            throw ReaderError("本机模型未生成回答。", "Bundled inference failed: \(model.status)")
        }
        model.followup = "解释贷款的含义。"; model.ask(); try await wait(model)
        guard model.followup.isEmpty, model.records.count == 1 else {
            throw ReaderError("追问失败。", "Packaged follow-up failed.")
        }
        let saved = model.answer
        model.followup = "再解释一下"; model.ask(); model.stop()
        try await Task.sleep(nanoseconds: 300_000_000)
        guard model.answer == saved else { throw ReaderError("取消失败。", "Cancellation modified the answer.") }
        model.openSample()
        for _ in 0..<600 {
            if !model.opening && model.reader.ebook.ready { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard model.reader.ebook.ready, model.reader.url?.lastPathComponent == "Reading-Garden.txt" else {
            throw ReaderError("示例未打开。", "Bundled sample did not open. Status: \(model.status); loaded: \(model.reader.url?.lastPathComponent ?? "none"); ready: \(model.reader.ebook.ready)")
        }
        try "PASS: packaged app loaded bundled model, generated explanation/follow-up, preserved cancellation/history and opened bundled sample.\n".write(to: folder.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
    }
    static func wait(_ model: ReaderModel) async throws {
        for _ in 0..<2400 {
            if !model.busy { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        model.stop(); throw ReaderError("测试超时。", "Packaged inference timed out.")
    }
}
