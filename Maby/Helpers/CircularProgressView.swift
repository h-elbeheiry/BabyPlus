//
//  CircularProgressView.swift
//  BabyPlus
//
//  Created by Hussein Elbeheiry on 9/25/23.
//

import SwiftUI

struct CircularProgressView: View {
    let currentDuration: Int
    let maxDuration: Int

    private var progress: Double {
        return Double(currentDuration) / Double(maxDuration)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.pink.opacity(0.5),
                    lineWidth: 30
                )
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    Color.pink,
                    style: StrokeStyle(
                        lineWidth: 30,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: progress)

            // Adding the text inside the circle
            Text(formatTime(seconds: currentDuration))
                .font(.title2)
                .foregroundColor(.pink)
        }
    }

    func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
