import Foundation
import UserNotifications
import Observation
import UIKit
import Supabase
import os

// MARK: - Preferences Model

struct NotificationPreferences {
    var newReviews: Bool = true
    var reviewLikes: Bool = true
    var similarAdded: Bool = false
    var communityUpdates: Bool = false

    init() {}

    init(from dto: NotificationPreferencesDTO) {
        self.newReviews = dto.newReviews
        self.reviewLikes = dto.reviewLikes
        self.similarAdded = dto.similarAdded
        self.communityUpdates = dto.communityUpdates
    }
}

// MARK: - DTOs

struct NotificationPreferencesDTO: Codable {
    var newReviews: Bool
    var reviewLikes: Bool
    var similarAdded: Bool
    var communityUpdates: Bool

    enum CodingKeys: String, CodingKey {
        case newReviews = "new_reviews"
        case reviewLikes = "review_likes"
        case similarAdded = "similar_added"
        case communityUpdates = "community_updates"
    }
}

// MARK: - NotificationManager

@Observable
@MainActor
final class NotificationManager: NSObject {

    static let shared = NotificationManager()

    // MARK: - State

    var isPermissionGranted = false
    var isPermissionDetermined = false
    var preferences = NotificationPreferences()
    var isLoadingPreferences = false

    private let client = AppConfig.client
    private var currentDeviceToken: String?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func checkPermissionStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isPermissionDetermined = settings.authorizationStatus != .notDetermined
        isPermissionGranted = settings.authorizationStatus == .authorized
    }

    @discardableResult
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isPermissionGranted = granted
            isPermissionDetermined = true
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            AppLogger.notifications.error("Push-Berechtigung konnte nicht angefragt werden: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Device Token

    func registerDeviceToken(_ token: Data) async {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        currentDeviceToken = tokenString

        do {
            try await client.rpc("upsert_device_token", params: ["p_token": tokenString]).execute()
            AppLogger.notifications.debug("Device-Token registriert.")
        } catch {
            AppLogger.notifications.error("Device-Token konnte nicht gespeichert werden: \(error.localizedDescription)")
        }
    }

    func unregisterCurrentToken() async {
        guard let token = currentDeviceToken else { return }
        do {
            try await client.rpc("delete_device_token", params: ["p_token": token]).execute()
            currentDeviceToken = nil
            AppLogger.notifications.debug("Device-Token entfernt.")
        } catch {
            AppLogger.notifications.error("Device-Token konnte nicht entfernt werden: \(error.localizedDescription)")
        }
    }

    // MARK: - Preferences

    func loadPreferences() async {
        guard !isLoadingPreferences else { return }
        isLoadingPreferences = true
        defer { isLoadingPreferences = false }

        do {
            let dto: NotificationPreferencesDTO = try await client
                .from("notification_preferences")
                .select()
                .single()
                .execute()
                .value
            preferences = NotificationPreferences(from: dto)
        } catch {
            // Noch keine Präferenzen — Defaults verwenden, werden beim ersten Speichern angelegt
            AppLogger.notifications.debug("Keine gespeicherten Benachrichtigungseinstellungen gefunden.")
        }
    }

    func savePreferences() async {
        do {
            let dto = NotificationPreferencesDTO(
                newReviews: preferences.newReviews,
                reviewLikes: preferences.reviewLikes,
                similarAdded: preferences.similarAdded,
                communityUpdates: preferences.communityUpdates
            )
            try await client
                .from("notification_preferences")
                .upsert(dto)
                .execute()
            AppLogger.notifications.debug("Benachrichtigungseinstellungen gespeichert.")
        } catch {
            AppLogger.notifications.error("Benachrichtigungseinstellungen konnten nicht gespeichert werden: \(error.localizedDescription)")
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Zeigt Benachrichtigungen auch im Vordergrund an
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Verarbeitet Tap auf eine Benachrichtigung → Deep Link
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLinkString = userInfo["deepLink"] as? String,
           let url = URL(string: deepLinkString) {
            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .notificationDeepLink,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
        completionHandler()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let notificationDeepLink = Notification.Name("notificationDeepLink")
}
