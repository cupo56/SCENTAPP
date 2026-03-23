import SwiftUI
import SwiftData
import Nuke
import NukeUI

struct PerfumeDetailView: View {
    @Environment(\.dependencies) private var container

    private let perfume: Perfume?
    private let perfumeId: UUID?

    init(perfume: Perfume) {
        self.perfume = perfume
        self.perfumeId = perfume.id
    }

    init(perfumeId: UUID) {
        self.perfume = nil
        self.perfumeId = perfumeId
    }

    var body: some View {
        Group {
            if let perfume {
                PerfumeDetailContent(
                    viewModel: container.makePerfumeDetailViewModel(perfume: perfume)
                )
            } else if let perfumeId {
                PerfumeDetailLoaderView(perfumeId: perfumeId)
            }
        }
    }
}

private struct PerfumeDetailLoaderView: View {
    @Environment(\.dependencies) private var container
    @Environment(\.modelContext) private var modelContext

    let perfumeId: UUID

    @State private var perfume: Perfume?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let perfume {
                PerfumeDetailContent(
                    viewModel: container.makePerfumeDetailViewModel(perfume: perfume)
                )
            } else if isLoading {
                ZStack {
                    DesignSystem.Colors.appBackground.ignoresSafeArea()
                    ProgressView("Parfum wird geladen...")
                        .tint(DesignSystem.Colors.primary)
                }
            } else {
                ContentUnavailableView(
                    "Parfum nicht gefunden",
                    systemImage: "exclamationmark.magnifyingglass",
                    description: Text(errorMessage ?? "Dieses Parfum konnte nicht geladen werden.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignSystem.Colors.appBackground)
            }
        }
        .task(id: perfumeId) {
            await loadPerfume()
        }
    }

    @MainActor
    private func loadPerfume() async {
        isLoading = true
        errorMessage = nil

        do {
            perfume = try await container.makePerfumeResolver().resolvePerfume(id: perfumeId, modelContext: modelContext)
            if perfume == nil {
                errorMessage = "Dieses Parfum existiert nicht oder konnte nicht geladen werden."
            }
        } catch {
            errorMessage = NetworkError.handle(error, logger: AppLogger.perfumes, context: "Deep Link")
        }

        isLoading = false
    }
}

/// Innere View, die den fertig injizierten ViewModel als @State haelt.
private struct PerfumeDetailContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(\.selectedTab) private var selectedTab
    @Environment(CompareSelectionManager.self) private var compareManager

    @State private var viewModel: PerfumeDetailViewModel
    @State private var isRenderingShare = false
    @State private var showPerfumeShareSheet = false
    @State private var perfumeShareImage: UIImage?
    @State private var loadTask: Task<Void, Never>?

    init(viewModel: PerfumeDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var perfume: Perfume { viewModel.perfume }

    var body: some View {
        GeometryReader { screenGeometry in
            ScrollView {
                VStack(spacing: 0) {

                    // ─── HERO IMAGE ───
                    HeroImageSection(perfume: perfume, heroHeight: max(screenGeometry.size.height * 0.6, 480))

                    // ─── CONTENT ───
                    VStack(alignment: .leading, spacing: 28) {
                        PerfumeHeaderSection(perfume: perfume, reviewService: viewModel.reviewService)

                        PerfumeActionsSection(
                            perfume: perfume,
                            viewModel: viewModel,
                            authManager: authManager,
                            modelContext: modelContext,
                            compareManager: compareManager,
                            isRenderingShare: isRenderingShare,
                            shareAction: { sharePerfume() }
                        )

                        FragrancePyramidSection(perfume: perfume)

                        PerfumePerformanceSection(perfume: perfume)

                        SimilarPerfumesSection(service: viewModel.similarService)

                        if let desc = perfume.desc, !desc.isEmpty {
                            PerfumeDescriptionSection(description: desc)
                        }

                        ReviewsSection(
                            viewModel: viewModel,
                            authManager: authManager,
                            modelContext: modelContext
                        )

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, -24)
                    .background(DesignSystem.Colors.appBackground)
                }
            }
            .ignoresSafeArea(.all, edges: .top)
            .background(DesignSystem.Colors.appBackground)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Bindable(viewModel).showReviewSheet, onDismiss: {
            viewModel.editingReview = nil
        }) {
            ReviewFormView(perfume: perfume, existingReview: viewModel.editingReview) { review in
                Task {
                    if viewModel.editingReview != nil {
                        await viewModel.updateReview(review, modelContext: modelContext)
                    } else {
                        await viewModel.saveReview(review, modelContext: modelContext)
                    }
                }
            }
        }
        .onAppear {
            loadTask?.cancel()
            loadTask = Task {
                await viewModel.loadCurrentUserId()
                
                guard !Task.isCancelled else { return }
                
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await viewModel.reviewService.loadReviews() }
                    group.addTask { await viewModel.reviewService.loadRatingStats() }
                    group.addTask { await viewModel.similarService.loadSimilarPerfumes(for: perfume.id) }
                }
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .alert("Anmeldung erforderlich", isPresented: Bindable(viewModel).showLoginAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Zum Profil") { selectedTab.wrappedValue = 3 }
        } message: {
            Text("Bitte melde dich an oder registriere dich, um diese Funktion zu nutzen.")
        }
        .errorAlert("Bewertungsfehler", isPresented: Bindable(viewModel.reviewService).showErrorAlert, message: viewModel.reviewService.errorMessage) {
            await viewModel.reviewService.loadReviews()
        }
        .errorAlert("Synchronisierungsfehler", isPresented: Bindable(viewModel.statusService).showSyncErrorAlert, message: viewModel.statusService.syncErrorMessage)
        .sheet(isPresented: $showPerfumeShareSheet) {
            if let perfumeShareImage {
                ShareSheet(items: [perfumeShareImage])
            }
        }
    }

    // MARK: - Share Perfume

    private func sharePerfume() {
        isRenderingShare = true
        Task {
            let image = await CollectionExportService.renderPerfumeImage(perfume: perfume)
            perfumeShareImage = image
            isRenderingShare = false
            if image != nil {
                showPerfumeShareSheet = true
            }
        }
    }
}

// MARK: - Hero Image

private struct HeroImageSection: View {
    let perfume: Perfume
    let heroHeight: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            if let url = perfume.imageUrl {
                Color.clear
                    .frame(height: heroHeight)
                    .overlay {
                        LazyImage(url: url) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                DesignSystem.Colors.appBackground
                            }
                        }
                        .transition(.opacity)
                    }
                    .clipped()
            } else {
                ZStack {
                    DesignSystem.Colors.appBackground
                    Image(systemName: "flame")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
                        .foregroundColor(.gray.opacity(0.2))
                }
                .frame(height: heroHeight)
            }

            VStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)

                Spacer()

                LinearGradient(
                    colors: [.clear, DesignSystem.Colors.appBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 140)
            }
            .frame(height: heroHeight)
        }
        .frame(height: heroHeight)
        .accessibilityLabel(String(localized: "Parfum-Bild von \(perfume.name)"))
    }
}
