// File: ASC/App/AppDelegate.swift
// Purpose: Push notification registration for "Notify Instructor" and other alerts.
//          Registers device token with backend so instructors can receive push when students request sign-off.
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task { await PushRegistration.shared.sendTokenToBackend(tokenString) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ Push registration failed: \(error.localizedDescription)")
    }

    // Present notifications in foreground if desired
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}

// MARK: - Push registration (sends token to backend)

@MainActor
final class PushRegistration: ObservableObject {
    static let shared = PushRegistration()

    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func sendTokenToBackend(_ deviceToken: String) async {
        guard let token = KeychainHelper.readToken(), !token.isEmpty else { return }
        guard let url = URL(string: "\(kServerURL)/api/push/register.php") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode([
            "device_token": deviceToken,
            "platform": "ios"
        ])
        _ = try? await URLSession.shared.data(for: req)
    }
}
