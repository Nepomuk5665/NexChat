//
//  ShoePreview.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 04.01.2024.
//

import SwiftUI
import Shimmer


struct ShoePreview: View {
    let baseURL: String
    @State private var image: UIImage? = nil

    // URL for the first image in the series with lower resolution
    private var imageURL: URL {
        URL(string: "\(baseURL)01.jpg?fm=avif&auto=compress&w=200&dpr=1&updated_at=1691770728&h=100&q=20")!
    }

    var body: some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 95, height: 70)
                
        } else {
            // Placeholder or loading view
            Rectangle()
                
                .fill(Color.gray)
                .frame(width: 100, height: 100)
                .onAppear(perform: loadImage)
                .cornerRadius(5)
                .shimmering()
        }
    }

    private func loadImage() {
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                }
            }
        }.resume()
    }
}


#Preview {
    ShoePreview(baseURL: "https://images.stockx.com/360/Air-Jordan-11-Retro-DMP-Defining-Moments-2023-GS/Images/Air-Jordan-11-Retro-DMP-Defining-Moments-2023-GS/Lv2/img")
}
