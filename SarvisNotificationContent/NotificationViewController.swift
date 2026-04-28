import UIKit
import UserNotifications
import UserNotificationsUI
import SwiftUI

/// Entry-point view controller for the Notification Content Extension.
/// Hosts the SwiftUI NotificationContentView as a child view controller,
/// pinned to the extension's view bounds.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {

    private var hostingController: UIViewController?

    // MARK: - UNNotificationContentExtension

    func didReceive(_ notification: UNNotification) {
        // Remove any previously installed hosting controller (shouldn't happen, but safe).
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        let contentView = NotificationContentView(notification: notification)
        let host = UIHostingController(rootView: contentView)
        host.view.backgroundColor = .clear

        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hostingController = host
    }
}
