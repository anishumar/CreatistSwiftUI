import SwiftUI
import Foundation

struct InvitationPanelView: View {
    @ObservedObject var viewModel: InvitationListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading invitations...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding()
                    } else if viewModel.invitations.isEmpty {
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.white.opacity(0.2),
                                                        Color.clear
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "envelope.open")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.secondary)
                                    .opacity(0.8)
                            }
                            
                            VStack(spacing: 12) {
                                Text("You're all caught up!")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text("No pending invitations right now.")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.5)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 40)
                    } else {
                        // Group invitations by status
                        let pendingInvitations = viewModel.invitations.filter { $0.status.lowercased() == "pending" }
                        let acceptedInvitations = viewModel.invitations.filter { $0.status.lowercased() == "accepted" }
                        let rejectedInvitations = viewModel.invitations.filter { $0.status.lowercased() == "rejected" }
                        
                        if !pendingInvitations.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("PENDING INVITATIONS")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .tracking(0.5)
                                    
                                    Spacer()
                                    
                                    Text("\(pendingInvitations.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)
                                
                                ForEach(pendingInvitations) { invitation in
                                    invitationCard(for: invitation)
                                }
                            }
                        }
                        
                        if !acceptedInvitations.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("ACCEPTED INVITATIONS")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .tracking(0.5)
                                    
                                    Spacer()
                                    
                                    Text("\(acceptedInvitations.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)
                                
                                ForEach(acceptedInvitations) { invitation in
                                    invitationCard(for: invitation)
                                }
                            }
                        }
                        
                        if !rejectedInvitations.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("REJECTED INVITATIONS")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .tracking(0.5)
                                    
                                    Spacer()
                                    
                                    Text("\(rejectedInvitations.count)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .frame(width: 24, height: 24)
                                        .background(
                                            Circle()
                                                .fill(.ultraThinMaterial)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .padding(.horizontal, 20)
                                
                                ForEach(rejectedInvitations) { invitation in
                                    invitationCard(for: invitation)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.red)
                }
            }
            .onAppear {
                Task { await viewModel.fetchInvitationsAndBoards() }
            }
        }
    }
    
    @ViewBuilder
    private func invitationCard(for invitation: Invitation) -> some View {
        let vb: VisionBoard? = {
            if invitation.objectType == "visionboard" {
                return viewModel.visionBoards[invitation.objectId]
            } else if invitation.objectType == "genre" {
                if let genre = viewModel.genres[invitation.objectId] {
                    return viewModel.visionBoards[genre.visionboardId]
                }
            }
            return nil
        }()
        let genreName: String? = {
            if invitation.objectType == "genre" {
                return viewModel.genres[invitation.objectId]?.name
            }
            return nil
        }()
        let sender = viewModel.senders[invitation.senderId]
        
        VStack(alignment: .leading, spacing: 0) {
            // Header with project title and status
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let vb = vb {
                        Text(vb.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        if let desc = vb.description, !desc.isEmpty {
                            Text(desc)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    } else {
                        Text("Unknown Project")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                // Date range
                if let vb = vb {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text(vb.startDate, style: .date)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("End")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            Text(vb.endDate, style: .date)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Divider
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
            // Details section
            VStack(alignment: .leading, spacing: 12) {
                // Genre and work type
                if let genreName = genreName {
                    detailRow(title: "Genre", value: genreName, icon: "music.note")
                }
                
                if let workType = invitation.data?["work_type"]?.value as? String {
                    detailRow(title: "Work Type", value: workType, icon: "briefcase")
                }
                
                if let payment = invitation.data?["payment_amount"]?.value as? String {
                    detailRow(title: "Payment", value: "$\(payment)", icon: "dollarsign.circle")
                }
                
                // Sender information
                if let sender = sender {
                    detailRow(title: "From", value: sender.name, icon: "person")
                    
                    if let genres = sender.genres, !genres.isEmpty {
                        let genreList = genres.map { $0.rawValue.capitalized }.joined(separator: ", ")
                        detailRow(title: "Sender Genre", value: genreList, icon: "music.note.list")
                    }
                    
                    if let rating = sender.rating {
                        detailRow(title: "Rating", value: String(format: "%.1f ⭐", rating), icon: "star")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Action buttons for pending invitations
            if invitation.status.lowercased() == "pending" {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await viewModel.respondToInvitation(invitation: invitation, response: "rejected")
                                NotificationCenter.default.post(name: .didRespondToInvitation, object: nil)
                            }
                        }) {
                            Text("Reject")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                        
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.red.opacity(0.6),
                                                        Color.red.opacity(0.3)
                                                    ]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            Task {
                                await viewModel.respondToInvitation(invitation: invitation, response: "accepted")
                                NotificationCenter.default.post(name: .didRespondToInvitation, object: nil)
                            }
                        }) {
                            Text("Accept")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.ultraThinMaterial)
                                        
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [
                                                        Color.primary.opacity(0.1),
                                                        Color.clear
                                                    ]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            } else {
                // Non-pending invitations don't need action buttons
                Spacer()
                    .frame(height: 20)
            }
        }
        .background(
            ZStack {
                // Glass morphism background
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func detailRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
                .opacity(0.8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .opacity(0.8)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(0.3)
        )
    }
    
    private func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "pending":
            return .blue
        case "accepted":
            return .green
        case "rejected":
            return .red
        default:
            return .gray
        }
    }
}