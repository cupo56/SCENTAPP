//
//  AddToListSheet.swift
//  scentboxd
//

import SwiftUI
import os

struct AddToListSheet: View {
    let perfume: Perfume

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var lists: [CuratedListDTO] = []
    @State private var memberListIds: Set<UUID> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var togglingIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.appBackground.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                } else if let error = errorMessage {
                    errorView(message: error)
                } else {
                    listContent
                }
            }
            .navigationTitle("Zu Liste hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Fertig")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
            .task {
                await loadData()
            }
            .sheet(isPresented: $showCreateSheet) {
                ListEditSheet(mode: .create) { name, description, isPublic in
                    await createAndAdd(name: name, description: description, isPublic: isPublic)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if lists.isEmpty {
                    emptyHint
                } else {
                    ForEach(lists) { list in
                        listRow(for: list)
                    }
                }

                Button {
                    showCreateSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DesignSystem.Colors.primary)
                        Text("Neue Liste erstellen")
                            .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                            .foregroundStyle(DesignSystem.Colors.primary)
                        Spacer()
                    }
                    .padding(16)
                    .glassPanel()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func listRow(for list: CuratedListDTO) -> some View {
        let isMember = memberListIds.contains(list.id)
        let isToggling = togglingIds.contains(list.id)

        return Button {
            Task { await toggleMembership(list: list) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isMember ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isMember ? DesignSystem.Colors.primary : Color(hex: "#94A3B8"))
                    .animation(.spring(duration: 0.25), value: isMember)

                VStack(alignment: .leading, spacing: 3) {
                    Text(list.name)
                        .font(DesignSystem.Fonts.display(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text("\(list.itemCount ?? 0) Parfums")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }

                Spacer()

                if isToggling {
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(16)
            .glassPanel()
            .opacity(isToggling ? 0.6 : 1)
        }
        .disabled(isToggling)
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 36))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
            Text("Noch keine Listen vorhanden")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
        }
        .padding(.vertical, 32)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red.opacity(0.8))
            Text(message)
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") {
                Task { await loadData() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        let perfumeId = perfume.id
        do {
            async let listsTask = dependencies.curatedListDataSource.fetchLists()
            async let memberIdsTask = dependencies.curatedListDataSource.fetchListIdsContaining(perfumeId: perfumeId)
            (lists, memberListIds) = try await (listsTask, memberIdsTask)
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.lists, context: "AddToListSheet load")
        }
        isLoading = false
    }

    private func toggleMembership(list: CuratedListDTO) async {
        let perfumeId = perfume.id
        let isMember = memberListIds.contains(list.id)
        togglingIds.insert(list.id)

        // Optimistic update
        if isMember {
            memberListIds.remove(list.id)
        } else {
            memberListIds.insert(list.id)
        }

        do {
            if isMember {
                try await dependencies.curatedListDataSource.removePerfume(
                    listId: list.id, perfumeId: perfumeId
                )
            } else {
                try await dependencies.curatedListDataSource.addPerfume(
                    listId: list.id, perfumeId: perfumeId
                )
            }
        } catch {
            // Rollback on failure
            if isMember {
                memberListIds.insert(list.id)
            } else {
                memberListIds.remove(list.id)
            }
            AppLogger.lists.error("toggleMembership: \(error.localizedDescription)")
        }

        togglingIds.remove(list.id)
    }

    private func createAndAdd(name: String, description: String?, isPublic: Bool) async {
        let perfumeId = perfume.id
        do {
            let created = try await dependencies.curatedListDataSource.createList(
                name: name, description: description, isPublic: isPublic
            )
            lists.insert(created, at: 0)
            // Direkt zur neuen Liste hinzufügen
            try await dependencies.curatedListDataSource.addPerfume(
                listId: created.id, perfumeId: perfumeId
            )
            memberListIds.insert(created.id)
        } catch {
            AppLogger.lists.error("createAndAdd: \(error.localizedDescription)")
        }
    }
}
