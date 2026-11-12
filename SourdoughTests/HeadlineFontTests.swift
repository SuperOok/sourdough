import SwiftUI
import Testing
import UIKit
@testable import Sourdough

/// The headline face: registration from the bundle and the fallback.
@MainActor
struct HeadlineFontTests {
    /// A folder used as a bundle, holding a file with this name (relative to
    /// the folder) and the text "not a font" in it; `nil` for an empty folder.
    private func bundle(withFile file: String?) throws -> Bundle {
        let folder = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let file {
            let url = folder.appendingPathComponent(file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try Data("not a font".utf8).write(to: url)
        }
        return try #require(Bundle(path: folder.path))
    }

    @Test func theBundledFontCanBeRegisteredAndLoaded() {
        #expect(HeadlineFont.register(bundle: .main))
        let font = UIFont(name: HeadlineFont.name, size: 40)
        #expect(font != nil)
        #expect(font?.fontName == "Caveat-Bold")
        #expect(font?.familyName == "Caveat")
    }

    @Test func registeringAgainIsStillASuccess() {
        #expect(HeadlineFont.register(bundle: .main))
        #expect(HeadlineFont.register(bundle: .main))
        #expect(HeadlineFont.isAvailable())
    }

    @Test func aMissingFileIsNotRegistered() throws {
        #expect(!HeadlineFont.register(bundle: try bundle(withFile: nil)))
        #expect(!HeadlineFont.register(bundle: .main, resource: "NoSuchFont"))
    }

    @Test func aFileThatIsNoFontIsNotRegistered() throws {
        #expect(!HeadlineFont.register(bundle: try bundle(withFile: "Broken.ttf"), resource: "Broken"))
    }

    @Test func aFileInTheFontsFolderIsFoundToo() throws {
        let nested = try bundle(withFile: "Fonts/Nested.ttf")
        // Found (so CoreText refuses it, it is no font), not "missing".
        #expect(nested.url(forResource: "Nested", withExtension: "ttf") == nil)
        #expect(!HeadlineFont.register(bundle: nested, resource: "Nested"))
        #expect(nested.url(forResource: "Nested", withExtension: "ttf", subdirectory: "Fonts") != nil)
    }

    @Test func anUnknownNameIsNotAvailable() {
        #expect(!HeadlineFont.isAvailable("NoSuchFont-Bold"))
    }

    @Test func theHeadlineUsesCaveatWhenItIsThere() {
        HeadlineFont.register()
        #expect(HeadlineFont.font(size: 120) == .custom("Caveat-Bold", size: 120, relativeTo: .largeTitle))
    }

    @Test func theHeadlineFallsBackToBoldSerifWithoutTheFont() {
        #expect(HeadlineFont.font(name: "NoSuchFont-Bold", size: 120)
                == .system(size: 120, weight: .bold, design: .serif))
    }
}
