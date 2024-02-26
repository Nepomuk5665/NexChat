//
//  createusernme.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 03.01.2024.
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct CreateUsernameView: View {
    var onUsernameSubmitted: () -> Void
    @State private var username: String = ""
    let userIdentifier: String
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.presentationMode) var presentationMode
    @State private var navigateToSelectShoe = false
    @State private var displayname: String = ""
    @State private var isUsernameAlert = true  // true for username, false for display name
    @State private var navigateToHome = false

    var body: some View {
        NavigationView {
            ZStack{
                Rectangle()
                    .fill(.black)
                    .ignoresSafeArea(.all)
                
                VStack {
                    Image("nexchat_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250.0, height: 250.0)
                    Text("Username")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                        .bold()
                        .padding(.top)
                        
                    TextField("Enter username", text: $username)
                        .modifier(customViewModifier(roundedCornes: 15, startColor: .blue, endColor: .purple, textColor: .white))
                        .padding(.bottom)
                        .padding(.leading)
                        .padding(.trailing)
                        .autocapitalization(.none) // Disables automatic capitalization
                        .disableAutocorrection(true) // Optional: Disables autocorrection
                        .onChange(of: username) { newValue in
                            username = newValue.lowercased() // Convert to lowercase
                        }
                    
                    Text("Display Name")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                        .bold()
                        
                        
                    TextField("Enter Display Name", text: $displayname)
                        .modifier(customViewModifier(roundedCornes: 15, startColor: .blue, endColor: .purple, textColor: .white))
                        .padding(.bottom)
                        .padding(.leading)
                        .padding(.trailing)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: username) { newValue in
                            username = newValue.lowercased() // Convert to lowercase
                        }
                    
                    Button(action: {checkUsername()}, label: {
                        ZStack{
                            Rectangle()
                                .foregroundColor(.white)
                                .frame(height: 60)
                                .cornerRadius(10)
                            Text("Submit")
                                .foregroundStyle(.black)
                                .bold()
                        }
                    }).padding()
                        .alert(isPresented: $showAlert) {
                            Alert(title: Text(isUsernameAlert ? "Username Unavailable" : "Display Name Unavailable"),
                                  message: Text(alertMessage),
                                  dismissButton: .default(Text("OK")))
                        }

                }
                .navigationBarBackButtonHidden(true)
                NavigationLink(destination: HomeView(userIdentifier: userIdentifier), isActive: $navigateToHome) {
                    EmptyView()
                }

                NavigationLink(destination: SelectShoeView(userIdentifier: userIdentifier, onShoeSelected: {
                    self.navigateToHome = true
                }), isActive: $navigateToSelectShoe) {
                    EmptyView()
                }
            }
            .onAppear(perform: fetchUserData)
        }
        .navigationBarBackButtonHidden(true)
    }
    
    
    
    
    func checkUsername() {
        NexChat.isContentInappropriate(text: username) { containsProfanity in
            if containsProfanity {
                self.alertMessage = "Username contains inappropriate content."
                self.isUsernameAlert = true
                self.showAlert = true
            } else {
                NexChat.isContentInappropriate(text: self.displayname) { containsProfanity in
                    if containsProfanity {
                        self.alertMessage = "Display Name contains inappropriate content."
                        self.isUsernameAlert = false
                        self.showAlert = true
                    } else {
                        self.submitUsername()
                    }
                }
            }
        }
    }

    
    
    
    
    
    
    private func fetchUserData() {
        let db = Firestore.firestore()
        db.collection("users").document(userIdentifier).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                if let fullName = data["fullName"] as? String {
                    generateUsername(from: fullName)
                }
            } else if let error = error {
                print("Error fetching user data: \(error)")
            }
        }
    }
    
    private func generateUsername(from fullName: String) {
        let nameParts = fullName.split(separator: " ").map(String.init)
        if nameParts.count >= 2 {
            self.username = "\(nameParts[0]).\(nameParts[1])".lowercased()
        }
    }
    
    
    private func isContentInappropriate(_ text: String) -> Bool {
            // Implement your logic to check for inappropriate content
            // This is a placeholder
            return false
        }
    private func submitUsername() {
        // Validate username length
        guard username.count >= 3, username.count <= 15 else {
            alertMessage = "Username must be between 3 and 15 characters."
            showAlert = true
            return
        }

        // Validate display name length
        guard displayname.count >= 3, displayname.count <= 20 else {
            alertMessage = "Display name must be between 3 and 20 characters."
            showAlert = true
            return
        }

        // Check for inappropriate content in username and display name
        checkForInappropriateContent(text: username, isUsernameCheck: true)
    }

    private func checkForInappropriateContent(text: String, isUsernameCheck: Bool) {
        NexChat.isContentInappropriate(text: text) { containsProfanity in
            if containsProfanity {
                self.alertMessage = isUsernameCheck ? "Username contains inappropriate content." : "Display Name contains inappropriate content."
                self.showAlert = true
            } else {
                if isUsernameCheck {
                    // If checking username, now check display name
                    checkForInappropriateContent(text: self.displayname, isUsernameCheck: false)
                } else {
                    // If checking display name, proceed to save
                    checkAvailability()
                }
            }
        }
    }

    private func checkAvailability() {
        let db = Firestore.firestore()
        db.collection("users").whereField("username", isEqualTo: username)
            .getDocuments { snapshot, error in
                if error != nil {
                    self.alertMessage = "Error occurred while checking username."
                    self.showAlert = true
                } else if let snapshot = snapshot, !snapshot.isEmpty {
                    self.alertMessage = "This username is already in use. Please choose another."
                    self.showAlert = true
                } else {
                    // Check display name availability
                    db.collection("users").whereField("Display Name", isEqualTo: self.displayname)
                        .getDocuments { snapshot, error in
                            if error != nil {
                                self.alertMessage = "Error occurred while checking display name."
                                self.showAlert = true
                            } else if let snapshot = snapshot, !snapshot.isEmpty {
                                self.alertMessage = "This display name is already in use. Please choose another."
                                self.showAlert = true
                            } else {
                                // Both username and display name are available
                                self.saveUsername()
                            }
                        }
                }
            }
    }

    private func saveUsername() {
        let db = Firestore.firestore()
        db.collection("users").document(userIdentifier).setData(["username": username, "Display Name": displayname], merge: true) { error in
            if error != nil {
                self.alertMessage = "An error occurred while saving the username and display name."
                self.showAlert = true
            } else {
                self.checkShoeSelection()
            }
        }
    }
    
    private func checkShoeSelection() {
        let db = Firestore.firestore()
        db.collection("users").document(userIdentifier).getDocument { document, error in
            if let document = document, document.exists {
                if document.data()?["shoe"] == nil {
                    // No shoe selected, navigate to SelectShoeView
                    self.navigateToSelectShoe = true
                } else {
                    // Shoe already selected, proceed with existing flow
                    self.onUsernameSubmitted()
                }
            } else {
                // Handle error or case where document does not exist
                // Optionally handle the error here
            }
        }
    }
}

struct customViewModifier: ViewModifier {
    var roundedCornes: CGFloat
    var startColor: Color
    var endColor: Color
    var textColor: Color
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(LinearGradient(gradient: Gradient(colors: [startColor, endColor]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(roundedCornes)
            .padding(3)
            .foregroundColor(textColor)
            .overlay(RoundedRectangle(cornerRadius: roundedCornes)
                .stroke(LinearGradient(gradient: Gradient(colors: [startColor, endColor]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5))
            .font(.custom("Open Sans", size: 18))
            .shadow(radius: 10)
    }
}











import Foundation

// Function to check for inappropriate content using Profanity Filter API
func isContentInappropriate(text: String, completion: @escaping (Bool) -> Void) {
    guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        completion(false)
        return
    }

    let urlString = "https://api.api-ninjas.com/v1/profanityfilter?text=\(encodedText)"
    guard let url = URL(string: urlString) else {
        completion(false)
        return
    }

    var request = URLRequest(url: url)
    request.setValue("u9NBtwqO/Hvg0LsEiqWPMQ==RYNm0p4jPRadb89K", forHTTPHeaderField: "X-Api-Key")

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            completion(false)
            return
        }

        do {
            if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let hasProfanity = jsonResponse["has_profanity"] as? Bool {
                completion(hasProfanity)
            } else {
                completion(false)
            }
        } catch {
            completion(false)
        }
    }
    task.resume()
}








#Preview {
    CreateUsernameView(onUsernameSubmitted: {}, userIdentifier: "preview")
}
