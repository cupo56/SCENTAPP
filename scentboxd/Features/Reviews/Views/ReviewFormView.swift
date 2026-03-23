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
    @State private var longevity: Double = AppConfig.ReviewDefaults.longevity
    @State private var sillage: Double = AppConfig.ReviewDefaults.sillage
    @State private var selectedOccasions: [String] = []
    @State private var isSaving: Bool = false
    
    private var isEditing: Bool { existingReview != nil }
    
    private var isFormValid: Bool {
        rating >= 1
            && textCharCount >= AppConfig.ReviewDefaults.minTextLength
            && textCharCount <= AppConfig.ReviewDefaults.maxTextLength
            && title.count <= AppConfig.ReviewDefaults.maxTitleLength
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
            if let l = review.longevity { _longevity = State(initialValue: Double(l)) }
            if let s = review.sillage { _sillage = State(initialValue: Double(s)) }
            _selectedOccasions = State(initialValue: review.occasions)
        }
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.bgDark
                .ignoresSafeArea()
                .onTapGesture {
                    focusedField = nil
                }
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Schließen")
                    
                    Spacer()
                    
                    Spacer()
                    
                    Text("BEWERTUNG SCHREIBEN")
                        .font(.system(size: 12, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundColor(Color(hex: "#94A3B8"))
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.bgDark.opacity(0.8))
                .background(.ultraThinMaterial)
                .zIndex(10)
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // Title Section
                        VStack(spacing: 8) {
                            Text("Teile dein Erlebnis")
                                .font(DesignSystem.Fonts.serif(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Erfasse die Essenz des Moments")
                                .font(DesignSystem.Fonts.serif(size: 14))
                                .italic()
                                .foregroundColor(Color(hex: "#94A3B8"))
                        }
                        .padding(.top, 16)
                        
                        // Rating
                        ReviewRatingSection(rating: $rating)
                        
                        // Title Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                HStack(spacing: 6) {
                                    Text("ÜBERSCHRIFT")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                    Text("(OPTIONAL)")
                                        .font(.system(size: 10, weight: .medium))
                                        .tracking(0.5)
                                        .foregroundColor(Color(hex: "#64748B"))
                                }
                                .padding(.leading, 4)

                                Spacer()

                                if focusedField == .title {
                                    Button("Fertig") {
                                        focusedField = nil
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.champagne)
                                }
                            }

                            TextField("Deine Überschrift", text: $title)
                                .focused($focusedField, equals: .title)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .text }
                                .accessibilityLabel("Überschrift der Bewertung, optional")
                                .onChange(of: title) { _, newValue in
                                    if newValue.count > AppConfig.ReviewDefaults.maxTitleLength {
                                        title = String(newValue.prefix(AppConfig.ReviewDefaults.maxTitleLength))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(16)
                                .glassPanel()

                            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 11))
                                    Text("Ohne Überschrift wird automatisch „Bewertung für \(perfume.name)“ verwendet.")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(Color(hex: "#64748B"))
                                .padding(.leading, 4)
                            }
                        }
                        
                        // Text Area
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("PERSÖNLICHE NOTIZEN")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(hex: "#94A3B8"))
                                    .padding(.leading, 4)

                                Spacer()

                                if focusedField == .text {
                                    Button("Fertig") {
                                        focusedField = nil
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DesignSystem.Colors.champagne)
                                }
                            }

                            ZStack(alignment: .bottomTrailing) {
                                TextEditor(text: $text)
                                    .focused($focusedField, equals: .text)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 180)
                                    .padding(16)
                                    .padding(.bottom, 24)
                                    .glassPanel()
                                    .accessibilityLabel("Persönliche Notizen")
                                    .accessibilityHint("Mindestens \(AppConfig.ReviewDefaults.minTextLength) Zeichen")
                                    .onChange(of: text) { _, newValue in
                                        if newValue.count > AppConfig.ReviewDefaults.maxTextLength {
                                            text = String(newValue.prefix(AppConfig.ReviewDefaults.maxTextLength))
                                        }
                                    }

                                Text("\(textCharCount)/\(AppConfig.ReviewDefaults.maxTextLength)")
                                    .font(.system(size: 12))
                                    .foregroundColor(textCharCount > AppConfig.ReviewDefaults.maxTextLength ? .red : Color(hex: "#475569"))
                                    .padding(16)
                            }
                        }
                        
                        // Sliders Section
                        ReviewPerformanceSliders(longevity: $longevity, sillage: $sillage)

                        // Occasion Section
                        ReviewOccasionSection(selectedOccasions: $selectedOccasions)

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            
            // Sticky Bottom Button
            VStack {
                Spacer()
                Button {
                    saveReview()
                } label: {
                    HStack(spacing: 8) {
                        Text("EINTRAG VERÖFFENTLICHEN")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(1)
                            .textCase(.uppercase)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DesignSystem.Colors.primary)
                    .cornerRadius(12)
                    .shadow(color: DesignSystem.Colors.primary.opacity(0.2), radius: 10, y: 5)
                }
                .disabled(!isFormValid || isSaving)
                .opacity(isFormValid ? 1.0 : 0.5)
                .padding(.horizontal, 24)
                .accessibilityLabel("Eintrag veröffentlichen")
                .accessibilityHint("Doppeltippen, um die Bewertung zu speichern")
                .padding(.bottom, 24)
                .background(
                    LinearGradient(
                        colors: [DesignSystem.Colors.bgDark, DesignSystem.Colors.bgDark.opacity(0.9), .clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
                )
            }
            .ignoresSafeArea(.keyboard)
            
            if isSaving {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Wird gespeichert…")
                        .foregroundColor(.white)
                        .padding(24)
                        .glassPanel()
                }
            } else if !isFormValid && (rating < 1 || textCharCount > 0 && textCharCount < AppConfig.ReviewDefaults.minTextLength) {
                // To help users, show an indicator why they can't save
                VStack {
                    Spacer()
                    Text("Bitte vergib eine Bewertung (1-5 Sterne) und schreibe mindestens \(AppConfig.ReviewDefaults.minTextLength) Zeichen.")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 130)
                        .accessibilityLabel("Fehler: Bitte vergib eine Bewertung von 1 bis 5 Sternen und schreibe mindestens \(AppConfig.ReviewDefaults.minTextLength) Zeichen.")
                }
                .allowsHitTesting(false)
            }
        }
    }

    private func saveReview() {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? String(localized: "Bewertung für \(perfume.name)") 
            : title
        
        let review: Review
        if let existing = existingReview {
            existing.title = finalTitle
            existing.text = text
            existing.rating = rating
            existing.longevity = Int(longevity)
            existing.sillage = Int(sillage)
            existing.occasions = selectedOccasions
            review = existing
        } else {
            review = Review(
                title: finalTitle,
                text: text,
                rating: rating,
                longevity: Int(longevity),
                sillage: Int(sillage),
                occasions: selectedOccasions,
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
