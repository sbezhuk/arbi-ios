import SwiftUI
import SwiftData

/// Dedicated view for browsing transaction history with SwiftData-backed incremental pagination.
struct TransactionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var periodIdentifier: String?

    @State private var loadedOrders: [P2POrder] = []
    @State private var isLoadingPage: Bool = false
    @State private var hasMorePages: Bool = true
    @State private var editingOrder: P2POrder?
    @State private var initialLoadCompleted: Bool = false

    private let pageSize: Int = TransactionsPaginationFetcher.defaultPageSize

    var body: some View {
        List {
            if loadedOrders.isEmpty && initialLoadCompleted && !isLoadingPage {
                ContentUnavailableView {
                    Label("trades.empty.no_transactions", systemImage: "arrow.triangle.swap")
                } description: {
                    if let period = periodIdentifier {
                        Text(LocalizationManager.shared.string("trades.empty.no_trades_in_period", PeriodRolloverService.formattedPeriodDisplay(period)))
                    } else {
                        Text("trades.empty.no_transactions")
                    }
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 24)
            } else {
                ForEach(Array(loadedOrders.enumerated()), id: \.element.id) { index, order in
                    Button {
                        editingOrder = order
                    } label: {
                        OrderRowView(order: order)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // Request next page when user approaches within 3 rows of the loaded list bottom
                        if index >= loadedOrders.count - 3 {
                            loadNextPage()
                        }
                    }
                }
                .onDelete(perform: deleteOrders)

                if isLoadingPage {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listSectionSpacing(8)
        .contentMargins(.bottom, 56, for: .scrollContent)
        .navigationTitle("trades.title.transactions")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            reload()
        }
        .onAppear {
            if !initialLoadCompleted {
                loadNextPage()
            }
        }
        .sheet(item: $editingOrder) { order in
            AddOrderView(orderToEdit: order)
        }
    }

    private func reload() {
        loadedOrders = []
        hasMorePages = true
        initialLoadCompleted = false
        loadNextPage()
    }

    private func loadNextPage() {
        guard !isLoadingPage && hasMorePages else { return }
        isLoadingPage = true

        do {
            let nextBatch = try TransactionsPaginationFetcher.fetchPage(
                modelContext: modelContext,
                periodIdentifier: periodIdentifier,
                offset: loadedOrders.count,
                limit: pageSize
            )

            if nextBatch.count < pageSize {
                hasMorePages = false
            }

            let existingIDs = Set(loadedOrders.map(\.id))
            let uniqueNew = nextBatch.filter { !existingIDs.contains($0.id) }
            loadedOrders.append(contentsOf: uniqueNew)
            initialLoadCompleted = true
            isLoadingPage = false
        } catch {
            hasMorePages = false
            initialLoadCompleted = true
            isLoadingPage = false
        }
    }

    private func deleteOrders(at offsets: IndexSet) {
        for index in offsets {
            let order = loadedOrders[index]
            modelContext.delete(order)
        }
        loadedOrders.remove(atOffsets: offsets)
        try? modelContext.save()
    }
}
