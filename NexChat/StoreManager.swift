//
//  StoreManager.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 14.01.2024.
//

import SwiftUI
import StoreKit
import FirebaseFirestore

class StoreManager: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
    var currentUserIdentifier: String
    private var processedTransactions: Set<String> = []
    @Published var products: [SKProduct] = []
    @Published var transactionState: SKPaymentTransactionState?
    
    var onTransactionStateChange: ((SKPaymentTransactionState) -> Void)?

    init(currentUserIdentifier: String) {
        self.currentUserIdentifier = currentUserIdentifier
        super.init()
        SKPaymentQueue.default().add(self)
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }
    private var processedTransactionIds: Set<String> {
            get {
                Set(UserDefaults.standard.stringArray(forKey: "processedTransactionIds") ?? [])
            }
            set {
                UserDefaults.standard.set(Array(newValue), forKey: "processedTransactionIds")
            }
        }
    
    func fetchProducts() {
        let request = SKProductsRequest(productIdentifiers: Set(["100_coins"]))
        request.delegate = self
        request.start()
    }
    
    func purchaseProduct(_ product: SKProduct) {
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if !response.products.isEmpty {
            products = response.products
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            onTransactionStateChange?(transaction.transactionState)
            transactionState = transaction.transactionState

            switch transaction.transactionState {
            case .purchased:
                if transaction.payment.productIdentifier == "100_coins" {
                    let transactionId = transaction.transactionIdentifier ?? UUID().uuidString
                    if !processedTransactionIds.contains(transactionId) {
                        processedTransactionIds.insert(transactionId)
                        updateUserCoins(credentialUserId: currentUserIdentifier, coinsToAdd: 100)
                    } else {
                        print("Duplicate transaction: \(transactionId), skipping coin update.")
                    }
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored, .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
            case .purchasing, .deferred:
                break
            @unknown default:
                break
            }
        }
    }






    func formattedPrice(for product: SKProduct) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = product.priceLocale
            return formatter.string(from: product.price) ?? ""
        }
    
}

extension StoreManager {
    func updateUserCoins(credentialUserId: String, coinsToAdd: Int) {
        let db = Firestore.firestore()

        // First, update the user's coin count
        let coinUpdate = [
            "coins": FieldValue.increment(Int64(coinsToAdd))
        ]
        
        db.collection("users").document(credentialUserId).updateData(coinUpdate) { error in
            if let error = error {
                print("Error updating coins: \(error)")
            } else {
                print("Coins successfully updated for \(credentialUserId) with \(coinsToAdd)")
                // After updating coins, log the transaction
                self.logTransaction(credentialUserId: credentialUserId)
            }
        }
    }

    private func logTransaction(credentialUserId: String) {
            let db = Firestore.firestore()

            // Create a new transaction log entry as a separate document
            let transactionLog: [String: Any] = [
                "transactionId": "coins_100",
                "timestamp": FieldValue.serverTimestamp()
            ]

            // Add the transaction log to a subcollection under the user document
            db.collection("users").document(credentialUserId)
              .collection("transactions").document()
              .setData(transactionLog) { error in
                if let error = error {
                    print("Error logging transaction: \(error)")
                } else {
                    print("Transaction logged for \(credentialUserId)")
                }
            }
        }
    }




