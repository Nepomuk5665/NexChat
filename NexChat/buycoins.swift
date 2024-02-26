//
//  buycoins.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 06.01.2024.
//

import SwiftUI
import Shimmer
import StoreKit
import RiveRuntime
import PopupView

struct BuyCoinsView: View {
    var userIdentifier: String
    @State var isPriceRevealed = false
    @State private var products: [SKProduct] = []
    @State private var transactionState: SKPaymentTransactionState?
    @ObservedObject var storeManager: StoreManager
    
    init(userIdentifier: String) {
            self.userIdentifier = userIdentifier
            self.storeManager = StoreManager(currentUserIdentifier: userIdentifier)
        }
    
    @State var PurchaseProzessing = false
    @State var refreshToggle = false
    
    
    var body: some View {
        
        GeometryReader { geometry in
            ZStack {
                BackgroundVideoViewCoin().ignoresSafeArea(.all)
                
                VStack {
                    HStack {
                        Image("rizz_coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.1) // 10% of screen width
                            .padding(.top)
                        
                        Text("Ultimate Rizz")
                            .font(.system(size: geometry.size.width * 0.08)) // 8% of screen width
                            .foregroundStyle(.yellow)
                            .shimmering()
                            .padding(.top)
                            .bold()
                        
                        Image("rizz_coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.1) // 10% of screen width
                            .padding(.top)
                    }
                    .padding([.leading, .trailing], geometry.size.width * 0.05) // Padding based on screen width
                    
                    Spacer()
                }
                
                VStack {
                    Button(action: {
                        
                        purchaseProduct()
                        PurchaseProzessing = true
                    }, label: {
                        
                    
                    ZStack{
                        Rectangle()
                            .fill(PurchaseProzessing ? .gray : .yellow)
                            .opacity(0.8)
                            .cornerRadius(10)
                            .frame(width: 200, height: 50)// adjust it on the text size that it fits
                            
                        
                        HStack{
                            
                            
                            if PurchaseProzessing{
                                Text("Processing...")
                                    .shimmering()
                                    .bold()
                                    .foregroundStyle(.white)
                            } else {
                                if isPriceRevealed {
                                    
                                    Text("100")
                                        .bold()
                                        .foregroundStyle(.white)
                                        .transition(
                                            .identity
                                                .animation(.linear(duration: 1).delay(2))
                                                .combined(
                                                    with: .movingParts.anvil
                                                )
                                        )
                                    
                                }
                                
                                
                                else {
                                    Text("25")
                                        .foregroundStyle(.white)
                                        .transition(
                                            .asymmetric(
                                                insertion: .identity,
                                                removal: .opacity.animation(.easeOut(duration: 0.2)))
                                        )
                                }
                                Image("rizz_coin")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 30)
                                
                                if storeManager.products.isEmpty {
                                    Text("Loading...")
                                        .foregroundStyle(.white)
                                } else if let product = storeManager.products.first(where: { $0.productIdentifier == "100_coins" }) {
                                    Text("For only \(storeManager.formattedPrice(for: product))")
                                        .foregroundStyle(.white)
                                        
                                    
                                } else {
                                    Text("Product not available")
                                }
                            }
                            
                        }
                        
                        
                        Spacer()
                    }
                    })
                    .disabled(PurchaseProzessing)
                    
                }
            }
            
            .onAppear {
                
                
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        isPriceRevealed = true
                    }
                }
                
                
                storeManager.onTransactionStateChange = { state in
                    DispatchQueue.main.async {
                        switch state {
                        case .purchasing:
                            self.PurchaseProzessing = true
                        case .purchased, .failed, .restored, .deferred:
                            self.PurchaseProzessing = false
                        default:
                            break
                        }
                    }
                }
                
                
                
                
                storeManager.fetchProducts()
            }
        }.preferredColorScheme(.dark)
    }
    
    
    
    
    
    private func purchaseProduct() {
            if let product = storeManager.products.first(where: { $0.productIdentifier == "100_coins" }) {
                storeManager.purchaseProduct(product)
            }
        }
    private func fetchProducts() {
        withAnimation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                isPriceRevealed = true
            }
        }
        storeManager.fetchProducts()
    }
    
    
    
}






#Preview {
    BuyCoinsView(userIdentifier: "test")
}
