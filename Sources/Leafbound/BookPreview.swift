import SwiftUI

struct BookPreview: View {
    let title: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("EBOOK EXPORT")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2)
                Spacer()
                Image(systemName: "book.closed")
                    .font(.system(size: 13, weight: .medium))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Palette.lime.opacity(0.90))

            ZStack {
                cover
                    .rotationEffect(.degrees(-9))
                    .shadow(color: .black.opacity(0.33), radius: 20, x: 12, y: 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                orbitLines
                    .padding(.horizontal, -28)
                    .accessibilityHidden(true)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 9) {
                Rectangle()
                    .fill(Palette.lime.opacity(0.22))
                    .frame(height: 1)
                    .padding(.bottom, 10)
                HStack(spacing: 7) {
                    Circle()
                        .fill(Palette.lime)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text("Reflowable EPUB")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.lime)
                }
                Text("Upload your EPUB with Send to Kindle to read it on your device.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.78, green: 0.83, blue: 0.72))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 31)
        .padding(.vertical, 29)
        .background(Color(red: 0.123, green: 0.228, blue: 0.155))
        .clipped()
    }

    private var orbitLines: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.50, y: size.height * 0.52)
            for index in 0..<8 {
                let radius = CGFloat(52 + index * 23)
                let ellipse = Path(ellipseIn: CGRect(
                    x: center.x - radius, y: center.y - radius,
                    width: 2 * radius, height: 2 * radius
                ))
                context.stroke(ellipse, with: .color(Palette.lime.opacity(0.12)), lineWidth: 0.7)
            }
        }
        .mask {
            LinearGradient(colors: [.clear, .white, .white, .clear], startPoint: .top, endPoint: .bottom)
        }
    }

    private var cover: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.89, green: 0.88, blue: 0.73))
                .offset(x: 6, y: 4)
            RoundedRectangle(cornerRadius: 6)
                .fill(Palette.lime)
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Palette.ink.opacity(0.25), lineWidth: 1)
            Rectangle()
                .fill(Palette.moss.opacity(0.14))
                .frame(width: 2)
                .padding(.leading, 12)
                .padding(.vertical, 1)
            VStack(alignment: .leading, spacing: 0) {
                LeafEngraving()
                    .frame(width: 112, height: 91)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                    .padding(.bottom, 14)
                Rectangle()
                    .fill(Palette.moss.opacity(0.38))
                    .frame(height: 1)
                    .padding(.bottom, 12)
                Text(title ?? "Your next\nread")
                    .font(.system(size: 27, weight: .regular, design: .serif))
                    .tracking(-0.8)
                    .lineLimit(3)
                    .minimumScaleFactor(0.65)
                    .frame(maxHeight: 80, alignment: .topLeading)
                Spacer(minLength: 5)
                Text(".epub")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .padding(.bottom, 16)
            }
            .foregroundStyle(Palette.moss)
            .padding(.leading, 26)
            .padding(.trailing, 17)
        }
        .frame(width: 190, height: 254)
    }
}

private struct LeafEngraving: View {
    var body: some View {
        Canvas { context, _ in
            var outline = Path()
            outline.move(to: CGPoint(x: 20, y: 77))
            outline.addQuadCurve(to: CGPoint(x: 51, y: 24), control: CGPoint(x: 22, y: 47))
            outline.addQuadCurve(to: CGPoint(x: 98, y: 8), control: CGPoint(x: 73, y: 6))
            outline.addQuadCurve(to: CGPoint(x: 78, y: 56), control: CGPoint(x: 96, y: 31))
            outline.addQuadCurve(to: CGPoint(x: 20, y: 77), control: CGPoint(x: 57, y: 79))
            outline.closeSubpath()
            context.stroke(outline, with: .color(Palette.moss), lineWidth: 1.4)

            var vein = Path()
            vein.move(to: CGPoint(x: 10, y: 86))
            vein.addQuadCurve(to: CGPoint(x: 96, y: 9), control: CGPoint(x: 53, y: 47))
            for step in 0..<6 {
                let offset = CGFloat(step)
                let start = CGPoint(x: 31 + offset * 8.8, y: 67 - offset * 7.9)
                vein.move(to: start)
                vein.addQuadCurve(
                    to: CGPoint(x: 33 + offset * 7.3, y: 43 - offset * 5.9),
                    control: CGPoint(x: start.x + 1, y: start.y - 9)
                )
                vein.move(to: start)
                vein.addQuadCurve(
                    to: CGPoint(x: 52 + offset * 7.05, y: 73 - offset * 9),
                    control: CGPoint(x: start.x + 9, y: start.y + 4)
                )
            }
            context.stroke(vein, with: .color(Palette.moss.opacity(0.77)), lineWidth: 0.8)

            for point in [CGPoint(x: 8, y: 30), CGPoint(x: 67, y: 84), CGPoint(x: 104, y: 48)] {
                var cross = Path()
                cross.move(to: CGPoint(x: point.x - 3, y: point.y))
                cross.addLine(to: CGPoint(x: point.x + 3, y: point.y))
                cross.move(to: CGPoint(x: point.x, y: point.y - 3))
                cross.addLine(to: CGPoint(x: point.x, y: point.y + 3))
                context.stroke(cross, with: .color(Palette.moss.opacity(0.57)), lineWidth: 0.7)
            }
        }
    }
}
