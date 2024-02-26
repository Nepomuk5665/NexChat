//
//  SmallAccountPreview.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 15.01.2024.
//

import SwiftUI
import Firebase

struct SmallAccountPreview: View {
    var userID: String
    var myuserID: String
    @State private var refreshKey = UUID()
    
    @State private var displayName: String = "Loading..."
    @State private var shoeBaseURL: String = "https://images.stockx.com/360/Air-Jordan-11-Retro-DMP-Defining-Moments-2023-GS/Images/Air-Jordan-11-Retro-DMP-Defining-Moments-2023-GS/Lv2/img"
    
    @State private var isFriend: Bool = false
    @State private var friendRequestStatus: String? = nil
    
    @State private var listenerRegistration: ListenerRegistration?
    
    @State private var isRequestSentByMe: Bool = false
    
    var body: some View {
        ZStack {
            NavigationLink(destination: PreviewUser(userID: userID)) {
                Rectangle()
                    .fill(.gray)
                    .frame(height: 80)
                    .cornerRadius(20)
                    .padding(.leading)
                    .padding(.trailing)
            }
                    HStack {
                        NavigationLink(destination: PreviewUser(userID: userID)) {
                            
                            
                            Rectangle()
                                .frame(width: 5, height: 1)
                                .opacity(0)
                            Rectangle()
                                .frame(width: 10, height: 1)
                                .opacity(0)
                            ShoePreview(baseURL: shoeBaseURL)
                                .id(refreshKey)
                                .frame(width: 83, height: 60)
                                .cornerRadius(20)
                            
                            Text(displayName)
                                .font(.headline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundColor(.black)
                        }
                        Spacer()
                        if isFriend {
                            // Display a message or icon indicating that you are already friends
                            NavigationLink(destination: PreviewUser(userID: userID)) {
                                Text("Friends")
                                    .foregroundColor(.green)
                            }
                        } else if let friendRequestStatus = friendRequestStatus, friendRequestStatus == "pending" {
                            if !isRequestSentByMe {
                                friendRequestButtons
                            } else {
                                NavigationLink(destination: PreviewUser(userID: userID)) {
                                    Text("Pending...")
                                        .foregroundColor(.orange)
                                }
                            }
                        } else {
                            addButton
                        }
                        Rectangle()
                            .frame(width: 15, height: 1)
                            .opacity(0)
                    }
                }
                .onAppear {
                    loadUserData()
                    checkFriendStatus()
                    setupFriendRequestListener()
                }
                .onDisappear {
                    removeListener()
                }
    }
    
    
    private var isRequestReceived: Bool {
        // Determine if the current user is the receiver of the friend request
        return friendRequestStatus != nil && friendRequestStatus != "sent"
    }
    
    private func setupFriendRequestListener() {
        let db = Firestore.firestore()
        listenerRegistration = db.collection("friendRequests")
            .whereField("fromUserID", in: [myuserID, userID])
            .whereField("toUserID", in: [myuserID, userID])
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error setting up listener: \(error.localizedDescription)")
                } else if let snapshot = snapshot {
                    self.updateFriendRequestStatusFromSnapshot(snapshot)
                }
            }
        
        // Monitor changes to the friends list to keep the isFriend state updated
        db.collection("users").document(myuserID)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error?.localizedDescription ?? "unknown error")")
                    return
                }
                let data = document.data()
                self.isFriend = (data?["friends"] as? [String])?.contains(self.userID) ?? false
                self.refreshKey = UUID() // Force the view to refresh if the friendship status changes
            }
    }

    private func updateFriendRequestStatusFromSnapshot(_ snapshot: QuerySnapshot) {
        // Check if there is a relevant friend request and update states accordingly
        let relevantRequest = snapshot.documents.first { document in
            let data = document.data()
            return (data["fromUserID"] as? String == myuserID && data["toUserID"] as? String == userID) ||
                   (data["fromUserID"] as? String == userID && data["toUserID"] as? String == myuserID)
        }

        if let request = relevantRequest {
            let data = request.data()
            let status = data["status"] as? String ?? "unknown"
            self.friendRequestStatus = status

            // Check if the current user is the one who sent the request
            self.isRequestSentByMe = data["fromUserID"] as? String == myuserID

            // Update friend status if necessary
            if status == "accepted" {
                self.isFriend = true
            }
        } else {
            self.friendRequestStatus = nil
                    self.isRequestSentByMe = false
                }
                // Force refresh the view
                self.refreshKey = UUID()
            }
    
    private func checkIfUsersAreFriends() {
        let db = Firestore.firestore()
        db.collection("users").document(myuserID).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                self.isFriend = (data["friends"] as? [String])?.contains(userID) ?? false
                self.refreshKey = UUID() // Force the view to refresh if the friendship status changes
            }
        }
    }

    
    
    
    
    
    private func removeListener() {
        listenerRegistration?.remove()
    }
    
    
    
    private var addButton: some View {
        Button(action: {
            sendFriendRequest(from: myuserID, to: userID)
        }, label: {
            ZStack {
                Rectangle()
                    .fill(.yellow)
                    .frame(width: 70, height:70)
                    .cornerRadius(20)
                Text("+")
                    .bold()
                    .font(.system(size: 60))
                    .foregroundColor(.black)
            }
        })
    }
    
    
    private func checkFriendStatus() {
        // Check if the user is already a friend
        let db = Firestore.firestore()
        db.collection("users").document(myuserID).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                self.isFriend = (data["friends"] as? [String])?.contains(userID) ?? false
            }
        }
    }
    
    private func checkFriendRequestStatus() {
        let db = Firestore.firestore()
        // Check for both incoming and outgoing friend requests
        db.collection("friendRequests")
            .whereField("toUserID", isEqualTo: myuserID)
            .whereField("fromUserID", isEqualTo: userID)
            .getDocuments { snapshot, error in
                if let documents = snapshot?.documents, !documents.isEmpty {
                    self.friendRequestStatus = documents.first?.data()["status"] as? String
                    self.isRequestSentByMe = false
                } else {
                    // Check for requests sent by me
                    db.collection("friendRequests")
                        .whereField("fromUserID", isEqualTo: myuserID)
                        .whereField("toUserID", isEqualTo: userID)
                        .getDocuments { snapshot, error in
                            if let documents = snapshot?.documents, !documents.isEmpty {
                                self.friendRequestStatus = documents.first?.data()["status"] as? String
                                self.isRequestSentByMe = true
                            }
                        }
                }
            }
    }
    
    private var friendRequestButtons: some View {
        HStack {
            Button(action: {
                acceptFriendRequest()
            }) {
                ZStack{
                    Rectangle()
                        .frame(width: 55 , height: 20)
                        .foregroundColor(.brown)
                        .cornerRadius(5)
                    Text("accept")
                        .bold()
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
            Button(action: {
                rejectFriendRequest()
            }) {
                
                Text("X")
                    .bold()
                    .font(.system(size: 20))
                    .foregroundColor(.black)
                    .opacity(0.4)
                    
            }
        }
    }
    
    private func acceptFriendRequest() {
        // Find the specific friend request document
        let db = Firestore.firestore()
        db.collection("friendRequests")
            .whereField("fromUserID", isEqualTo: userID)
            .whereField("toUserID", isEqualTo: myuserID)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching friend request: \(error.localizedDescription)")
                    return
                }
                guard let snapshot = snapshot, let document = snapshot.documents.first else {
                    print("Friend request document not found")
                    return
                }

                let requestID = document.documentID
                
                // Update the status of the friend request to "accepted"
                db.collection("friendRequests").document(requestID).updateData(["status": "accepted"]) { error in
                    if let error = error {
                        print("Error updating friend request: \(error.localizedDescription)")
                    } else {
                        print("Friend request accepted")
                        
                        // Proceed with adding friends and deleting the request after a delay
                        addFriend(for: myuserID, friendUserID: userID)
                        addFriend(for: userID, friendUserID: myuserID)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            db.collection("friendRequests").document(requestID).delete() { error in
                                if let error = error {
                                    print("Error deleting friend request: \(error.localizedDescription)")
                                } else {
                                    print("Friend request deleted after one second")
                                    self.friendRequestStatus = nil
                                    self.isRequestSentByMe = false
                                    self.checkFriendStatus()
                                    self.refreshKey = UUID()
                                }
                            }
                        }
                    }
                }
            }
    }

    
    private func rejectFriendRequest() {
        updateFriendRequestStatus(to: "rejected")
    }
    
    
    func sendFriendRequest(from fromUserID: String, to toUserID: String) {
        let db = Firestore.firestore()
        let friendRequest = [
            "fromUserID": fromUserID,
            "toUserID": toUserID,
            "status": "pending",
            "notified": false
        ] as [String : Any]
        
        db.collection("friendRequests").addDocument(data: friendRequest) { error in
            if let error = error {
                print("Error sending friend request: \(error.localizedDescription)")
            } else {
                print("Friend request sent successfully")
                
                
                self.isRequestSentByMe = true
                self.friendRequestStatus = "pending"
                self.refreshKey = UUID()
            }
        }
    }


    
    
    
    private func updateFriendRequestStatus(to status: String) {
        let db = Firestore.firestore()
        // Fetch the specific friend request document
        db.collection("friendRequests")
            .whereField("fromUserID", isEqualTo: userID)
            .whereField("toUserID", isEqualTo: myuserID)
            .getDocuments { (snapshot, error) in
                guard let document = snapshot?.documents.first else {
                    print("Error fetching friend request: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                let requestID = document.documentID

                if status == "accepted" {
                    // Add friend for both users
                    addFriend(for: myuserID, friendUserID: userID)
                    addFriend(for: userID, friendUserID: myuserID)
                }

                // Wait for one second before deleting the friend request from Firestore
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    db.collection("friendRequests").document(requestID).delete() { error in
                        if let error = error {
                            print("Error deleting friend request: \(error.localizedDescription)")
                        } else {
                            print("Friend request \(status) successfully and deleted after one second")
                            self.friendRequestStatus = nil
                            self.isRequestSentByMe = false
                            // After updating the request, re-check the friend status
                            self.checkFriendStatus()
                            self.refreshKey = UUID() // Force refresh of the view
                        }
                    }
                }
            }
    }

    
    private func addFriend(for userID: String, friendUserID: String) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).updateData([
            "friends": FieldValue.arrayUnion([friendUserID])
        ]) { error in
            if let error = error {
                print("Error adding friend: \(error.localizedDescription)")
            } else {
                print("Friend added successfully")
                // Trigger the view to update
                self.refreshKey = UUID()
                self.checkFriendStatus() // Check the friend status to update the isFriend state.
            }
        }
    }
    
    
    
    
    private func loadUserData() {
        let db = Firestore.firestore()
        
        db.collection("users").document(userID).getDocument { userDocument, userError in
            if let userError = userError {
                print("Error fetching user: \(userError.localizedDescription)")
                return
            }
            
            if let userDocument = userDocument, userDocument.exists, let userData = userDocument.data() {
                displayName = userData["Display Name"] as? String ?? "Unknown"
                
                
                if let shoeName = userData["shoe"] as? String {
                    loadShoeBaseURL(shoeName: shoeName)
                }
            }
        }
    }
    
    private func loadShoeBaseURL(shoeName: String) {
        let db = Firestore.firestore()
        
        db.collection("shoes").document(shoeName).getDocument { shoeDocument, shoeError in
            if let shoeError = shoeError {
                print("Error fetching shoe: \(shoeError.localizedDescription)")
                return
            }
            
            if let shoeDocument = shoeDocument, shoeDocument.exists, let shoeData = shoeDocument.data() {
                if let baseURL = shoeData["baseURL"] as? String {
                    DispatchQueue.main.async {
                        self.shoeBaseURL = baseURL
                        self.refreshKey = UUID() // Update to refresh the ShoePreview
                    }
                }
            } else {
                print("Shoe document does not exist")
            }
        }
    }
}


#Preview {
    SmallAccountPreview(userID: "001083.34bfd7f586ce42da997ff9b6c73103f2.2322", myuserID: "String")
}
