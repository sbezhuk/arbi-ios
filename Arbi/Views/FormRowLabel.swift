import SwiftUI

// MARK: - Aligned Form Row Constants

public enum FormRowConstants {
    public static let labelFont: Font = .subheadline
    public static let iconWidth: CGFloat = 22
    public static let spacing: CGFloat = 8
}

// MARK: - Reusable Icon Component

/// Reusable icon component aligned to a fixed column
public struct FormRowIcon: View {
    public let systemImage: String
    public let color: Color
    public var font: Font = FormRowConstants.labelFont

    public init(
        systemImage: String,
        color: Color = .secondary,
        font: Font = FormRowConstants.labelFont
    ) {
        self.systemImage = systemImage
        self.color = color
        self.font = font
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(font)
            .frame(width: FormRowConstants.iconWidth, alignment: .leading)
            .foregroundStyle(color)
    }
}

// MARK: - Reusable Form Row Label Component

/// Reusable icon + text label component ensuring exact vertical and horizontal alignment
/// without artificial width constraints that truncate or wrap localized labels.
public struct FormRowLabel: View {
    public let title: LocalizedStringKey
    public let systemImage: String
    public let color: Color
    public let required: Bool

    public init(
        title: LocalizedStringKey,
        systemImage: String,
        color: Color = .secondary,
        required: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.required = required
    }

    public var body: some View {
        HStack(spacing: FormRowConstants.spacing) {
            FormRowIcon(systemImage: systemImage, color: color)
            HStack(spacing: 2) {
                Text(title)
                if required {
                    Text("*")
                        .foregroundStyle(.secondary)
                }
            }
            .font(FormRowConstants.labelFont.weight(.regular))
            .foregroundStyle(.primary)
            .lineLimit(1)
        }
        .lineLimit(1)
        .layoutPriority(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
