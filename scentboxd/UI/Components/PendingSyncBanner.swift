//
//  PendingSyncBanner.swift
//  scentboxd
//

import SwiftUI
import SwiftData

struct PendingSyncBanner: View {
    @Query(filter: #Predicate<Perfume> { $0.userMetadata?.hasPendingSync == true })
    private var pendingPerfumes: [Perfume]

    @Query(filter: #Predicate<Review> { $0.hasPendingSync == true })
    private var pendingReviews: [Review]

    private var totalPending: Int {
        pendingPerfumes.count + pendingReviews.count
    }

    var body: some View {
        if totalPending > 0 {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "\(totalPending) Änderung(en) nicht synchronisiert"))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Text(String(localized: "Wird beim nächsten Online-Start hochgeladen"))
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }

                Spacer()
            }
            .padding(12)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(10)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "\(totalPending) Änderungen noch nicht synchronisiert"))
        }
    }
}
