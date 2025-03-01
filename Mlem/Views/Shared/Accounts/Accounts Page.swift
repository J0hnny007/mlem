//
//  Instance and Community List View.swift
//  Mlem
//
//  Created by David Bureš on 27.03.2022.
//

import SwiftUI

struct AccountsPage: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var accountsTracker: SavedAccountTracker
    @Environment(\.forceOnboard) var forceOnboard
    
    @State private var isShowingInstanceAdditionSheet: Bool = false
    @State var selectedAccount: SavedAccount?
    
    @State var isShowingDeleteConfirm: Bool = false
    
    let onboarding: Bool
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        let instances = Array(accountsTracker.accountsByInstance.keys)
        
        Group {
            if onboarding || instances.isEmpty || isShowingInstanceAdditionSheet {
                AddSavedInstanceView(onboarding: onboarding,
                                     currentAccount: $selectedAccount)
            } else {
                List {
                    ForEach(instances, id: \.self) { instance in
                        Section(header: Text(instance)) {
                            ForEach(accountsTracker.accountsByInstance[instance] ?? []) { account in
                                Button(account.username) {
                                    dismiss()
                                    
                                    // this tiny delay prevents the modal dismiss animation from being cancelled
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                        appState.setActiveAccount(account)
                                    }
                                }
                                .swipeActions {
                                    Button("Remove", role: .destructive) {
                                        accountsTracker.removeAccount(account: account, appState: appState, forceOnboard: forceOnboard)
                                    }
                                }
                                .foregroundColor(appState.currentActiveAccount == account ? .secondary : .primary)
                            }
                        }
                    }
                    
                    Button {
                        isShowingInstanceAdditionSheet = true
                    } label: {
                        Label("Add Account", systemImage: AppConstants.switchUserSymbolName)
                    }
                    .accessibilityLabel("Add a new account.")
                    
                    Button(role: .destructive) {
                        isShowingDeleteConfirm = true
                    } label: {
                        Label("Delete Current Account", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .onAppear {
            self.selectedAccount = appState.currentActiveAccount
        }
        .onChange(of: selectedAccount) { account in
            guard let account else { return }
            appState.setActiveAccount(account)
        }
        .sheet(isPresented: $isShowingDeleteConfirm) {
            DeleteAccountView()
        }
    }
}
