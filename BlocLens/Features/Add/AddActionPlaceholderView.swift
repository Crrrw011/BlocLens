import SwiftUI

struct AddActionPlaceholderView: View {
    let action: AddAction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSpacing.large) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 48))
                    .foregroundStyle(DesignColour.opticBlue)
                Text(action.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(L10n.Add.placeholderMessage)
                    .foregroundStyle(DesignColour.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(DesignSpacing.large)
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Add.done) { dismiss() }
                }
            }
        }
    }
}
