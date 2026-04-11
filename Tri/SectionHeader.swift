import SwiftUI

struct SectionHeader: View {
    let title: String
    let buttonSystemName: String?
    let buttonAction: (() -> Void)?
    let includeHorizontalPadding: Bool

    init(
        title: String,
        buttonSystemName: String? = nil,
        buttonAction: (() -> Void)? = nil,
        includeHorizontalPadding: Bool = true
    ) {
        self.title = title
        self.buttonSystemName = buttonSystemName
        self.buttonAction = buttonAction
        self.includeHorizontalPadding = includeHorizontalPadding
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .serif))
            Spacer()
            if let buttonSystemName, let buttonAction {
                Button(action: buttonAction) {
                    Image(systemName: buttonSystemName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.automatic)
            }
        }
        .padding(.horizontal, includeHorizontalPadding ? 20 : 0)
        .padding(.top, 12)
    }
}
