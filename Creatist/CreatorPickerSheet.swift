import SwiftUI

struct CreatorPickerSheet: View {
    let genre: UserGenre
    let users: [User]
    let onSelect: (User) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            List(users, id: \ .id) { user in
                Button(action: { onSelect(user) }) {
                    HStack {
                        if let urlString = user.profileImageUrl, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable().aspectRatio(contentMode: .fill)
                                        .foregroundColor(.gray)
                                } else {
                                    ProgressView()
                                }
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                                .foregroundColor(.gray)
                        }
                        Text(user.name)
                            .padding(.leading, 8)
                    }
                }
            }
            .navigationTitle("Add Creator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
} 