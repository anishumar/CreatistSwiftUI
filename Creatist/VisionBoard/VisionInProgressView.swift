import SwiftUI
import Foundation

struct VisionInProgressView: View {
    let board: VisionBoard
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss
    @State private var showGroupChat = false
    @State private var groupChatManager: ChatWebSocketManager? = nil
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Vision In Progress!")
                .font(.largeTitle).bold()
            Text("\(board.name)")
                .font(.title2)
            Button(action: {
                if let user = Creatist.shared.user {
                    let urlString = "ws://localhost:8080/ws/visionboard/\(board.id.uuidString)/group-chat?token=\(KeychainHelper.get("accessToken") ?? "")"
                    if let url = URL(string: urlString) {
                        groupChatManager = ChatWebSocketManager(
                            url: url,
                            token: KeychainHelper.get("accessToken") ?? "",
                            userId: user.id.uuidString,
                            isGroupChat: true,
                            visionboardId: board.id.uuidString
                        )
                    }
                }
                showGroupChat = true
            }) {
                HStack {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Open Group Chat")
                }
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
            }
            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $showGroupChat) {
            if let user = Creatist.shared.user {
                if let manager = groupChatManager {
                    ChatView(
                        manager: manager,
                        currentUserId: user.id.uuidString,
                        title: "Group Chat"
                    )
                } else {
                    ProgressView("Initializing chat...")
                        .onAppear {
                            let urlString = "ws://localhost:8080/ws/visionboard/\(board.id.uuidString)/group-chat?token=\(KeychainHelper.get("accessToken") ?? "")"
                            if let url = URL(string: urlString) {
                                groupChatManager = ChatWebSocketManager(
                                    url: url,
                                    token: KeychainHelper.get("accessToken") ?? "",
                                    userId: user.id.uuidString,
                                    isGroupChat: true,
                                    visionboardId: board.id.uuidString
                                )
                            }
                        }
                }
            } else {
                ProgressView("Loading user...")
            }
        }
    }
} 