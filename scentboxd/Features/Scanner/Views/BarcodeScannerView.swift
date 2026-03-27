//
//  BarcodeScannerView.swift
//  scentboxd
//

import SwiftUI
import VisionKit

struct BarcodeScannerView: View {
    @State private var viewModel: BarcodeScannerViewModel
    let onSelectPerfume: (Perfume) -> Void

    @Environment(\.dismiss) private var dismiss

    init(viewModel: BarcodeScannerViewModel, onSelectPerfume: @escaping (Perfume) -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onSelectPerfume = onSelectPerfume
    }

    var body: some View {
        ZStack {
            cameraLayer

            if viewModel.foundPerfume == nil {
                ScannerOverlayView()
            }

            closeButton

            if viewModel.isSearching {
                searchingOverlay
            }

            if let error = viewModel.errorMessage, viewModel.foundPerfume == nil {
                errorOverlay(message: error)
            }
        }
        .sheet(item: Binding(
            get: { viewModel.foundPerfume },
            set: { _ in }
        )) { perfume in
            PerfumeQuickPreviewSheet(
                perfume: perfume,
                onViewDetails: {
                    dismiss()
                    onSelectPerfume(perfume)
                },
                onRescan: {
                    viewModel.reset()
                }
            )
            .presentationDetents([.height(270)])
            .presentationDragIndicator(.hidden)
            .presentationBackgroundInteraction(.enabled)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var cameraLayer: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable { barcode in
                viewModel.handleScan(barcode)
            }
            .ignoresSafeArea()
        } else {
            DesignSystem.Colors.appBackground
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "camera.slash")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("Kamera nicht verfügbar")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.4))
                        .padding()
                }
            }
            Spacer()
        }
    }

    private var searchingOverlay: some View {
        Color.black.opacity(0.35)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.4)
                    Text("Suche Parfum…")
                        .foregroundColor(.white)
                        .font(.subheadline)
                }
                .padding(24)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
            }
    }

    private func errorOverlay(message: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundColor(.orange)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(DesignSystem.Colors.appText)
                Button("Erneut scannen") {
                    viewModel.reset()
                }
                .foregroundColor(DesignSystem.Colors.primary)
                .fontWeight(.medium)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.Colors.appBackground)
            .cornerRadius(16)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}
