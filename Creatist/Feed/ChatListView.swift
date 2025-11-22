import SwiftUI

struct ChatListView: View {
    @State private var searchText: String = ""
    @State private var showNewChat = false
    // Add dummy data to make search bar visible
    let chats: [(id: UUID, name: String, lastMessage: String, unread: Int)] = [
        (UUID(), "John Doe", "Hey, how are you?", 2),
        (UUID(), "Jane Smith", "Thanks for the help!", 0),
        (UUID(), "Mike Johnson", "See you tomorrow", 1)
    ]
    var filteredChats: [(id: UUID, name: String, lastMessage: String, unread: Int)] {
        if searchText.isEmpty { return chats }
        return chats.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.lastMessage.localizedCaseInsensitiveContains(searchText) }
    }
    var body: some View {
        NavigationStack {
            if filteredChats.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundColor(.secondary)
                    Text("No chats yet")
                        .font(.title3).bold()
                        .foregroundColor(.primary)
                    Text("Start a new chat to connect with someone!")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredChats, id: \.id) { chat in
                        HStack {
                            Circle().fill(Color(.systemGray4)).frame(width: 44, height: 44)
                            VStack(alignment: .leading) {
                                Text(chat.name).font(.headline)
                                Text(chat.lastMessage).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            if chat.unread > 0 {
                                Text("\(chat.unread)")
                                    .font(.caption).bold()
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.green))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(PlainListStyle())
                .searchable(text: $searchText, prompt: "Search chats")
            }
        }
        .navigationTitle("Chats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showNewChat = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewChat) {
            NavigationView {
                VStack {
                    Text("Start a new chat")
                        .font(.title2)
                        .padding()
                    Spacer()
                    Button("Close") { showNewChat = false }
                        .padding()
                }
                .navigationTitle("New Chat")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

