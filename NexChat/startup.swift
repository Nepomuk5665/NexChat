//
//  ContentView.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 02.01.2024.
//

import SwiftUI


struct Startup: View {
    
    @State private var showNextView = false
    // @AppStorage("show") private var showNextView = false
    var body: some View {
        ZStack {
            if showNextView {
                chooseview()
            } else {
                BackgroundVideoView()
                    .statusBar(hidden: true)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                
                showNextView = true
            }
        }
    }
}


struct NextView: View {
    var body: some View {
        
        Text("This is the next view!")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
    }
}

#Preview {
    Startup()
}
