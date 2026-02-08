//
//  ReviewFormView.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import SwiftUI

struct ReviewFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    let perfume: Perfume
    let existingReview: Review?
    let onSave: (Review) -> Void
    
    @State private var rating: Int = 1
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var isSaving: Bool = false
    
    private var isEditing: Bool { existingReview != nil }
    
    private var isFormValid: Bool {
        rating >= 1 && text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }
    
    private var textCharCount: Int {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count
    }
    
    init(perfume: Perfume, existingReview: Review? = nil, onSave: @escaping (Review) -> Void) {
        self.perfume = perfume
        self.existingReview = existingReview
        self.onSave = onSave
        
        if let review = existingReview {
            _rating = State(initialValue: review.rating)
            _title = State(initialValue: review.title)
            _text = State(initialValue: review.text)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Text("Bewertung")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.4))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            rating = star
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Section("Titel") {
                    TextField("Kurze Zusammenfassung", text: $title)
                }
                
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 150)
                } header: {
                    Text("Deine Notizen")
                } footer: {
                    HStack {
                        if textCharCount < 10 {
                            Text("Mindestens 10 Zeichen erforderlich (\(textCharCount)/10)")
                                .foregroundColor(.orange)
                        } else {
                            Text("\(textCharCount) Zeichen")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .font(.caption)
                }
            }
            .navigationTitle(isEditing ? "Bewertung bearbeiten" : "Bewertung schreiben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveReview()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Speichern")
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
        }
    }
    
    private func saveReview() {
        let review: Review
        if let existing = existingReview {
            existing.title = title
            existing.text = text
            existing.rating = rating
            review = existing
        } else {
            review = Review(
                title: title,
                text: text,
                rating: rating,
                createdAt: Date()
            )
        }
        onSave(review)
        dismiss()
    }
}

#Preview {
    ReviewFormView(perfume: Perfume(name: "Test")) { _ in }
}
