//
//  PreviewUser.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 14.01.2024.
//



import SwiftUI
import Firebase



struct UserSearchResult {
    
    var username: String
    var userID: String
}




struct PreviewUser: View {
    var userID: String
    
    @State private var userCoins: Int = 0
    
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var shoeBaseURL: String = ""
    
    @State private var selectedShoeBaseURL = ""
    @State private var refreshKey = UUID()
    @State private var imageOffset = CGSize.zero
    
    @State private var isImageChanging = false
    
    
    @State private var boughtShoes: [Shoe] = []
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            
            
            VStack{
                ThreeDImageView(baseURL: selectedShoeBaseURL)
                    .id(refreshKey)
                    .frame(height: 300)
                    .offset(x: imageOffset.width, y: 0)
                    .animation(.easeInOut(duration: 0.5), value: isImageChanging)
                    .transition(.slide)
                    .onAppear {
                        loadData()
                    }
                    .onTapGesture {
                        debugPrint(selectedShoeBaseURL)
                    }
                    .padding(.top)
                Rectangle()
                    .frame(height: 450)
                    .opacity(0)
            }
                
            VStack{
                Rectangle()
                    .opacity(0)
                ZStack {
                    Rectangle()
                        .fill(.gray)
                        .frame(height: 500)
                        .cornerRadius(20)
                        .ignoresSafeArea(.all)
                    VStack {
                        Rectangle()
                            .opacity(0)
                            .frame(height: 12)
                        HStack {
                            ShoePreview(baseURL: selectedShoeBaseURL)
                                .id(refreshKey)
                                .frame(width: 90, height: 60)
                                .cornerRadius(20)
                                .padding()
                            VStack {
                                Text(fullName)
                                    .font(.title)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text(username)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        ZStack{
                            Rectangle()
                                .fill(.brown)
                                .frame(width: 100, height: 40)
                                .cornerRadius(8)
                                .padding(.leading)
                            
                            HStack {
                                Text("\(userCoins)")
                                    .foregroundColor(.yellow)
                                Image("rizz_coin")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                            }.padding(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        ZStack {
                            Rectangle()
                                .fill(.brown)
                                .cornerRadius(20)
                                .ignoresSafeArea(.all)
                                .padding(.leading)
                                .padding(.trailing)
                                
                            
                            // LazyVGrid to show bought shoes
                            VStack{
                                HStack{
                                    Rectangle()
                                        .frame(width: 10, height: 1)
                                        .opacity(0)
                                    Text("Shoe locker:")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading)
                                        .padding(.top)
                                }
                                if boughtShoes.isEmpty {
                                    Text("No shoes bought yet")
                                        .foregroundColor(.white)
                                } else {
                                    ScrollView{
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                                            ForEach(boughtShoes) { shoe in
                                                ShoePreview(baseURL: shoe.baseURL)
                                                    .frame(width: 90, height: 60)
                                                    .cornerRadius(10)
                                                
                                            }
                                        }
                                        .padding()
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
            }.ignoresSafeArea()
                
            
            .onAppear{
                animateImageChange()
                
            }
            .preferredColorScheme(.light)
            
            
            
            VStack{
                Rectangle()
                    .frame(width: 0, height: 60)
                    .opacity(0)
                
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }, label: {
                    HStack{
                        
                        Image(systemName: "arrowshape.left.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 50))
                            .padding(.leading)
                            
                        Spacer()
                    }
                })
                Spacer()
            }
            
            
            
            
            
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func loadData() {
        let db = Firestore.firestore()
        
        // Fetch the user's data
        db.collection("users").document(userID).getDocument { userDocument, userError in
            if let userError = userError {
                print("Error fetching user: \(userError.localizedDescription)")
                self.selectedShoeBaseURL = "" // Set a default or error URL if needed
                return
            }
            
            guard let userDocument = userDocument, userDocument.exists, let userData = userDocument.data() else {
                print("User document does not exist")
                self.selectedShoeBaseURL = "" // Set a default or error URL if needed
                return
            }
            
            
            
            if let boughtShoeNames = userData["boughtShoesArray"] as? [String] {
                self.boughtShoes = []
                for shoeName in boughtShoeNames {
                    db.collection("shoes").document(shoeName).getDocument { shoeDocument, shoeError in
                        guard let shoeDocument = shoeDocument, shoeDocument.exists, let shoeData = shoeDocument.data() else {
                            print("Shoe document does not exist")
                            return
                        }
                        
                        if let baseURL = shoeData["baseURL"] as? String {
                            DispatchQueue.main.async {
                                let newShoe = Shoe(id: shoeDocument.documentID, baseURL: baseURL)
                                self.boughtShoes.append(newShoe)
                            }
                        }
                    }
                }
            }
            
            
            self.fullName = userData["Display Name"] as? String ?? "Unknown"
            self.username = userData["username"] as? String ?? "Unknown"
            self.userCoins = userData["coins"] as? Int ?? 0
            // Assuming the shoe name is stored under a field in the user's document
            if let shoeName = userData["shoe"] as? String {
                // Fetch the shoe's data
                db.collection("shoes").document(shoeName).getDocument { shoeDocument, shoeError in
                    if let shoeError = shoeError {
                        print("Error fetching shoe: \(shoeError.localizedDescription)")
                        self.selectedShoeBaseURL = "" // Set a default or error URL if needed
                        return
                    }
                    
                    guard let shoeDocument = shoeDocument, shoeDocument.exists, let shoeData = shoeDocument.data() else {
                        print("Shoe document does not exist")
                        self.selectedShoeBaseURL = "" // Set a default or error URL if needed
                        return
                    }
                    
                    // Update the state variable with the shoe's base URL
                    if let baseURL = shoeData["baseURL"] as? String {
                        DispatchQueue.main.async {
                            self.selectedShoeBaseURL = baseURL
                            self.animateImageChange()  // Trigger the animation
                            refreshKey = UUID()
                        }
                    } else {
                        print("baseURL not found in shoe's data")
                        self.selectedShoeBaseURL = "" // Set a default or error URL if needed
                    }
                }
            } else {
                print("Shoe name not found in user's data")
                self.selectedShoeBaseURL = "" // Set a default or error URL if needed
            }
        }
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
                self.isImageChanging = false  // Reset the animation trigger
            }
        }
    }
    
    
    
    
    
    
    
    
    
    
}




#Preview {
    PreviewUser(userID: "001083.34bfd7f586ce42da997ff9b6c73103f2.2322")
}
