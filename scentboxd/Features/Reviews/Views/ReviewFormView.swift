//
//  ReviewFormView.swift
//  scentboxd
//
//  Created by Cupo on 22.01.26.
//

import SwiftUI

struct ReviewFormView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
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
    
    private enum Field: Hashable {
        case title, text
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
            ZStack {
                DesignSystem.Colors.bgDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Rating Section
                        VStack(spacing: 12) {
                            Text("Bewertung")
                                .font(DesignSystem.Fonts.serif(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.system(size: 36))
                                        .foregroundColor(star <= rating ? DesignSystem.Colors.champagne : Color.white.opacity(0.2))
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                rating = star
                                            }
                                        }
                                        .scaleEffect(star <= rating ? 1.1 : 1.0)
                                        .animation(.spring(response: 0.3), value: rating)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.vertical, 12)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(rating) von 5 Sternen")
                            .accessibilityValue("\(rating)")
                            .accessibilityAdjustableAction { direction in
                                switch direction {
                                case .increment:
                                    if rating < 5 { rating += 1 }
                                case .decrement:
                                    if rating > 1 { rating -= 1 }
                                @unknown default:
                                    break
                                }
                            }
                        }
                        .padding(.top, 8)
                        
                        // Title Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TITEL")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(DesignSystem.Colors.primary)
                            
                            TextField("Kurze Zusammenfassung", text: $title)
                                .focused($focusedField, equals: .title)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .text }
                                .foregroundColor(.white)
                                .padding(16)
                                .glassPanel()
                        }
                        .padding(.horizontal, 20)
                        
                        // Text Editor
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DEINE NOTIZEN")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(DesignSystem.Colors.primary)
                            
                            TextEditor(text: $text)
                                .focused($focusedField, equals: .text)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 180)
                                .padding(16)
                                .glassPanel()
                            
                            HStack {
                                if textCharCount < 10 {
                                    Text("Mindestens 10 Zeichen erforderlich (\(textCharCount)/10)")
                                        .foregroundColor(.orange)
                                } else {
                                    Text("\(textCharCount) Zeichen")
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                }
                                Spacer()
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 80)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Sticky Save Button
                VStack {
                    Spacer()
                    Button {
                        saveReview()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Speichern")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isFormValid || isSaving)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            colors: [DesignSystem.Colors.bgDark, DesignSystem.Colors.bgDark.opacity(0.9), .clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 100)
                        .allowsHitTesting(false)
                    )
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        ProgressView("Wird gespeichert…")
                            .foregroundColor(.white)
                            .padding(24)
                            .glassPanel()
                    }
                }
            }
            .navigationTitle(isEditing ? "Bewertung bearbeiten" : "Bewertung schreiben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.champagne)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") {
                        focusedField = nil
                    }
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
