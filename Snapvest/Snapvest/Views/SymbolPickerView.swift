//
//  SymbolPickerView.swift
//  Snapvest
//
//  Created on 2024
//

import SwiftUI

struct SymbolPickerView: View {
    let market: TradeMarket
    let onSelect: (String, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var items: [SymbolItem] = []
    @State private var filteredItems: [SymbolItem] = []
    @State private var filterTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    symbolList
                }
            }
            .navigationTitle(market == .crypto ? "選擇加密貨幣" : "選擇股票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
        .task {
            let loaded = SymbolListService.loadSymbols(market: market)
            items = loaded
            filteredItems = loaded
        }
        .onChange(of: searchText) { _, newValue in
            filterTask?.cancel()
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                filteredItems = items
                return
            }
            let query = newValue
            let currentItems = items
            filterTask = Task {
                do {
                    try await Task.sleep(for: .milliseconds(220))
                    guard !Task.isCancelled else { return }
                    let result = await Task.detached(priority: .userInitiated) {
                        SymbolListService.filter(items: currentItems, query: query, limit: 150)
                    }.value
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if searchText == query {
                            filteredItems = result
                        }
                    }
                } catch {}
            }
        }
        .onChange(of: items) { _, newValue in
            filterTask?.cancel()
            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                filteredItems = newValue
            } else {
                let query = searchText
                filterTask = Task {
                    let result = await Task.detached(priority: .userInitiated) {
                        SymbolListService.filter(items: newValue, query: query, limit: 150)
                    }.value
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if searchText == query { filteredItems = result }
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondaryText)
            TextField("搜尋代號或名稱", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .padding(12)
        .background(Color.secondaryBackground)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.tertiaryText)
            Text(searchText.isEmpty ? "載入中…" : "找不到符合的項目")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var symbolList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    Button(action: {
                        onSelect(item.symbol, item.name)
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Text(item.symbol)
                                .font(.headline)
                                .foregroundColor(.primaryText)
                                .frame(width: 80, alignment: .leading)
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundColor(.secondaryText)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.tertiaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if item.id != filteredItems.last?.id {
                        Divider()
                            .padding(.leading, 108)
                    }
                }
            }
        }
    }
}

#Preview {
    SymbolPickerView(market: .stockUS) { symbol, name in
        print("Selected: \(symbol) - \(name)")
    }
}
