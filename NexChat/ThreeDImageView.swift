//
//  ThreeDImageView.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 04.01.2024.
//

import SwiftUI
import WebKit

struct ThreeDImageView: View {
    var baseURL: String
        @State private var images: [UIImage?] = Array(repeating: nil, count: 36)
        @State private var currentIndex: Int = 0
        @State private var swipeOffset: CGFloat = 0
        @State private var isLoading = true
        
        private var imageURLs: [URL] {
            (1...36).map { i in
                URL(string: "\(baseURL)\((i < 10 ? "0" : ""))\(i).jpg?fm=avif&auto=compress&w=576&dpr=1&updated_at=1691770728&h=384&q=60")!
            }
        }

    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                WebView(url: Bundle.main.url(forResource: "loading", withExtension: "gif")!)
            } else {
                if let image = images[currentIndex] {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    
                        .gesture(
                            DragGesture(minimumDistance: 0.1, coordinateSpace: .local)
                                .onChanged { value in
                                    swipeOffset += value.translation.width - value.predictedEndTranslation.width
                                    let swipeThreshold: CGFloat = 50 // Adjust for swipe sensitivity
                                    
                                    if abs(swipeOffset) >= swipeThreshold {
                                        if swipeOffset > 0 {
                                            currentIndex = (currentIndex + 1) % images.count
                                        } else {
                                            currentIndex = (currentIndex - 1 + images.count) % images.count
                                        }
                                        swipeOffset = 0
                                    }
                                }
                                .onEnded { _ in
                                    swipeOffset = 0
                                }
                        )
                }
            }
        }
        .onAppear(perform: loadAllImages)
        .onChange(of: baseURL) { _ in
            images = Array(repeating: nil, count: 36)
            loadAllImages()
        }
        
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
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}


#Preview {
    ThreeDImageView(baseURL: "https://images.stockx.com/360/Air-Jordan-4-Retro-Red-Cement/Images/Air-Jordan-4-Retro-Red-Cement/Lv2/img")
}
