import Foundation
import Combine

class ChatWebSocketManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConnected: Bool = false
    @Published var typingUsers: Set<String> = []
    @Published var authError: Bool = false
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var url: URL
    private var token: String
    var userId: String
    private var cancellables = Set<AnyCancellable>()
    private var reconnectTimer: Timer?
    private var isGroupChat: Bool
    private var visionboardId: String?
    private var otherUserId: String?
    private var retryOnAuthError = true
    
    init(url: URL, token: String, userId: String, isGroupChat: Bool, visionboardId: String? = nil, otherUserId: String? = nil) {
        print("🔧 ChatWebSocketManager: Initializing...")
        print("🔧 ChatWebSocketManager: URL = \(url)")
        print("🔧 ChatWebSocketManager: isGroupChat = \(isGroupChat)")
        print("🔧 ChatWebSocketManager: visionboardId = \(visionboardId ?? "nil")")
        print("🔧 ChatWebSocketManager: otherUserId = \(otherUserId ?? "nil")")
        print("🔧 ChatWebSocketManager: userId = \(userId)")
        
        self.url = url
        self.token = token
        self.userId = userId
        self.isGroupChat = isGroupChat
        self.visionboardId = visionboardId
        self.otherUserId = otherUserId
        Task {
            await loadHistory()
            connect()
        }
    }
    
    func loadHistory() async {
        print("📚 ChatWebSocketManager: Loading chat history...")
        guard let tokenHeader = ("Bearer " + token).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { 
            print("❌ ChatWebSocketManager: Failed to encode token header")
            return 
        }
        var endpoint: String = ""
        if isGroupChat, let visionboardId = visionboardId {
            endpoint = "/v1/visionboard/\(visionboardId)/group-chat/messages"
            print("📚 ChatWebSocketManager: Group chat history endpoint = \(endpoint)")
        } else if let otherUserId = otherUserId {
            endpoint = "/v1/message/\(otherUserId)"
            print("📚 ChatWebSocketManager: Direct chat history endpoint = \(endpoint)")
        } else {
            print("❌ ChatWebSocketManager: No valid endpoint found")
            return
        }
        let restScheme = (url.scheme == "wss") ? "https" : "http"
        guard let host = url.host else { 
            print("❌ ChatWebSocketManager: No host found in URL")
            return 
        }
        let port = (url.port != nil) ? ":\(url.port!)" : ""
        let baseUrl = "\(restScheme)://\(host)\(port)"
        let urlString = baseUrl + endpoint
        print("📚 ChatWebSocketManager: REST URL = \(urlString)")
        guard let restUrl = URL(string: urlString) else { 
            print("❌ ChatWebSocketManager: Failed to create REST URL")
            return 
        }
        var request = URLRequest(url: restUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print("📚 ChatWebSocketManager: Making REST request to load history...")
        do {
            let (data, response) = try await NetworkManager.shared.authorizedRequest(request)
            guard let httpResponse = response as? HTTPURLResponse else { 
                print("❌ ChatWebSocketManager: Invalid HTTP response")
                return 
            }
            print("📚 ChatWebSocketManager: REST response status = \(httpResponse.statusCode)")
            guard httpResponse.statusCode == 200 else { 
                print("❌ ChatWebSocketManager: REST request failed with status \(httpResponse.statusCode)")
                return 
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                // Try fallback without fractional seconds
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let date = isoFormatter.date(from: dateString) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted.")
            }
            if let response = try? decoder.decode(ChatMessagesResponse.self, from: data) {
                let messages = response.messages
                print("📚 ChatWebSocketManager: Successfully loaded \(messages.count) messages from history")
                DispatchQueue.main.async {
                    self.messages = messages
                    print("📚 ChatWebSocketManager: Updated UI with \(self.messages.count) messages")
                }
            } else {
                print("❌ ChatWebSocketManager: Failed to decode messages from REST response")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📚 ChatWebSocketManager: REST response body = \(responseString)")
                }
            }
        } catch {
            print("❌ ChatWebSocketManager: Failed to load chat history: \(error)")
        }
    }
    
    func connect() {
        print("🔌 ChatWebSocketManager: Connecting to WebSocket...")
        disconnect()
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        print("🔌 ChatWebSocketManager: WebSocket task started")
        DispatchQueue.main.async { 
            self.isConnected = true 
            print("🔌 ChatWebSocketManager: Connection status set to true")
        }
        listen()
    }
    
    func disconnect() {
        print("🔌 ChatWebSocketManager: Disconnecting WebSocket...")
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async { 
            self.isConnected = false 
            print("🔌 ChatWebSocketManager: Connection status set to false")
        }
    }
    
    func listen() {
        print("👂 ChatWebSocketManager: Starting to listen for messages...")
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                print("❌ ChatWebSocketManager: WebSocket receive error: \(error)")
                if self.retryOnAuthError, let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
                    print("🔄 ChatWebSocketManager: Detected 401/403, attempting token refresh...")
                    Task { await self.handleAuthErrorAndReconnect() }
                } else if self.retryOnAuthError, error.localizedDescription.contains("403") || error.localizedDescription.contains("401") {
                    print("🔄 ChatWebSocketManager: Detected 401/403, attempting token refresh...")
                    Task { await self.handleAuthErrorAndReconnect() }
                } else {
                    DispatchQueue.main.async { self.isConnected = false }
                    self.reconnect()
                }
            case .success(let message):
                print("📨 ChatWebSocketManager: Received WebSocket message")
                switch message {
                case .string(let text):
                    print("📨 ChatWebSocketManager: Received string message: \(text)")
                    self.handleIncoming(text: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("📨 ChatWebSocketManager: Received data message: \(text)")
                        self.handleIncoming(text: text)
                    } else {
                        print("❌ ChatWebSocketManager: Failed to decode data message")
                    }
                @unknown default:
                    print("❌ ChatWebSocketManager: Unknown message type")
                    break
                }
                self.listen()
            }
        }
    }
    
    private func handleAuthErrorAndReconnect() async {
        self.retryOnAuthError = false
        let refreshed = await NetworkManager.shared.refreshToken()
        if refreshed, let newToken = KeychainHelper.get("accessToken") {
            print("🔄 ChatWebSocketManager: Token refreshed, reconnecting WebSocket...")
            let urlString = self.url.absoluteString
            let newUrlString: String
            if urlString.contains("token=") {
                let parts = urlString.components(separatedBy: "token=")
                newUrlString = parts[0] + "token=" + newToken
            } else {
                newUrlString = urlString
            }
            if let newUrl = URL(string: newUrlString) {
                self.url = newUrl
                self.token = newToken
                DispatchQueue.main.async {
                    self.isConnected = false
                }
                self.connect()
            } else {
                print("❌ ChatWebSocketManager: Failed to construct new WebSocket URL with refreshed token")
                DispatchQueue.main.async {
                    self.authError = true
                }
            }
        } else {
            print("❌ ChatWebSocketManager: Token refresh failed, logging out user")
            KeychainHelper.clearAllTokens()
            DispatchQueue.main.async {
                self.authError = true
            }
        }
        self.retryOnAuthError = true
    }
    
    func handleIncoming(text: String) {
        print("🔄 ChatWebSocketManager: Processing incoming message: \(text)")
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("🔄 ChatWebSocketManager: Successfully parsed JSON")
            
            // Group chat: message is a JSON string
            if let messageString = json["message"] as? String,
               let messageData = messageString.data(using: .utf8),
               let innerJson = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] {

                // Typing indicator (group chat)
                if let typing = innerJson["typing"] as? Bool, let userId = innerJson["user_id"] as? String {
                    print("⌨️ ChatWebSocketManager: Typing indicator - user: \(userId), typing: \(typing)")
                    DispatchQueue.main.async {
                        if typing {
                            self.typingUsers.insert(userId)
                        } else {
                            self.typingUsers.remove(userId)
                        }
                    }
                    return
                }

                // Group chat message
                if let senderId = innerJson["sender_id"] as? String, let message = innerJson["message"] as? String {
                    let createdAt: Date
                    if let ts = innerJson["created_at"] as? String, let date = ISO8601DateFormatter().date(from: ts) {
                        createdAt = date
                    } else {
                        createdAt = Date()
                    }
                    let avatarUrl = innerJson["avatar_url"] as? String ?? (json["avatar_url"] as? String)
                    let receiverId = innerJson["receiver_id"] as? String ?? ""
                    let id = json["timestamp"] as? String ?? UUID().uuidString

                    print("🆔 Received group chat message with id: \(id)")

                    let chatMessage = ChatMessage(
                        id: id,
                        senderId: senderId,
                        receiverId: receiverId,
                        message: message,
                        createdAt: createdAt,
                        avatarUrl: avatarUrl
                    )
                    DispatchQueue.main.async {
                        if !self.messages.contains(where: { $0.id == chatMessage.id }) {
                            self.messages.append(chatMessage)
                            print("📨 ChatWebSocketManager: Added group chat message to UI. Total messages: \(self.messages.count)")
                        } else {
                            print("🟡 ChatWebSocketManager: Duplicate message ignored (id: \(chatMessage.id))")
                        }
                    }
                    return
                }

                // If neither, ignore or log as unknown
                print("❌ ChatWebSocketManager: Unknown group chat message format")
                return
            }

            // Direct chat: message is a string
            if let senderId = json["sender_id"] as? String, let message = json["message"] as? String {
                print("📨 ChatWebSocketManager: Processing chat message from user: \(senderId)")
                let createdAt: Date
                if let ts = json["created_at"] as? String, let date = ISO8601DateFormatter().date(from: ts) {
                    createdAt = date
                    print("📨 ChatWebSocketManager: Using provided created_at: \(ts)")
                } else {
                    createdAt = Date()
                    print("📨 ChatWebSocketManager: Using current timestamp")
                }
                let avatarUrl = json["avatar_url"] as? String
                let receiverId = json["receiver_id"] as? String ?? ""
                let id = json["id"] as? String ?? UUID().uuidString
                print("📨 ChatWebSocketManager: Message details - avatarUrl: \(avatarUrl ?? "nil")")
                let chatMessage = ChatMessage(id: id, senderId: senderId, receiverId: receiverId, message: message, createdAt: createdAt, avatarUrl: avatarUrl)
                DispatchQueue.main.async {
                    if !self.messages.contains(where: { $0.id == chatMessage.id }) {
                        self.messages.append(chatMessage)
                        print("📨 ChatWebSocketManager: Added direct chat message to UI. Total messages: \(self.messages.count)")
                    } else {
                        print("🟡 ChatWebSocketManager: Duplicate message ignored (id: \(chatMessage.id))")
                    }
                }
            } else {
                print("❌ ChatWebSocketManager: Invalid message format - missing sender_id or message")
            }
        } else {
            print("❌ ChatWebSocketManager: Failed to parse incoming message as JSON")
        }
    }
    
    func sendMessage(_ message: String) {
        print("📤 ChatWebSocketManager: Sending message: \(message)")
        let json: [String: Any] = [
            "sender_id": userId,
            "receiver_id": otherUserId ?? "",
            "message": message,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        print("📤 ChatWebSocketManager: Message JSON: \(json)")
        
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let text = String(data: data, encoding: .utf8) {
            print("📤 ChatWebSocketManager: Sending WebSocket message: \(text)")
            webSocketTask?.send(.string(text)) { error in
                if let error = error {
                    print("❌ ChatWebSocketManager: WebSocket send error: \(error)")
                } else {
                    print("✅ ChatWebSocketManager: Message sent successfully")
                }
            }
        } else {
            print("❌ ChatWebSocketManager: Failed to serialize message to JSON")
        }
    }
    
    func sendTyping(isTyping: Bool) {
        print("⌨️ ChatWebSocketManager: Sending typing indicator: \(isTyping)")
        let json: [String: Any] = [
            "typing": isTyping,
            "user_id": userId
        ]
        print("⌨️ ChatWebSocketManager: Typing JSON: \(json)")
        
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let text = String(data: data, encoding: .utf8) {
            print("⌨️ ChatWebSocketManager: Sending typing WebSocket message: \(text)")
            webSocketTask?.send(.string(text)) { error in
                if let error = error {
                    print("❌ ChatWebSocketManager: Typing indicator send error: \(error)")
                } else {
                    print("✅ ChatWebSocketManager: Typing indicator sent successfully")
                }
            }
        } else {
            print("❌ ChatWebSocketManager: Failed to serialize typing indicator to JSON")
        }
    }
    
    func reconnect() {
        print("🔄 ChatWebSocketManager: Attempting to reconnect...")
        disconnect()
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            print("🔄 ChatWebSocketManager: Reconnect timer fired")
            self?.connect()
        }
    }
}

struct ChatMessagesResponse: Codable {
    let messages: [ChatMessage]
} 