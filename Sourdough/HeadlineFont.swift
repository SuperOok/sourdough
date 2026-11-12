import CoreText
import SwiftUI

/// The handwriting face of the start headline: Caveat Bold (SIL OFL 1.1, The
/// Caveat Project Authors), shipped as `Fonts/Caveat-Bold.ttf`. It is
/// registered at run time, so the Info.plist needs no entry. If the file is
/// missing or cannot be registered, the headline falls back to the system
/// serif face in bold; the app never depends on the font.
enum HeadlineFont {
    /// The PostScript name of the face, as `Font.custom` wants it.
    static let name = "Caveat-Bold"
    /// File name (without extension) of the bundled face.
    static let resource = "Caveat-Bold"

    /// Registers the font file for this process. `true` if the face is usable
    /// afterwards: registered now, or registered before (which CoreText
    /// reports as an error, though nothing is wrong).
    @discardableResult
    static func register(bundle: Bundle = .main, resource: String = resource) -> Bool {
        guard let url = bundle.url(forResource: resource, withExtension: "ttf")
                ?? bundle.url(forResource: resource, withExtension: "ttf", subdirectory: "Fonts")
        else { return false }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return true }
        guard let failure = error?.takeRetainedValue() else { return false }
        return CFErrorGetCode(failure) == CTFontManagerError.alreadyRegistered.rawValue
    }

    /// Whether the system knows a face with this PostScript name. `Font.custom`
    /// cannot tell: it silently draws the system font for an unknown name.
    static func isAvailable(_ name: String = name) -> Bool {
        let descriptor = CTFontDescriptorCreateWithAttributes(
            [kCTFontNameAttribute: name] as CFDictionary)
        return CTFontDescriptorCreateMatchingFontDescriptor(descriptor, nil) != nil
    }

    /// The headline face at `size` points (scaled with Dynamic Type relative
    /// to `style`), or the bold system serif face if `name` is not available.
    static func font(name: String = name, size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        isAvailable(name)
            ? .custom(name, size: size, relativeTo: style)
            : .system(size: size, weight: .bold, design: .serif)
    }
}
