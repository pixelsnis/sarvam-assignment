//
//  ColorExtensions.swift
//  SarvamDemoApp
//
//  Created by Aneesh on 27/08/26.
//

import SwiftUI

extension Color {
  init(hex: String) {
    let value = hex
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "#", with: "")
    
    let normalizedValue: String
    switch value.count {
    case 3:
      normalizedValue = value.map { "\($0)\($0)" }.joined()
    case 6, 8:
      normalizedValue = value
    default:
      self = Color(red: 1, green: 0, blue: 1)
      return
    }
    
    guard let hexValue = UInt64(normalizedValue, radix: 16) else {
      self = Color(red: 1, green: 0, blue: 1)
      return
    }
    
    let hasAlpha = normalizedValue.count == 8
    let red = Double((hexValue >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
    let green = Double((hexValue >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
    let blue = Double((hexValue >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
    let alpha = hasAlpha ? Double(hexValue & 0xFF) / 255 : 1
    
    self.init(red: red, green: green, blue: blue, opacity: alpha)
  }
}
