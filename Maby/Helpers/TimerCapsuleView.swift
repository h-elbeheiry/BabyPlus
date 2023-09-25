//
//  TimerCapsuleView.swift
//  BabyPlus
//
//  Created by Hussein Elbeheiry on 9/25/23.
//

import SwiftUI
import Combine

struct TimerCapsuleView: View {
    var duration: Int
    var stopAction: () -> Void
    @State private var buttonScale: CGFloat = 1.0

    func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        Rectangle() // Use Rectangle instead of Capsule
            .fill(Color.clear) // Explicitly set the fill color to clear
            .frame(height: 50)
            .clipShape(Capsule()) // Clip it to a capsule shape
            .background(
                VisualEffectView(effect: UIBlurEffect(style: .light))
            )
            .overlay(
                HStack {
                    Text(formatTime(seconds: duration))

                    Spacer()

                    Button(action: stopAction) {
                        ZStack {
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .background(Circle().foregroundColor(Color.red))
                                .frame(width: 24, height: 24)

                            Rectangle()
                                .foregroundColor(.white)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .scaleEffect(buttonScale)
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { isPressing in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                            buttonScale = isPressing ? 1.1 : 1.0
                        }
                    }, perform: { })
                }
                    .padding(.horizontal, 16)
            )
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?

    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        return UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

struct TimerCapsuleView_Previews: PreviewProvider {
    static var previews: some View {
        TimerCapsuleView(duration: 1200) {
            // This is a mock stop action for the preview.
            print("Stop button tapped.")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
