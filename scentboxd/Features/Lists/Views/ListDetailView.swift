//
//  ListDetailView.swift
//  scentboxd
//

import SwiftUI
import SwiftData
import os

struct ListDetailView: View {
    let list: CuratedListDTO
    let onListUpdated: (CuratedListDTO) -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.modelContext) private var modelContext

    @State private var perfumes: [Perfume] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showEditSheet = false
    @State private var currentList: CuratedListDTO
    @State private var perfumeToRemove: Perfume?
    @State private var showRemoveConfirm = false

    init(list: CuratedListDTO, onListUpdated: @escaping (CuratedListDTO) -> Void) {
        self.list = list
        self.onListUpdated = onListUpdated
        _currentList = State(initialValue: list)
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()

            if isLoading && perfumes.isEmpty {
                ProgressView()
                    .tint(DesignSystem.Colors.primary)
            } else if let error = errorMessage, perfumes.isEmpty {
                errorView(message: error)
            } else if perfumes.isEmpty {
                emptyView
            } else {
                perfumesGrid
            }
        }
        .navigationTitle(currentList.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .accessibilityLabel("Liste bearbeiten")
            }
        }
        .task {
            await loadPerfumes()
        }
        .sheet(isPresented: $showEditSheet) {
            ListEditSheet(mode: .edit(currentList)) { name, description, isPublic in
                await updateList(name: name, description: description, isPublic: isPublic)
            }
        }
        .confirmationDialog(
            "Parfum entfernen",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Entfernen", role: .destructive) {
                if let perfume = perfumeToRemove {
                    Task { await removePerfume(perfume) }
                }
            }
            Button("Abbrechen", role: .cancel) { perfumeToRemove = nil }
        } message: {
            if let perfume = perfumeToRemove {
                Text("\"\(perfume.name)\" aus dieser Liste entfernen?")
            }
        }
    }

    // MARK: - Grid

    private var perfumesGrid: some View {
        ScrollView(showsIndicators: false) {
            if let desc = currentList.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(perfumes) { perfume in
                    NavigationLink(destination: PerfumeDetailView(perfume: perfume)) {
                        PerfumeCardView(perfume: perfume)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            perfumeToRemove = perfume
                            showRemoveConfirm = true
                        } label: {
                            Label("Aus Liste entfernen", systemImage: "bookmark.slash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Empty & Error

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
            Text("Keine Parfums in dieser Liste")
                .font(DesignSystem.Fonts.serif(size: 18, weight: .bold))
                .foregroundStyle(Color.primary)
            Text("Füge Parfums über den \"Liste\"-Button auf der Parfum-Detailseite hinzu.")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
        }
        .padding(32)
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
                Task { await loadPerfumes() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadPerfumes() async {
        isLoading = true
        errorMessage = nil
        do {
            let ids = try await dependencies.curatedListDataSource.fetchListItems(listId: currentList.id)
            if ids.isEmpty {
                perfumes = []
            } else {
                perfumes = try await dependencies.perfumeRepository.fetchPerfumesByIds(ids)
            }
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.lists, context: "fetchListItems")
        }
        isLoading = false
    }

    private func removePerfume(_ perfume: Perfume) async {
        do {
            try await dependencies.curatedListDataSource.removePerfume(
                listId: currentList.id, perfumeId: perfume.id
            )
            perfumes.removeAll { $0.id == perfume.id }
            let updatedCount = max(0, (currentList.itemCount ?? 1) - 1)
            currentList = CuratedListDTO(
                id: currentList.id, userId: currentList.userId,
                name: currentList.name, description: currentList.description,
                isPublic: currentList.isPublic, createdAt: currentList.createdAt,
                itemCount: updatedCount
            )
            onListUpdated(currentList)
        } catch {
            AppLogger.lists.error("removePerfume: \(error.localizedDescription)")
        }
        perfumeToRemove = nil
    }

    private func updateList(name: String, description: String?, isPublic: Bool) async {
        do {
            try await dependencies.curatedListDataSource.updateList(
                listId: currentList.id, name: name, description: description, isPublic: isPublic
            )
            currentList = CuratedListDTO(
                id: currentList.id, userId: currentList.userId,
                name: name, description: description,
                isPublic: isPublic, createdAt: currentList.createdAt,
                itemCount: currentList.itemCount
            )
            onListUpdated(currentList)
        } catch {
            AppLogger.lists.error("updateList: \(error.localizedDescription)")
        }
    }
}
