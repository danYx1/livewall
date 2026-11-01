import SwiftUI

struct ContentView: View {

    @StateObject private var model = StudioModel()
    @State private var selection = 0

    var body: some View {
        ZStack {
            AppBackground()

            TabView(selection: $selection) {
                CreateView()
                    .tag(0)
                    .tabItem {
                        Label("Создать", systemImage: "wand.and.stars")
                    }

                GuideView()
                    .tag(1)
                    .tabItem {
                        Label("Как установить", systemImage: "questionmark.circle")
                    }
            }
            .tint(Theme.accent)
        }
        .environmentObject(model)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $model.showGuide) {
            GuideView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
        }
    }
}

#Preview {
    ContentView()
}
