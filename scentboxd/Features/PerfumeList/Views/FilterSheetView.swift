//
//  FilterSheetView.swift
//  scentboxd
//

import SwiftUI

struct FilterSheetView: View {
    @EnvironmentObject var viewModel: PerfumeListViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Lokale Kopie für "Anwenden"-Logik
    @State private var draftFilter: PerfumeFilter
    @State private var draftSort: PerfumeSortOption
    @State private var noteInput: String = ""
    @State private var occasionInput: String = ""
    
    init(filter: PerfumeFilter, sort: PerfumeSortOption) {
        _draftFilter = State(initialValue: filter)
        _draftSort = State(initialValue: sort)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Sortierung
                Section {
                    Picker("Sortierung", selection: $draftSort) {
                        ForEach(PerfumeSortOption.allCases) { option in
                            Label(option.rawValue, systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                } header: {
                    Label("Sortierung", systemImage: "arrow.up.arrow.down")
                }
                
                // MARK: - Marke
                Section {
                    if viewModel.availableBrands.isEmpty {
                        Text("Lade Marken…")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Marke", selection: brandBinding) {
                            Text("Alle Marken").tag("")
                            ForEach(viewModel.availableBrands, id: \.self) { brand in
                                Text(brand).tag(brand)
                            }
                        }
                    }
                } header: {
                    Label("Marke", systemImage: "building.2")
                }
                
                // MARK: - Konzentration
                Section {
                    if viewModel.availableConcentrations.isEmpty {
                        Text("Lade Konzentrationen…")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Konzentration", selection: concentrationBinding) {
                            Text("Alle").tag("")
                            ForEach(viewModel.availableConcentrations, id: \.self) { conc in
                                Text(conc.uppercased()).tag(conc)
                            }
                        }
                    }
                } header: {
                    Label("Konzentration", systemImage: "drop.fill")
                }
                
                // MARK: - Longevity
                Section {
                    Picker("Longevity", selection: longevityBinding) {
                        Text("Alle").tag("")
                        ForEach(longevityOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                } header: {
                    Label("Longevity", systemImage: "clock.fill")
                }
                
                // MARK: - Sillage
                Section {
                    Picker("Sillage", selection: sillageBinding) {
                        Text("Alle").tag("")
                        ForEach(sillageOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                } header: {
                    Label("Sillage", systemImage: "wind")
                }
                
                // MARK: - Noten
                Section {
                    HStack {
                        TextField("Note hinzufügen…", text: $noteInput)
                            .textInputAutocapitalization(.words)
                            .onSubmit { addNote() }
                        Button(action: addNote) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(noteInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    if !draftFilter.noteNames.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(draftFilter.noteNames, id: \.self) { note in
                                ChipView(text: note) {
                                    draftFilter.noteNames.removeAll { $0 == note }
                                }
                            }
                        }
                    }
                } header: {
                    Label("Noten", systemImage: "leaf.fill")
                }
                
                // MARK: - Occasions
                Section {
                    HStack {
                        TextField("Occasion hinzufügen…", text: $occasionInput)
                            .textInputAutocapitalization(.words)
                            .onSubmit { addOccasion() }
                        Button(action: addOccasion) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(occasionInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    if !draftFilter.occasions.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(draftFilter.occasions, id: \.self) { occasion in
                                ChipView(text: occasion) {
                                    draftFilter.occasions.removeAll { $0 == occasion }
                                }
                            }
                        }
                    }
                } header: {
                    Label("Occasions", systemImage: "calendar")
                }
                
                // MARK: - Bewertung
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Min: \(String(format: "%.1f", draftFilter.minRating ?? 0))")
                            Spacer()
                            Text("Max: \(String(format: "%.1f", draftFilter.maxRating ?? 5))")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            Slider(
                                value: minRatingBinding,
                                in: 0...5,
                                step: 0.5
                            )
                            Text("–")
                            Slider(
                                value: maxRatingBinding,
                                in: 0...5,
                                step: 0.5
                            )
                        }
                        
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                Image(systemName: starImage(for: index))
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                            }
                            Spacer()
                            if draftFilter.minRating != nil || draftFilter.maxRating != nil {
                                Button("Zurücksetzen") {
                                    draftFilter.minRating = nil
                                    draftFilter.maxRating = nil
                                }
                                .font(.caption)
                            }
                        }
                    }
                } header: {
                    Label("Bewertung", systemImage: "star.fill")
                }
            }
            .navigationTitle("Filter & Sortierung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anwenden") {
                        applyFilters()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Alle zurücksetzen") {
                        draftFilter = PerfumeFilter()
                        draftSort = .nameAsc
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func addNote() {
        let trimmed = noteInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !draftFilter.noteNames.contains(trimmed) else { return }
        draftFilter.noteNames.append(trimmed)
        noteInput = ""
    }
    
    private func addOccasion() {
        let trimmed = occasionInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !draftFilter.occasions.contains(trimmed) else { return }
        draftFilter.occasions.append(trimmed)
        occasionInput = ""
    }
    
    private func applyFilters() {
        viewModel.activeFilter = draftFilter
        viewModel.sortOption = draftSort
        dismiss()
    }
    
    // MARK: - Bindings
    
    private var brandBinding: Binding<String> {
        Binding(
            get: { draftFilter.brandName ?? "" },
            set: { draftFilter.brandName = $0.isEmpty ? nil : $0 }
        )
    }
    
    private var concentrationBinding: Binding<String> {
        Binding(
            get: { draftFilter.concentration ?? "" },
            set: { draftFilter.concentration = $0.isEmpty ? nil : $0 }
        )
    }
    
    private var longevityBinding: Binding<String> {
        Binding(
            get: { draftFilter.longevity ?? "" },
            set: { draftFilter.longevity = $0.isEmpty ? nil : $0 }
        )
    }
    
    private var sillageBinding: Binding<String> {
        Binding(
            get: { draftFilter.sillage ?? "" },
            set: { draftFilter.sillage = $0.isEmpty ? nil : $0 }
        )
    }
    
    private var minRatingBinding: Binding<Double> {
        Binding(
            get: { draftFilter.minRating ?? 0 },
            set: { draftFilter.minRating = $0 > 0 ? $0 : nil }
        )
    }
    
    private var maxRatingBinding: Binding<Double> {
        Binding(
            get: { draftFilter.maxRating ?? 5 },
            set: { draftFilter.maxRating = $0 < 5 ? $0 : nil }
        )
    }
    
    // MARK: - Helpers
    
    private func starImage(for index: Int) -> String {
        let rating = draftFilter.minRating ?? 0
        if Double(index) + 1 <= rating { return "star.fill" }
        if Double(index) + 0.5 <= rating { return "star.leadinghalf.filled" }
        return "star"
    }
    
    private var longevityOptions: [String] {
        ["Schwach", "Moderat", "Langhaltend", "Sehr langhaltend", "Ewig"]
    }
    
    private var sillageOptions: [String] {
        ["Nah", "Moderat", "Stark", "Enorm"]
    }
}

// MARK: - Chip View

struct ChipView: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.15))
        .foregroundColor(.accentColor)
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout (horizontal Chip Wrap)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
