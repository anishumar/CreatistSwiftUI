import SwiftUI

struct ChatView: View {
    @ObservedObject var manager: ChatWebSocketManager
    let currentUserId: String
    let title: String
    @State private var messageText: String = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    func avatarView(for msg: ChatMessage) -> some View {
        Group {
            if let urlString = msg.avatarUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image("defaultAvatar")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ProgressView()
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                if let _ = UIImage(named: "defaultAvatar") {
                    Image("defaultAvatar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(msg.senderId.prefix(2)).uppercased())
                                .font(.caption2)
                                .foregroundColor(.primary)
                        )
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding(.trailing, 4)
                }
                Text(title)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(manager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
            }
            .padding()
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(manager.messages.sorted(by: { $0.createdAt < $1.createdAt })) { msg in
                            let isMine = msg.senderId == currentUserId
                            HStack(alignment: .bottom, spacing: 8) {
                                if isMine {
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(msg.message)
                                            .padding(10)
                                            .background(Color.accentColor.opacity(0.2))
                                            .foregroundColor(.primary)
                                            .cornerRadius(12)
                                        Text(msg.createdAt, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(msg.message)
                                            .padding(10)
                                            .background(Color.gray.opacity(0.2))
                                            .foregroundColor(.primary)
                                            .cornerRadius(12)
                                        Text(msg.createdAt, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                            .id(msg.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: manager.messages.count) { _ in
                    if let last = manager.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            if !manager.typingUsers.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(manager.typingUsers), id: \ .self) { userId in
                        Text(userId == currentUserId ? "You" : "Someone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("is typing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 2)
            }
            Divider()
            HStack {
                TextField("Message...", text: $messageText, onEditingChanged: { editing in
                    manager.sendTyping(isTyping: editing)
                })
                .focused($isInputFocused)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: messageText) { newValue in
                    manager.sendTyping(isTyping: !newValue.isEmpty)
                }
                Button(action: {
                    let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    manager.sendMessage(trimmed)
                    messageText = ""
                    manager.sendTyping(isTyping: false)
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
    }
} 