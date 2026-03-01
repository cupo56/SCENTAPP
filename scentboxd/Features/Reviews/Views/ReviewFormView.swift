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
    @State private var longevity: Double = 65
    @State private var sillage: Double = 30
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
            if let l = review.longevity { _longevity = State(initialValue: Double(l)) }
            if let s = review.sillage { _sillage = State(initialValue: Double(s)) }
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
                            Text("Dein Duft-Tagebuch")
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
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 36))
                                    .foregroundColor(star <= rating ? DesignSystem.Colors.champagne : Color.white.opacity(0.2))
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            rating = star
                                        }
                                    }
                                    .scaleEffect(star <= rating ? 1.1 : 1.0)
                            }
                        }
                        
                        // Title Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("ÜBERSCHRIFT")
                                    .font(.system(size: 12, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(hex: "#94A3B8"))
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
                                .foregroundColor(.white)
                                .padding(16)
                                .glassPanel()
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

                                Text("\(textCharCount)/500")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#475569"))
                                    .padding(16)
                            }
                        }
                        
                        // Sliders Section
                        VStack(spacing: 24) {
                            // Longevity
                            VStack(spacing: 16) {
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock")
                                            .foregroundColor(DesignSystem.Colors.champagne)
                                        Text("Haltbarkeit")
                                            .foregroundColor(.white)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                    Text(longevityText)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(DesignSystem.Colors.primary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                Slider(value: $longevity, in: 0...100)
                                    .tint(DesignSystem.Colors.champagne)
                                
                                HStack {
                                    Text("Flüchtig")
                                    Spacer()
                                    Text("Ewig")
                                }
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#64748B"))
                            }
                            .padding(20)
                            .glassPanel()
                            
                            // Sillage
                            VStack(spacing: 16) {
                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "wind")
                                            .foregroundColor(DesignSystem.Colors.champagne)
                                        Text("Sillage")
                                            .foregroundColor(.white)
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                    Text(sillageText)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(DesignSystem.Colors.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(DesignSystem.Colors.primary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                Slider(value: $sillage, in: 0...100)
                                    .tint(DesignSystem.Colors.champagne)
                                
                                HStack {
                                    Text("Hautnah")
                                    Spacer()
                                    Text("Raumfüllend")
                                }
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#64748B"))
                            }
                            .padding(20)
                            .glassPanel()
                        }
                        
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
            }
        }
    }
    
    private var longevityText: String {
        if longevity < 33 { return "Flüchtig" }
        else if longevity < 66 { return "Moderat" }
        else { return "Ewig" }
    }
    
    private var sillageText: String {
        if sillage < 33 { return "Hautnah" }
        else if sillage < 66 { return "Moderat" }
        else { return "Raumfüllend" }
    }
    
    private func saveReview() {
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? "Bewertung für \(perfume.name)" 
            : title
        
        let review: Review
        if let existing = existingReview {
            existing.title = finalTitle
            existing.text = text
            existing.rating = rating
            existing.longevity = Int(longevity)
            existing.sillage = Int(sillage)
            review = existing
        } else {
            review = Review(
                title: finalTitle,
                text: text,
                rating: rating,
                longevity: Int(longevity),
                sillage: Int(sillage),
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
