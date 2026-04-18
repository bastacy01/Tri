//
//  TypewriterText.swift
//  Tri
//
//  Created by Ben Stacy on 4/13/26.
//

import SwiftUI

struct RevealText: View {
    let content: Text
    var characterCount: Int  // needed to calculate animation duration
    var speed: Double = 0.04
    var font: Font = .system(size: 15, weight: .semibold, design: .serif)
    var triggerKey: String = ""

    @State private var revealed: CGFloat = 0

    var body: some View {
        content
            .font(font)
            .lineSpacing(6)
            .frame(maxWidth: 340, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.leading)
            .mask(
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: geo.size.width * revealed)
                        LinearGradient(
                            colors: [.black, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 24)
                        Spacer(minLength: 0)
                    }
                }
            )
            .task(id: "\(triggerKey)-\(characterCount)") {
                revealed = 0
                try? await Task.sleep(nanoseconds: 100_000_000)
                let duration = max(0.25, min(3.2, speed * Double(max(characterCount, 1))))
                withAnimation(.linear(duration: duration)) {
                    revealed = 1.1
                }
            }
    }
}
