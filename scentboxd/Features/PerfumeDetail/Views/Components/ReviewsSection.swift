import SwiftUI
import SwiftData

struct ReviewsSection: View {
    let viewModel: PerfumeDetailViewModel
    let authManager: AuthManager
    let modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Community Reviews")
                    .font(DesignSystem.Fonts.serif(size: 22, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Spacer()
                if let total = viewModel.reviewService.reviewTotalCount, total > 0 {
                    Text("\(total)")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
            }

            // Content
            if viewModel.reviewService.isLoadingReviews {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(DesignSystem.Colors.primary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if viewModel.reviewService.reviews.isEmpty {
                Text("Noch keine Bewertungen vorhanden.")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.reviewService.reviews, id: \.id) { review in
                    ReviewCard(
                        review: review,
                        isOwn: review.userId == viewModel.currentUserId,
                        likeCount: viewModel.reviewService.likeCount(for: review.id),
                        isLiked: viewModel.reviewService.isLiked(review.id),
                        onEdit: {
                            viewModel.editingReview = review
                            viewModel.showReviewSheet = true
                        },
                        onDelete: {
                            Task { await viewModel.deleteReview(review, modelContext: modelContext) }
                        },
                        onToggleLike: {
                            if authManager.isAuthenticated {
                                Task { await viewModel.reviewService.toggleLike(reviewId: review.id) }
                            } else {
                                viewModel.showLoginAlert = true
                            }
                        }
                    )
                    .onAppear {
                        Task {
                            await viewModel.reviewService.loadMoreIfNeeded(currentReview: review)
                        }
                    }
                }

                if viewModel.reviewService.isLoadingMoreReviews {
                    HStack {
                        Spacer()
                        ProgressView("Lade weitere…")
                            .font(.caption)
                            .tint(DesignSystem.Colors.primary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }

            // Delete error banner
            if let deleteError = viewModel.reviewService.deleteErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(deleteError)
                        .font(.caption)
                        .foregroundColor(Color(hex: "#94A3B8"))
                    Spacer()
                    Button {
                        viewModel.reviewService.deleteErrorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }
                    .accessibilityLabel("Fehlermeldung schließen")
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // Write Review Button
            Button {
                if authManager.isAuthenticated {
                    Task { await viewModel.handleReviewButtonTapped() }
                } else {
                    viewModel.showLoginAlert = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.hasExistingReview ? "pencil" : "pencil.line")
                        .font(.system(size: 14))
                    Text(viewModel.hasExistingReview ? String(localized: "Bewertung bearbeiten") : String(localized: "Bewertung schreiben"))
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(12)
            }
            .accessibilityLabel(viewModel.hasExistingReview ? String(localized: "Bewertung bearbeiten") : String(localized: "Bewertung schreiben"))
            .accessibilityHint(authManager.isAuthenticated ? String(localized: "Öffnet das Bewertungsformular") : String(localized: "Anmeldung erforderlich"))
        }
        .padding(.top, 4)
    }
}
