//
//  chooseview.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 03.01.2024.
//

import SwiftUI
import AuthenticationServices
import Firebase
import FirebaseFirestore
import Pow
struct chooseview: View {
    @State private var shouldNavigateToHome = false
    @State private var showCreateUsernameView = false
    @State private var userIdentifier: String = ""
    @State private var hasUsername = false
    @State private var navigateToCreateUsername = false
    @State private var navigateToHome = false
    @State private var showSelectShoeView = false
    @State var canContinue = true
    @AppStorage("userID") var userID: String = ""
    var body: some View {
        NavigationView {
            ZStack {
                Rectangle()
                    .fill(.black)
                    .ignoresSafeArea(.all)

                Image("nexchat_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250.0, height: 250.0)
                
                VStack {
                    Spacer()

                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let auth):
                                if let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential {
                                    print("AppleID Credential received: \(appleIDCredential)")
                                    userID = "\(appleIDCredential)"
                                    checkUsernameExists(credential: appleIDCredential)
                                    
                                } else {
                                    print("Credential is not of type ASAuthorizationAppleIDCredential")
                                }

                            case .failure(let error):
                                print("Authentication error: \(error.localizedDescription)")
                            }
                        }
                    )
                    .conditionalEffect(
                              .repeat(
                                .glow(color: .blue, radius: 120),
                                every: 1.5
                              ),
                              condition: canContinue
                          )
                          .disabled(!canContinue)
                          .animation(.default, value: canContinue)
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 45)
                    .padding([.trailing, .leading, .top])

                    NavigationLink(destination: HomeView(userIdentifier: userIdentifier), isActive: $navigateToHome) { EmptyView() }
                    NavigationLink(
                        destination: CreateUsernameView(
                            onUsernameSubmitted: {
                                self.navigateToHome = true
                            },
                            userIdentifier: userIdentifier
                        ),
                        isActive: $showCreateUsernameView
                    ) { EmptyView() }
                    NavigationLink(
                                destination: SelectShoeView(userIdentifier: userIdentifier, onShoeSelected: {
                                    self.navigateToHome = true
                                }),
                                isActive: $showSelectShoeView
                            ) { EmptyView() }

                }
                
            }
        }
    }

    private func checkUsernameExists(credential: ASAuthorizationAppleIDCredential) {
        let userID = credential.user
        if userID.isEmpty {
            print("Invalid user ID.")
            return
        }
        
        print("Checking if username exists for userID: \(userID)")
        
        let db = Firestore.firestore()
        let userDocument = db.collection("users").document(userID)
        
        userDocument.getDocument { (document, error) in
            if let error = error {
                // Handle the error
                print("Error getting document for userID \(userID): \(error.localizedDescription)")
                return
            }
            
            guard let document = document else {
                print("Document is nil for userID: \(userID)")
                self.uploadUserData(credential: credential)
                self.userIdentifier = userID
                self.showCreateUsernameView = true
                return
            }
            
            if document.exists {
                print("Document exists for userID \(userID), navigating accordingly.")
                self.userIdentifier = userID
                let data = document.data()
                if data?["username"] != nil && data?["shoe"] != nil {
                    // Username and shoe exist, navigate to HomeView
                    self.navigateToHome = true
                } else if data?["username"] != nil {
                    // Username exists but no shoe, navigate to SelectShoeView
                    self.showSelectShoeView = true
                } else {
                    // No username, navigate to CreateUsernameView
                    self.showCreateUsernameView = true
                }
            } else {
                // No document, create new user data and navigate to CreateUsernameView
                print("No document found for userID \(userID), creating new user data.")
                self.uploadUserData(credential: credential)
                self.userIdentifier = userID
                self.showCreateUsernameView = true
            }
        }
    }



    private func uploadUserData(credential: ASAuthorizationAppleIDCredential) {
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        let email = credential.email ?? "Email not available"

        let db = Firestore.firestore()
        db.collection("users").document(credential.user).setData([
            "fullName": fullName,
            "email": email,
            "coins": 0,
        ], merge: true) { error in
            if let error = error {
                print("Error uploading user data: \(error.localizedDescription)")
            } else {
                print("User data successfully uploaded.")
            }
        }
    }


}


#Preview {
    chooseview()
}
