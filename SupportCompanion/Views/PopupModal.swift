import SwiftUI

struct PopupModal: View {
    @Binding var isShowing: Bool
    var appState = AppStateManager.shared

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(Constants.Support.Labels.email)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                Spacer()
                Link(destination: URL(string: "mailto:\(appState.preferences.supportEmail)")!) {
                    Text(appState.preferences.supportEmail)
                        .foregroundColor(.blue)
                }
            }
            HStack {
                Text(Constants.Support.Labels.phone)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.leading)
                Spacer()
                Text(appState.preferences.supportPhone)
            }
            .padding(.bottom)
            
            ScButton(Constants.General.close){
                isShowing = false
            }
        }
        .padding()
        .frame(minWidth: 200, idealWidth: 300, maxWidth: 500, minHeight: 200)
        .background(Color.clear)
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}
