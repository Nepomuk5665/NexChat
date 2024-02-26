//
//  PresentShoeView.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 08.01.2024.
//

import SwiftUI
import EffectsLibrary
import ConfettiSwiftUI
import Shimmer

import UIKit

struct PresentShoeView: View {
    var config = FireworksConfig(
        intensity: .high,
        lifetime: .short,
        initialVelocity: .medium
    )
    var baseURL: String
    
    @State private var images: [UIImage?] = Array(repeating: nil, count: 36)
    @State private var currentIndex: Int = 0
    @State private var isLoading = true
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("Thank You Very Much for Buying This Shoe")
                    .shimmering()
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 50)
                    .transition(.move(edge: .bottom))
                
                GeometryReader { geometry in
                    if isLoading {
                        CustomProgressView()  // Customized progress view
                    } else {
                        if let image = images[currentIndex] {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                }
                
                Spacer()
            }
            
            FireworksView(config: config)
            VStack{
                Spacer()
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }, label: {
                    
                    
                    Text("Continue")
                    
                    
                }).buttonStyle(PushDownButtonStyle())
            }
            
        }
        .onAppear(perform: setupView)
        .onChange(of: baseURL) { _ in resetImages() }
    }
    
    private func setupView() {
        loadAllImages()
        startImageRotation()
    }
    
    private func resetImages() {
        images = Array(repeating: nil, count: 36)
        loadAllImages()
    }
    
    private func loadAllImages() {
        isLoading = true
        for index in imageURLs.indices {
            loadImageAtIndex(index)
        }
    }
    
    private func loadImageAtIndex(_ index: Int) {
        guard images[index] == nil, imageURLs.indices.contains(index) else { return }
        
        URLSession.shared.dataTask(with: imageURLs[index]) { data, response, error in
            guard let data = data, let image = UIImage(data: data) else { return }
            
            DispatchQueue.main.async {
                self.images[index] = image
                if self.isLoading && index == self.currentIndex {
                    self.isLoading = false
                }
            }
        }.resume()
    }
    
    private func startImageRotation() {
        Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { timer in
            self.currentIndex = (self.currentIndex + 1) % self.images.count
        }
    }
    
    private var imageURLs: [URL] {
        (1...36).map { i in
            URL(string: "\(baseURL)\((i < 10 ? "0" : ""))\(i).jpg?fm=avif&auto=compress&w=576&dpr=1&updated_at=1691770728&h=384&q=60")!
        }
    }
}

struct CustomProgressView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            .scaleEffect(1.5)
    }
}



struct PushDownButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title)
            .bold()
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 64)
            .background(.tint, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .conditionalEffect(
                .pushDown,
                condition: configuration.isPressed
            )
    }
}





#Preview {
    PresentShoeView(baseURL: "https://images.stockx.com/360/Nike-Air-Max-Plus-Wolf-Grey/Images/Nike-Air-Max-Plus-Wolf-Grey/Lv2/img")
}
