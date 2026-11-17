import SwiftUI

struct SplashScreenView: View {
    var onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.65
    @State private var logoOpacity: Double = 0
    @State private var textOffset: CGFloat = 24
    @State private var textOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 0.92
    @State private var isFadingOut: Bool = false

    private let gradientColors: [Color] = [
        Color(red: 0.0, green: 0.96, blue: 0.83),
        Color(red: 0.51, green: 0.22, blue: 0.93),
        Color(red: 1.0, green: 0.0, blue: 0.43),
        Color(red: 0.0, green: 0.96, blue: 0.83)
    ]

    var body: some View {
        ZStack {
            // Deep studio background
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.11, green: 0.08, blue: 0.22),
                    Color(red: 0.03, green: 0.04, blue: 0.07)
                ]),
                center: .center,
                startRadius: 40,
                endRadius: 680
            )
            .ignoresSafeArea()

            // Animated stardust & wave rings
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    // Floating particles
                    for i in 0..<28 {
                        let seed = Double(i) * 1.37
                        let angle = seed + time * (0.12 + Double(i % 4) * 0.03)
                        let radius = 130.0 + Double((i * 29) % 260) + sin(time * 0.8 + seed) * 16.0
                        let x = center.x + cos(angle) * radius
                        let y = center.y + sin(angle) * radius
                        let dotSize = 2.0 + Double(i % 3) * 1.5
                        let alpha = 0.25 + 0.35 * sin(time * 1.6 + seed)
                        let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                        let col = i % 2 == 0
                            ? Color(red: 0.0, green: 0.96, blue: 0.83).opacity(alpha)
                            : Color(red: 1.0, green: 0.0, blue: 0.43).opacity(alpha)
                        context.fill(Path(ellipseIn: rect), with: .color(col))
                    }
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    // Outer breathing aura
                    Circle()
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: gradientColors), center: .center),
                            lineWidth: 3
                        )
                        .frame(width: 230, height: 230)
                        .scaleEffect(pulseScale * 1.08)
                        .opacity(0.35)
                        .rotationEffect(.degrees(-ringRotation * 0.6))

                    // Main glowing ring
                    Circle()
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: gradientColors), center: .center),
                            lineWidth: 7
                        )
                        .frame(width: 176, height: 176)
                        .shadow(color: Color(red: 0.0, green: 0.96, blue: 0.83).opacity(0.45), radius: 22)
                        .rotationEffect(.degrees(ringRotation))
                        .scaleEffect(pulseScale)

                    // Dancing equalizer bars
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        HStack(spacing: 8) {
                            ForEach(0..<7, id: \.self) { idx in
                                let wave = sin(t * 5.2 + Double(idx) * 0.75)
                                let baseH: Double = [28, 48, 72, 86, 72, 48, 28][idx]
                                let h = CGFloat(max(16, baseH + wave * 22))
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.0, green: 0.96, blue: 0.83),
                                                Color(red: 0.65, green: 0.25, blue: 0.96),
                                                Color(red: 1.0, green: 0.0, blue: 0.43)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 9, height: h)
                            }
                        }
                    }
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 8) {
                    Text("AuraBeat")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white,
                                    Color(red: 0.0, green: 0.96, blue: 0.83),
                                    Color(red: 0.78, green: 0.55, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(red: 0.0, green: 0.96, blue: 0.83).opacity(0.3), radius: 14)

                    Text("ТВОЯ КАРМАННАЯ СТУДИЯ")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.68))
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
            }
        }
        .opacity(isFadingOut ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            finishSplash()
        }
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.72)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.75).delay(0.25)) {
                textOffset = 0
                textOpacity = 1.0
            }
            withAnimation(.linear(duration: 9.0).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulseScale = 1.04
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                finishSplash()
            }
        }
    }

    private func finishSplash() {
        guard !isFadingOut else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            isFadingOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            onFinished()
        }
    }
}
