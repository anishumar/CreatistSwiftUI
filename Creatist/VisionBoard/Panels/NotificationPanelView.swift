import SwiftUI
import Foundation

struct NotificationPanelView: View {
    @ObservedObject var viewModel: NotificationViewModel
    @State private var commentText: [UUID: String] = [:]

    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.notifications.isEmpty {
                    Text("No notifications.").foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.notifications) { notification in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                iconForType(notification.objectType, notification.eventType)
                                Text(notification.message).font(.headline)
                            }
                            Text("Type: \(notification.objectType.capitalized), Event: \(notification.eventType.capitalized)").font(.caption)
                            Text("Status: \(notification.status.capitalized)").font(.caption)
                            if let created = notification.createdAt as Date? {
                                Text("Received: \(created, style: .date)").font(.caption2)
                            }
                            if notification.status == "unread" {
                                HStack {
                                    Button("Accept") {
                                        Task {
                                            await viewModel.respond(to: notification, response: "Accepted", comment: commentText[notification.id] ?? "")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    Button("Reject") {
                                        Task {
                                            await viewModel.respond(to: notification, response: "Rejected", comment: commentText[notification.id] ?? "")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                TextField("Comment (optional)", text: Binding(
                                    get: { commentText[notification.id] ?? "" },
                                    set: { commentText[notification.id] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                            } else {
                                Text("Responded: \(notification.status)").foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 8)
                        .onTapGesture {
                            handleNotificationClick(notification)
                        }
                    }
                }
            }
            .navigationTitle("Notifications")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
            .onAppear {
                Task { await viewModel.fetchNotifications() }
            }
        }
    }

    func iconForType(_ objectType: String, _ eventType: String) -> some View {
        let iconName: String
        switch objectType {
        case "visionboard": iconName = "rectangle.stack"
        case "message": iconName = "envelope"
        case "showcase": iconName = "star"
        default: iconName = "bell"
        }
        return Image(systemName: iconName).foregroundColor(.blue)
    }

    func handleNotificationClick(_ notification: NotificationItem) {
        // TODO: Route based on objectType/objectId
        // Example:
        // if notification.objectType == "visionboard" { ... }
    }
} 