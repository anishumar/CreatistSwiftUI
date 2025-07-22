import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) var colorScheme
    let coralRed = Color(red: 230/255, green: 67/255, blue: 79/255)
    
    var backgroundColor: Color {
        if colorScheme == .dark {
            return Color.black // Pitch black for dark mode
        } else {
            return Color(red: 245/255, green: 245/255, blue: 247/255) // #F5F5F7
        }
    }
    
    @State private var scale: CGFloat = 2.2
    @State private var fadeOut = false
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            Text("Creatist")
                .font(.custom("Helvetica Neue Bold", size: 44))
                .foregroundColor(coralRed)
                .scaleEffect(scale)
                .opacity(fadeOut ? 0 : 1)
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: scale)
                .animation(.easeInOut(duration: 0.4), value: fadeOut)
        }
        .onAppear {
            // Zoom in
            withAnimation {
                scale = 1.0
            }
            // After a pause, zoom out and fade
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation {
                    scale = 0.7
                    fadeOut = true
                }
            }
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SplashScreenView()
                .preferredColorScheme(.light)
            SplashScreenView()
                .preferredColorScheme(.dark)
        }
    }
} 