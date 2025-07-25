import SwiftUI

struct PrivacyPolicySheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.title2).bold()
                        .padding(.bottom, 8)
                    Text("Effective Date: [Insert Date]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Group {
                        Text("1. Introduction").font(.headline)
                        Text("Welcome to Creatist (\"we\", \"us\", or \"our\"). We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and related services (collectively, the \"Service\").\n\nThis policy is in accordance with the Information Technology Act, 2000, the Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011, and the Digital Personal Data Protection Act, 2023, as applicable in India.")
                        Text("2. Information We Collect").font(.headline)
                        Text("We may collect the following types of information:")
                        Text("a. Personal Information").font(.subheadline).bold()
                        Text("• Name\n• Email address\n• Phone number\n• Profile information (including profile photo, bio, city, country, genres, etc.)\n• Location data (for features like discovering nearby creators or updating your profile location)\n• Any other information you voluntarily provide (e.g., posts, messages, media uploads)")
                        Text("b. Non-Personal Information").font(.subheadline).bold()
                        Text("• Device information (model, OS version, unique device identifiers)\n• Usage data (app interactions, crash logs, diagnostics)\n• Cookies and similar technologies (where applicable)")
                        Text("3. Use of Information").font(.headline)
                        Text("We use your information to:\n• Provide, operate, and improve our services\n• Personalize your experience\n• Enable social features (e.g., following, messaging, sharing content)\n• Communicate with you (updates, notifications, support)\n• Ensure security and prevent fraud\n• Comply with legal obligations")
                        Text("4. Sharing of Information").font(.headline)
                        Text("We do not sell your personal information. We may share your information with:\n• Service providers who assist in app operations (subject to confidentiality agreements)\n• Law enforcement or regulatory authorities, if required by law\n• Other users, if you choose to share your activity or profile publicly")
                        Text("5. Data Security").font(.headline)
                        Text("We implement reasonable security practices and procedures, including encryption and access controls, to protect your information from unauthorized access, alteration, disclosure, or destruction.")
                        Text("6. Data Retention").font(.headline)
                        Text("We retain your personal information for as long as necessary to fulfill the purposes outlined in this policy, unless a longer retention period is required or permitted by law.")
                        Text("7. Your Rights").font(.headline)
                        Text("You have the right to:\n• Access, correct, or update your personal information\n• Withdraw consent (where applicable)\n• Request deletion of your data (subject to legal requirements)\n• Contact us regarding any privacy concerns\n\nTo exercise these rights, please contact us at the details provided below.")
                        Text("8. Children’s Privacy").font(.headline)
                        Text("Our services are not intended for children under the age of 18. We do not knowingly collect personal information from children.")
                        Text("9. Changes to This Policy").font(.headline)
                        Text("We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy on this page.")
                        Text("10. Contact Us").font(.headline)
                        Text("If you have any questions or concerns about this Privacy Policy or our data practices, please contact us at:\nEmail: [Insert Contact Email]\nAddress: [Insert Company Address]")
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

struct TermsOfServiceSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms of Service")
                        .font(.title2).bold()
                        .padding(.bottom, 8)
                    Text("Effective Date: [Insert Date]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Group {
                        Text("Welcome to Creatist! Please read these Terms of Service (\"Terms\") carefully before using our mobile application and related services (collectively, the \"Service\"). By accessing or using Creatist, you agree to be bound by these Terms and our Privacy Policy.")
                        Text("1. Acceptance of Terms").font(.headline)
                        Text("By registering for, accessing, or using Creatist, you confirm that you are at least 18 years old (or have parental consent if you are between 13 and 18), and that you have read, understood, and agree to these Terms. If you do not agree, please do not use the Service.")
                        Text("2. Changes to Terms").font(.headline)
                        Text("We may update these Terms from time to time to reflect changes in law or our services. We will notify you of significant changes via the app or email. Continued use after changes means you accept the new Terms.")
                        Text("3. Eligibility").font(.headline)
                        Text("You must be legally competent to enter into a contract under Indian law. If you are under 18, you must have parental or guardian consent.")
                        Text("4. User Accounts").font(.headline)
                        Text("• You must provide accurate, complete information when creating an account.\n• You are responsible for maintaining the confidentiality of your account credentials.\n• You agree not to impersonate others or use false information.")
                        Text("5. Use of the Service").font(.headline)
                        Text("• You may use Creatist for personal, non-commercial purposes only.\n• You agree not to misuse the Service, including but not limited to:\n  - Uploading harmful, offensive, or illegal content.\n  - Harassing, threatening, or abusing other users.\n  - Attempting to hack, disrupt, or reverse-engineer the Service.\n• You are responsible for your interactions with other users.")
                        Text("6. Content").font(.headline)
                        Text("• You retain ownership of content you upload, but grant us a non-exclusive, royalty-free license to use, display, and share it as needed to provide the Service.\n• You must not upload content that infringes on others’ rights or violates any law.")
                        Text("7. Privacy").font(.headline)
                        Text("We respect your privacy. Please review our Privacy Policy to understand how we collect, use, and protect your data, in accordance with the Information Technology Act, 2000, and the Digital Personal Data Protection Act, 2023.")
                        Text("8. Data Protection and Security").font(.headline)
                        Text("• We implement reasonable security practices as per Indian law.\n• You have the right to access, correct, or delete your personal data.\n• We do not sell your personal data to third parties.")
                        Text("9. Payments and Subscriptions").font(.headline)
                        Text("If you purchase premium features, you agree to pay the applicable fees. All payments are non-refundable except as required by law.")
                        Text("10. Third-Party Services").font(.headline)
                        Text("Creatist may link to third-party services. We are not responsible for their content or practices.")
                        Text("11. Termination").font(.headline)
                        Text("We may suspend or terminate your account if you violate these Terms or applicable law. You may also delete your account at any time.")
                        Text("12. Limitation of Liability").font(.headline)
                        Text("To the extent permitted by law, Creatist and its affiliates are not liable for any indirect, incidental, or consequential damages arising from your use of the Service.")
                        Text("13. Indemnity").font(.headline)
                        Text("You agree to indemnify and hold harmless Creatist, its affiliates, and employees from any claims, damages, or expenses arising from your use of the Service or violation of these Terms.")
                        Text("14. Governing Law and Dispute Resolution").font(.headline)
                        Text("• These Terms are governed by the laws of India.\n• Any disputes will be subject to the exclusive jurisdiction of the courts in [Your City], India.\n• As per the Mediation Act, 2023, parties are encouraged to resolve disputes through mediation before approaching courts.")
                        Text("15. Compliance with New Indian Laws").font(.headline)
                        Text("• We comply with the Digital Personal Data Protection Act, 2023, and IT Rules, 2021.\n• We will promptly address any government or user requests as required by law.\n• Users have the right to data portability, correction, and erasure under the new law.")
                        Text("16. Grievance Redressal").font(.headline)
                        Text("If you have any complaints or concerns, please contact our Grievance Officer:\nName: [Insert Name]\nEmail: [Insert Email]\nAddress: [Insert Address]\nWe will acknowledge your complaint within 24 hours and resolve it within 15 days, as per Indian law.")
                        Text("17. Contact Us").font(.headline)
                        Text("For any questions about these Terms, contact us at [Insert Contact Email].")
                        Text("Conclusion:").font(.headline)
                        Text("By using Creatist, you agree to these Terms. We are committed to fairness, transparency, and compliance with the latest Indian laws, including the Digital Personal Data Protection Act, 2023, and the Mediation Act, 2023. Your rights and safety are our priority.")
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

struct AboutSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("About")
                        .font(.title2).bold()
                        .padding(.bottom, 8)
                    Text("Creatist is a platform for creators to collaborate, share, and grow. Our mission is to empower artists, musicians, and visionaries to bring their ideas to life together.")
                        .font(.body)
                    Text("Version 1.0.0").font(.caption)
                    Text("Developed by the Creatist Team.").font(.caption)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

struct HelpSupportSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Help & Support")
                        .font(.title2).bold()
                        .padding(.bottom, 8)
                    Text("Need help? Check out our FAQ below or contact support.")
                        .font(.body)
                    Text("Frequently Asked Questions").font(.headline)
                    Text("Q: How do I reset my password?\nA: Go to Profile > Edit Profile > Change Password.")
                    Text("Q: How do I report a bug?\nA: Use the Contact Us form or email support@creatist.com.")
                }
                .padding()
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

struct ContactUsSheet: View {
    @Binding var isPresented: Bool
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contact Us")
                        .font(.title2).bold()
                        .padding(.bottom, 8)
                    Text("For support, feedback, or business inquiries, reach out to us:")
                        .font(.body)
                    Text("Email: support@creatist.com")
                    Text("Phone: +1 (555) 123-4567")
                    Text("We aim to respond within 2 business days.").font(.caption)
                }
                .padding()
            }
            .navigationTitle("Contact Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
} 