//
//  SelectShoeView.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 04.01.2024.
//

import SwiftUI
import Firebase
import Introspect
import Pow
import SystemConfiguration

struct Shoe: Identifiable {
    let id: String  // Document ID
    let baseURL: String
    var isSelected: Bool = false
    var cost: Int = 0
}



struct SelectShoeView: View {
    @AppStorage("userID") var userID: String = ""
    @State private var refreshKey = UUID()
    @State private var shoes = [Shoe]()
    @State private var selectedShoe: String = "none"
    @State private var selectedShoeBaseURL = "https://images.stockx.com/360/Air-Jordan-11-Retro-DMP-Defining-Moments-2023-GS/Images/Air-Jordan-11-Retro-DMP-Defining-Moments-2023-GS/Lv2/img"  // Replace with your default URL
    @State private var imageOffset = CGSize.zero
    @State private var animateOut = false
    @State private var isImageChanging = false
    var userIdentifier: String
    var onShoeSelected: () -> Void
    @State private var userCoins: Int = 0
    @State var canContinue = true
    @State var isFormValid = true
    private var selectedShoeBinding: Binding<String> {
        Binding<String>(
            get: { self.selectedShoe },
            set: { newSelectedShoe in
                self.selectedShoe = newSelectedShoe
                if let selectedShoeIndex = shoes.firstIndex(where: { $0.id == newSelectedShoe }) {
                    self.selectedShoeBaseURL = shoes[selectedShoeIndex].baseURL
                }
            }
        )
    }
    
    
    
    @State private var boughtShoesList: [String] = []
    
    @State private var showPresentShoeView = false
    
    
    @State private var listenerRegistration: ListenerRegistration?
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    
    
    @State private var navigateToBuyCoins = false
    
    @State private var isKeyboardVisible = false
    @State private var searchQuery = ""
    
    var body: some View {
        
        VStack {
            
            ZStack{
                
                
                
                VStack{
                    ThreeDImageView(baseURL: selectedShoeBaseURL)
                        .id(refreshKey)
                        .frame(height: isKeyboardVisible ? 0 : 300)
                        .offset(x: imageOffset.width, y: 0)
                        .animation(.easeInOut(duration: 0.5), value: selectedShoeBaseURL)
                        .transition(.slide)
                        .onAppear {
                            self.imageOffset = CGSize(width: UIScreen.main.bounds.width, height: 0)
                        }
                        .onAppear{
                            userID = userIdentifier
                        }
                    Spacer()
                }
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Shoe name section
                        if !isKeyboardVisible {
                            if selectedShoe != "none" {
                                let shoeNameParts = splitShoeName(shoeName: selectedShoe)
                                Text(shoeNameParts.0) // First part of the shoe name
                                    .font(.system(size: 20))
                                    .bold()
                                if !shoeNameParts.1.isEmpty {
                                    Text(shoeNameParts.1) // Second part of the shoe name
                                        .font(.system(size: 20))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                Text("Choose your profile shoe")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                    .bold()
                            }
                        } else {
                            Text(searchQuery)
                                .font(.system(size: 20))
                                .bold()
                        }
                        Spacer()
                    }
                    .padding([.leading, .top])
                    Spacer() // Pushes content to the left and coin display to the right
                    // Coin display section
                    VStack {
                        HStack {
                            Text("\(userCoins)")
                                .foregroundColor(.yellow)
                            Image("rizz_coin")
                                .resizable()
                                .frame(width: 30, height: 30)
                        }
                        .padding(.top)
                        .padding(.trailing)
                        Spacer()
                    }
                }
                
            }
            .onTapGesture {
                withAnimation{
                    self.hideKeyboard()
                }
            }
            .navigationBarBackButtonHidden(true)
            
            TextField("Search Shoes", text: $searchQuery)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            
            
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    ForEach(filteredShoes) { shoe in
                        ZStack{
                            shoeButton(for: shoe)
                                .animation(.easeInOut, value: shoe.isSelected)
                                .onTapGesture {
                                    withAnimation{
                                        self.hideKeyboard()
                                    }
                                }
                            
                        }
                    }
                }
                .padding(.top, isKeyboardVisible ? 20 : 0) // Adjust padding based on keyboard
            }
            .onTapGesture {
                withAnimation{
                    self.hideKeyboard()
                }
            }
            
            if !isKeyboardVisible {
                confirmSelectionButton()
            }
            
            
            
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        
        .sheet(isPresented: $showPresentShoeView) {
            PresentShoeView(baseURL: self.selectedShoeBaseURL)
        }
        .preferredColorScheme(.light)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $navigateToBuyCoins) {
            BuyCoinsView(userIdentifier: userIdentifier)
        }
        .onAppear(perform: {
            loadShoes()
            fetchUserData()
        })
        .onChange(of: selectedShoeBaseURL) { _ in
            animateImageChange()
        }
        .navigationBarBackButtonHidden(true)
        .introspectTextField { textField in
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main) { _ in
                self.isKeyboardVisible = true
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main) { _ in
                self.isKeyboardVisible = false
            }
        }
        .onDisappear {
            listenerRegistration?.remove()
        }
        
        
        
        
    }
    
    
    
    
    private func fetchUserData() {
        let db = Firestore.firestore()
        let userDocument = db.collection("users").document(userIdentifier)
        
        userDocument.addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot, document.exists else {
                print("Error fetching user data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let data = document.data()
            self.userCoins = data?["coins"] as? Int ?? 0
            self.boughtShoesList = data?["boughtShoesArray"] as? [String] ?? []
        }
    }
    
    
    
    
    
    
    
    
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    
    
    
    
    
    private func confirmSelectionButton() -> some View {
        let selectedShoeObject = shoes.first(where: { $0.id == selectedShoe })
        
        return Group {
            if let shoe = selectedShoeObject {
                // Check if the shoe is already bought or if the cost is zero
                if shoe.cost == 0 || isShoeBought(shoe) {
                    // Shoe is free or already bought, just select it
                    Button("Select Shoe") {
                        saveShoeSelection()
                    }
                    .padding()
                    .background(Capsule().strokeBorder(Color.blue, lineWidth: 1))
                    .disabled(selectedShoe == "none")
                    .opacity(selectedShoe == "none" ? 0.5 : 1)
                } else if userCoins >= shoe.cost {
                    // User has enough coins to buy
                    Button(action: {
                        purchaseShoe(shoe)
                    }) {
                        Text("Buy for \(shoe.cost) Coins")
                            .padding()
                            .background(Capsule().strokeBorder(Color.yellow, lineWidth: 1))
                        
                    }
                } else {
                    // Not enough coins to buy
                    Button(action: {
                        navigateToBuyCoins = true
                    }) {
                        ZStack{
                            Rectangle()
                                .frame(width: 200, height: 50)
                                .cornerRadius(12)
                                .foregroundColor(.yellow)
                            
                            Text("Buy Rizz")
                                .bold()
                                .padding()
                                .foregroundColor(.black)
                                .conditionalEffect(.smoke, condition: isFormValid)
                            
                        } .conditionalEffect(.repeat(.wiggle(rate: .fast), every: .seconds(1)), condition: isFormValid)
                        
                    }.transition(.movingParts.poof)
                    
                }
            }
        }
    }
    
    
    private func isShoeBought(_ shoe: Shoe) -> Bool {
        return boughtShoesList.contains(shoe.id)
    }
    
    
    
    
    
    
    
    private func checkInternetConnection() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return (isReachable && !needsConnection)
    }
    
    
    
    
    
    
    
    private func purchaseShoe(_ shoe: Shoe) {
        if !checkInternetConnection() {
            self.alertMessage = "No Internet Connection. Please check your network and try again."
            self.showAlert = true
            return
        }
        // Deduct coins and unlock the shoe
        let newCoinTotal = userCoins - shoe.cost
        let db = Firestore.firestore()
        let userDocument = db.collection("users").document(userIdentifier)
        
        // Append the new shoe ID to the local list
        boughtShoesList.append(shoe.id)
        
        // Update coins and bought shoes in Firestore
        userDocument.updateData([
            "coins": newCoinTotal,
            "boughtShoesArray": boughtShoesList
        ]) { error in
            if let error = error {
                print("Error updating user data: \(error)")
            } else {
                // Update local userCoins state
                withAnimation{
                    self.userCoins = newCoinTotal
                }
                self.showPresentShoeView = true
            }
        }
    }
    
    
    
    
    
    private func buyCoins() {
        navigateToBuyCoins = true
    }
    
    
    
    private func splitShoeName(shoeName: String) -> (String, String) {
        let parts = shoeName.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).map(String.init)
        let firstPart = parts.count > 0 ? parts[0].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let secondPart = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        return (firstPart, secondPart)
    }
    
    private var filteredShoes: [Shoe] {
        let sortedShoes = shoes.sorted {
            switch (isShoeBought($0), isShoeBought($1)) {
            case (true, false): return true    // First item is owned, it should come first
            case (false, true): return false   // Second item is owned, it should come first
            default: break                     // If both or neither are owned, check further
            }
            
            switch ($0.cost, $1.cost) {
            case (0, 0): return $0.id < $1.id // Both are free, sort by ID
            case (0, _): return true          // First item is free, it should come after owned but before others
            case (_, 0): return false         // Second item is free, same as above
            default: return $0.cost < $1.cost // Sort by cost
            }
        }
        
        guard !searchQuery.isEmpty else { return sortedShoes }
        return sortedShoes.filter { $0.id.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    
    private func animateImageChange() {
        // Animate the image out to the left
        withAnimation {
            self.imageOffset = CGSize(width: -UIScreen.main.bounds.width, height: 0)
        }
        
        // Delay the incoming animation to sync with the outgoing animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Reset the image position for the new image
            self.imageOffset = CGSize(width: UIScreen.main.bounds.width, height: 0)
            withAnimation {
                self.imageOffset = CGSize.zero
            }
        }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    private func shoeButton(for shoe: Shoe) -> some View {
        ZStack {
            ShoePreview(baseURL: shoe.baseURL)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(shoe.id == selectedShoe ? Color.yellow : Color.clear, lineWidth: 1)
                )
            
            VStack {
                
                HStack {
                    Spacer()
                    if shoe.cost == 0 {
                        // Shoe is free
                        shoeTag(text: "Free", backgroundColor: .gray)
                    } else if isShoeBought(shoe) {
                        // Shoe is owned
                        shoeTag(text: "Own", backgroundColor: .yellow, textColor: .red)
                    } else {
                        // Shoe has a cost
                        shoeTag(text: "\(shoe.cost)", backgroundColor: .yellow)
                    }
                }.padding(.trailing, 8)
                Spacer()
            }
        }
        .onTapGesture {
            withAnimation {
                self.hideKeyboard()
                selectShoe(shoe: shoe)
            }
        }
    }
    
    private func shoeTag(text: String, backgroundColor: Color, textColor: Color = .black) -> some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)
                .frame(width: 40, height: 20)
                .cornerRadius(5)
                .opacity(backgroundColor == .yellow ? 0.7 : 1.0)
            Text(text)
                .bold()
                .foregroundColor(textColor)
        }
    }
    
    
    private func selectShoe(shoe: Shoe) {
        selectedShoe = shoe.id
        selectedShoeBaseURL = shoe.baseURL
        refreshKey = UUID()  // Update key to force view redraw
    }
    
    
    
    private func loadShoes() {
        let db = Firestore.firestore()
        db.collection("shoes").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting shoes: \(error)")
            } else if let documents = snapshot?.documents, !documents.isEmpty {
                self.shoes = documents.compactMap { document in
                    let data = document.data()
                    if let baseURL = data["baseURL"] as? String, let cost = data["cost"] as? Int {
                        return Shoe(id: document.documentID, baseURL: baseURL, cost: cost)
                    } else {
                        return nil
                    }
                }
                self.selectedShoe = "none"
                self.selectedShoeBaseURL = ""
            }
        }
    }
    
    
    
    
    
    private func selectShoe(at index: Int) {
        for i in shoes.indices {
            shoes[i].isSelected = (i == index)
        }
        selectedShoe = shoes[index].id
        selectedShoeBaseURL = shoes[index].baseURL
        refreshKey = UUID()
    }
    
    private func saveShoeSelection() {
        let db = Firestore.firestore()
        db.collection("users").document(userIdentifier).setData(["shoe": selectedShoe], merge: true) { error in
            if let error = error {
                print("Error saving shoe selection: \(error)")
            } else {
                print("Shoe selection successfully saved")
                onShoeSelected()
            }
        }
    }
}



#Preview {
    SelectShoeView(userIdentifier: "tester", onShoeSelected: {})
}
