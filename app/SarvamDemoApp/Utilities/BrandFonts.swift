// BrandFonts: Shared typography definitions for the Sarvam brand.
import CoreText
import SwiftUI

private enum BrandFontName {
  static let seasonMixMedium = "SeasonMix-Medium"
  static let matterRegular = "Matter-Regular"
  static let matterMedium = "Matter-Medium"
  static let matterSemiMonoRegular = "MatterSemiMono-Regular"
}

enum BrandFontRegistrar {
  private static let resources: [(fileName: String, postScriptName: String)] = [
    ("SeasonMix-Medium.otf", BrandFontName.seasonMixMedium),
    ("MatterRegular.otf", BrandFontName.matterRegular),
    ("MatterMedium.otf", BrandFontName.matterMedium),
    ("MatterSemiMonoRegular.otf", BrandFontName.matterSemiMonoRegular),
  ]

  static func registerFonts() {
    for resource in resources {
      guard let url = Bundle.main.url(
        forResource: resource.fileName,
        withExtension: nil,
        subdirectory: "Font"
      ) ?? Bundle.main.url(forResource: resource.fileName, withExtension: nil) else {
        assertionFailure("Missing bundled font: \(resource.fileName)")
        continue
      }

      var registrationError: Unmanaged<CFError>?
      let registered = CTFontManagerRegisterFontsForURL(
        url as CFURL,
        .process,
        &registrationError
      )

      #if DEBUG
      if !registered,
         let error = registrationError?.takeRetainedValue() {
        print("[App:Fonts] Could not register \(resource.postScriptName): \(error.localizedDescription)")
      }
      #endif
    }
  }
}

extension Font {
  static let brandTitle3 = Font.custom(
    BrandFontName.seasonMixMedium,
    size: 20,
    relativeTo: .title3
  )

  static let brandSubheadline = Font.custom(
    BrandFontName.matterRegular,
    size: 15,
    relativeTo: .subheadline
  )

  static let brandBody = Font.custom(
    BrandFontName.matterRegular,
    size: 17,
    relativeTo: .body
  )

  static let brandHeadline = Font.custom(
    BrandFontName.matterMedium,
    size: 17,
    relativeTo: .headline
  )

  static let brandCaption = Font.custom(
    BrandFontName.matterRegular,
    size: 12,
    relativeTo: .caption
  )

  static let brandMonospaced = Font.custom(
    BrandFontName.matterSemiMonoRegular,
    size: 17,
    relativeTo: .body
  )
}
