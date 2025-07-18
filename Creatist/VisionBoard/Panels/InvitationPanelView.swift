import SwiftUI
import Foundation

struct InvitationPanelView: View {
    @ObservedObject var viewModel: InvitationListViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                } else if viewModel.invitations.isEmpty {
                    Text("No pending invitations.").foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.invitations) { invitation in
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
                        VStack(alignment: .leading, spacing: 8) {
                            if let vb = vb {
                                Text(vb.name).font(.headline)
                                if let desc = vb.description, !desc.isEmpty {
                                    Text(desc).font(.subheadline)
                                }
                                HStack {
                                    Text("Start: ")
                                    Text(vb.startDate, style: .date)
                                    Spacer()
                                    Text("End: ")
                                    Text(vb.endDate, style: .date)
                                }.font(.caption)
                            } else {
                                Text("-").font(.headline)
                            }
                            if let genreName = genreName {
                                Text("Genre: \(genreName)").font(.caption)
                            }
                            if let sender = sender {
                                Text("From: \(sender.name)").font(.caption)
                                if let genres = sender.genres, !genres.isEmpty {
                                    Text("Sender Genre: \(genres.map { $0.rawValue.capitalized }.joined(separator: ", "))").font(.caption)
                                }
                                if let rating = sender.rating {
                                    Text("Sender Rating: \(String(format: "%.1f", rating))").font(.caption)
                                }
                            }
                            if let workType = invitation.data?["work_type"]?.value as? String {
                                Text("Work Type: \(workType)").font(.caption)
                            }
                            if let payment = invitation.data?["payment_amount"]?.value as? String {
                                Text("Payment: $\(payment)").font(.caption)
                            }
                            Text("Status: \(invitation.status.capitalized)").font(.caption2)
                            if invitation.status.lowercased() == "pending" {
                                HStack {
                                    Button("Accept") {
                                        Task {
                                            await viewModel.respondToInvitation(invitation: invitation, response: "accepted")
                                            NotificationCenter.default.post(name: .didRespondToInvitation, object: nil)
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    Button("Reject") {
                                        Task {
                                            await viewModel.respondToInvitation(invitation: invitation, response: "rejected")
                                            NotificationCenter.default.post(name: .didRespondToInvitation, object: nil)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                    }
                }
            }
            .navigationTitle("Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                Task { await viewModel.fetchInvitationsAndBoards() }
            }
        }
    }
} 