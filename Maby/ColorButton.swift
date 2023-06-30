//
//  ColorButton.swift
//  Maby
//
//  Created by Hussein Elbeheiry on 6/30/23.
//

import SwiftUI

public struct ColorButton: View {

    public enum AnimationType {
        case bell
        case plus
        case calendar
        case gear
    }

    public var image: Image
    public var colorImage: Image
    public var isSelected: Bool
    public var fromLeft: Bool
    public var toLeft: Bool
    public var animationType: AnimationType

    @State var t: CGFloat = 0
    @State var tForBg: CGFloat = 0

    var scale: CGFloat {
        1 + t * 0.2
    }

    public var body: some View {
        ZStack {
            ColorButtonBg(colorImage: colorImage, isSelected: isSelected, fromLeft: fromLeft, toLeft: toLeft, t: tForBg)
                .offset(x: 3, y: 3)
            switch animationType {
            case .bell:
                ColorButtonOutlineBell(image: image, t: t)
            case .plus:
                ColorButtonOutlinePlus(image: image, t: t)
            case .calendar:
                ColorButtonOutlineCalendar(image: image, fromLeft: fromLeft, t: t)
            case .gear:
                ColorButtonOutlineGear(image: image, t: t)
            }
        }
        .padding(8)
        .onAppear {
            if isSelected {
                tForBg = 1
            }
        }
        .onChange(of: isSelected) { newValue in
            if newValue {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 10).delay(0.15)) {
                    t = 1
                }
                withAnimation(.easeIn(duration: 0.3)) {
                    tForBg = 1
                }
            } else {
                t = 0
                withAnimation(.easeIn(duration: 0.3)) {
                    tForBg = 0
                }
            }
        }
    }
}

struct ColorButtonOutlineBell: View, Animatable {

    var image: Image
    var t: CGFloat

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    var angle: CGFloat {
        if t < 0.5 {
            return 2*t * 20
        }
        return 2*(1 - t) * 20
    }

    var body: some View {
        image
            .rotationEffect(Angle(degrees: angle), anchor: UnitPoint(x: 0.5, y: 0))
    }
}

struct ColorButtonOutlinePlus: View {

    var image: Image
    var t: CGFloat

    var body: some View {
        ZStack {
            image
            Image("colorTab3Plus")
                .rotationEffect(Angle(degrees: t * 90))
        }
    }
}

struct ColorButtonOutlineCalendar: View, Animatable {

    var image: Image
    var fromLeft: Bool
    var t: CGFloat

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    var body: some View {
        ZStack {
            image
                .offset(x: offset(maxValue: 5))
            Circle()
                .frame(width: 3)
                .offset(x: 3, y: 4)
                .offset(x: offset(maxValue: 8))
        }
    }

    func offset(maxValue: CGFloat) -> CGFloat {
        let max = fromLeft ? maxValue : -maxValue
        if t < 0.5 {
            return 2*t * max
        }
        return 2*(1 - t) * max
    }
}

struct ColorButtonOutlineGear: View {

    var image: Image
    var t: CGFloat

    var body: some View {
        image
            .rotationEffect(Angle(degrees: t * 50))
    }
}

struct ColorButtonBg: View {

    var colorImage: Image
    var isSelected: Bool
    var fromLeft: Bool
    var toLeft: Bool
    var t: CGFloat

    var offset: CGFloat {
        if isSelected {
            return fromLeft ? (t - 1) * 20 : (t - 1) * -15
        } else {
            return toLeft ? (t - 1) * 20 : (t - 1) * -15
        }
    }

    var body: some View {
        colorImage
            .scaleEffect(t)
            .offset(x: offset)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff

        self.init(red: Double(r) / 0xff, green: Double(g) / 0xff, blue: Double(b) / 0xff)
    }

    static var exampleGrey = Color(hex: "0C0C0C")
    static var exampleLightGrey = Color(hex: "#B1B1B1")
    static var examplePurple = Color(hex: "7D26FE")
}

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                    g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                    b = CGFloat(hexNumber & 0x0000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: 1)
                    return
                }
            }
        }

        return nil
    }
}

extension Color {
    static func hex(_ hex: String) -> Color {
        guard let uiColor = UIColor(hex: hex) else {
            return Color.red
        }
        return Color(uiColor)
    }
}
