import SwiftUI

/// Section-level validation presentation footer.
/// Displays error messages underneath the rounded section container with native styling.
public struct SectionValidationFooter<Helper: View>: View {
    private let errorMessages: [String]
    private let isVisible: Bool
    private let helper: Helper?

    public init(
        result: FormValidationResult,
        fields: [String],
        isVisible: Bool,
        @ViewBuilder helper: () -> Helper
    ) {
        self.errorMessages = result.sectionErrorMessages(for: fields)
        self.isVisible = isVisible
        self.helper = helper()
    }

    public init(
        result: FormValidationResult,
        field: String,
        isVisible: Bool,
        @ViewBuilder helper: () -> Helper
    ) {
        self.init(result: result, fields: [field], isVisible: isVisible, helper: helper)
    }

    public var body: some View {
        let hasErrors = isVisible && !errorMessages.isEmpty

        if hasErrors {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(errorMessages, id: \.self) { messageKey in
                        Text(LocalizedStringKey(messageKey))
                            .font(.caption)
                            .foregroundStyle(Color(uiColor: .systemRed))
                    }
                }
                .padding(.top, 2)

                if let helper, !(Helper.self == EmptyView.self) {
                    helper
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let helper, !(Helper.self == EmptyView.self) {
            helper
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension SectionValidationFooter where Helper == EmptyView {
    public init(
        result: FormValidationResult,
        fields: [String],
        isVisible: Bool
    ) {
        self.errorMessages = result.sectionErrorMessages(for: fields)
        self.isVisible = isVisible
        self.helper = nil
    }

    public init(
        result: FormValidationResult,
        field: String,
        isVisible: Bool
    ) {
        self.init(result: result, fields: [field], isVisible: isVisible)
    }
}

extension SectionValidationFooter where Helper == Text {
    public init(
        result: FormValidationResult,
        fields: [String],
        isVisible: Bool,
        helperText: LocalizedStringKey
    ) {
        self.init(result: result, fields: fields, isVisible: isVisible) {
            Text(helperText)
                .font(.caption)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
    }

    public init(
        result: FormValidationResult,
        field: String,
        isVisible: Bool,
        helperText: LocalizedStringKey
    ) {
        self.init(result: result, fields: [field], isVisible: isVisible, helperText: helperText)
    }
}
