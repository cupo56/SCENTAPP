//
//  ListsView.swift
//  scentboxd
//

import SwiftUI

struct ListsView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(AuthManager.self) private var authManager

    @State private var lists: [CuratedListDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var listToDelete: CuratedListDTO?
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            DesignSystem.Colors.appBackground.ignoresSafeArea()

            if isLoading && lists.isEmpty {
                ProgressView()
                    .tint(DesignSystem.Colors.primary)
            } else if let error = errorMessage, lists.isEmpty {
                errorView(message: error)
            } else if lists.isEmpty {
                emptyView
            } else {
                listContent
            }
        }
        .navigationTitle("Meine Listen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
                .accessibilityLabel("Neue Liste erstellen")
            }
        }
        .task {
            await loadLists()
        }
        .sheet(isPresented: $showCreateSheet) {
            ListEditSheet(mode: .create) { name, description, isPublic in
                await createList(name: name, description: description, isPublic: isPublic)
            }
        }
        .alert("Liste löschen", isPresented: $showDeleteConfirm) {
            Button("Löschen", role: .destructive) {
                if let list = listToDelete {
                    Task { await deleteList(list) }
                }
            }
            Button("Abbrechen", role: .cancel) { listToDelete = nil }
        } message: {
            if let list = listToDelete {
                Text("Möchtest du \"\(list.name)\" wirklich löschen? Alle Einträge gehen verloren.")
            }
        }
    }

    // MARK: - Content

    private var listContent: some View {
        List {
            ForEach(lists) { list in
                NavigationLink(destination: ListDetailView(list: list, onListUpdated: { updated in
                    if let idx = lists.firstIndex(where: { $0.id == updated.id }) {
                        lists[idx] = updated
                    }
                })) {
                    ListRowView(list: list)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        listToDelete = list
                        showDeleteConfirm = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty & Error

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.4))
            Text("Noch keine Listen")
                .font(DesignSystem.Fonts.serif(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
            Text("Erstelle deine erste kuratierte Parfum-Liste.")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
            Button {
                showCreateSheet = true
            } label: {
                Text("Liste erstellen")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Colors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
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
                Task { await loadLists() }
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignSystem.Colors.primary)
        }
        .padding()
    }

    // MARK: - Actions

    private func loadLists() async {
        isLoading = true
        errorMessage = nil
        do {
            lists = try await dependencies.curatedListDataSource.fetchLists()
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.lists, context: "fetchLists")
        }
        isLoading = false
    }

    private func createList(name: String, description: String?, isPublic: Bool) async {
        do {
            let created = try await dependencies.curatedListDataSource.createList(
                name: name, description: description, isPublic: isPublic
            )
            lists.insert(created, at: 0)
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.lists, context: "createList")
        }
    }

    private func deleteList(_ list: CuratedListDTO) async {
        do {
            try await dependencies.curatedListDataSource.deleteList(listId: list.id)
            lists.removeAll { $0.id == list.id }
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.lists, context: "deleteList")
        }
        listToDelete = nil
    }
}

// MARK: - List Row

private struct ListRowView: View {
    let list: CuratedListDTO

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            Image(systemName: list.isPublic ? "bookmark.fill" : "lock.fill")
                .font(.system(size: 16))
                .foregroundStyle(DesignSystem.Colors.champagne)
                .frame(width: 36, height: 36)
                .background(DesignSystem.Colors.champagne.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(DesignSystem.Fonts.display(size: 15, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(list.itemCount ?? 0) Parfums")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#94A3B8"))
                    if list.isPublic {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#94A3B8"))
                        Text("Öffentlich")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.primary.opacity(0.8))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#94A3B8"))
        }
        .padding(16)
        .glassPanel()
    }
}

// MARK: - List Edit Sheet (Erstellen + Bearbeiten)

struct ListEditSheet: View {
    enum Mode { case create; case edit(CuratedListDTO) }

    let mode: Mode
    let onSave: (String, String?, Bool) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var descriptionText = ""
    @State private var isPublic = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NAME")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(DesignSystem.Colors.primary)
                            TextField("z. B. Sommersprays", text: $name)
                                .textContentType(.name)
                                .foregroundStyle(Color.primary)
                                .padding(16)
                                .glassPanel()
                        }

                        // Beschreibung
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BESCHREIBUNG (OPTIONAL)")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(DesignSystem.Colors.primary)
                            TextEditor(text: $descriptionText)
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(Color.primary)
                                .frame(minHeight: 80, maxHeight: 160)
                                .padding(12)
                                .glassPanel()
                            Text("\(descriptionText.count)/500")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#94A3B8"))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        // Öffentlich Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Öffentlich")
                                    .font(DesignSystem.Fonts.display(size: 15, weight: .medium))
                                    .foregroundStyle(Color.primary)
                                Text("Andere Nutzer können diese Liste sehen")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#94A3B8"))
                            }
                            Spacer()
                            Toggle("", isOn: $isPublic)
                                .tint(DesignSystem.Colors.primary)
                                .labelsHidden()
                        }
                        .padding(16)
                        .glassPanel()

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Speichern
                        Button {
                            Task { await save() }
                        } label: {
                            if isSaving {
                                ProgressView().tint(.white).frame(maxWidth: .infinity)
                            } else {
                                Text(isEdit ? "Speichern" : "Liste erstellen")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving || descriptionText.count > 500)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEdit ? "Liste bearbeiten" : "Neue Liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .disabled(isSaving)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if case .edit(let list) = mode {
                name = list.name
                descriptionText = list.description ?? ""
                isPublic = list.isPublic
            }
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespaces)
        await onSave(name, trimmedDesc.isEmpty ? nil : trimmedDesc, isPublic)
        isSaving = false
        dismiss()
    }
}
