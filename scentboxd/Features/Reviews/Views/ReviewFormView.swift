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
    let onSave: (Review) -> Void
    
    @State private var rating: Int = 3
    @State private var title: String = ""
    @State private var text: String = ""
    @State private var isSaving: Bool = false
    
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
                
                Section("Deine Notizen") {
                    TextEditor(text: $text)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Bewertung schreiben")
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
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveReview() {
        let review = Review(
            title: title,
            text: text,
            rating: rating,
            createdAt: Date()
        )
        onSave(review)
        dismiss()
    }
}

#Preview {
    ReviewFormView(perfume: Perfume(name: "Test")) { _ in }
}
