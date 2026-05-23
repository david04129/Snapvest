//
//  RenameAccountSheet.swift
//  Snapvest
//

import SwiftUI

struct RenameAccountSheet: View {
    @ObservedObject var viewModel: AccountsViewModel
    let accountId: String
    let userId: String
    let accountType: AccountType
    let initialName: String
    var onRenamed: ((String) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    init(
        viewModel: AccountsViewModel,
        accountId: String,
        userId: String,
        accountType: AccountType,
        initialName: String,
        onRenamed: ((String) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.accountId = accountId
        self.userId = userId
        self.accountType = accountType
        self.initialName = initialName
        self.onRenamed = onRenamed
        _name = State(initialValue: initialName)
    }
    
    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var canSave: Bool {
        !trimmedName.isEmpty && trimmedName != initialName && !isSaving
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("帳戶名稱", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text("同一類別下的帳戶名稱不可重複。")
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.lossRed)
                    }
                }
            }
            .navigationTitle("重新命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        Task { @MainActor in
                            await save()
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    @MainActor
    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        let submittedName = trimmedName
        if let error = await viewModel.renameAccount(
            accountId: accountId,
            userId: userId,
            to: submittedName
        ) {
            errorMessage = error
        } else {
            onRenamed?(submittedName)
            dismiss()
        }
    }
}
