//
//  FriendRequestsView.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 15.01.2024.
//

import SwiftUI
import Firebase

struct FriendRequest: Identifiable {
    var id: String
    var fromUserID: String
    var fromUserName: String
    var status: String  // Add status property
}

struct FriendRequestsView: View {
    var userID: String
    @State private var friendRequests: [FriendRequest] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 20) { // Adjust spacing as needed
                ForEach(friendRequests) { request in
                    SmallAccountPreview(userID: request.fromUserID, myuserID: userID)
                        .padding() // Optional padding for each preview
                }
            }
        }
        .onAppear(perform: loadFriendRequests)
    }

    private func loadFriendRequests() {
        let db = Firestore.firestore()
        db.collection("friendRequests")
          .whereField("toUserID", isEqualTo: userID)
          .whereField("status", isEqualTo: "pending")
          .getDocuments { (snapshot, error) in
              if let error = error {
                  print("Error getting friend requests: \(error.localizedDescription)")
              } else if let snapshot = snapshot {
                  print("Friend requests fetched: \(snapshot.documents.count)")
                  self.friendRequests = snapshot.documents.compactMap { doc in
                      let data = doc.data()
                      let fromUserID = data["fromUserID"] as? String ?? ""
                      let status = data["status"] as? String ?? ""
                      // Fetch the actual username if needed here
                      return FriendRequest(
                          id: doc.documentID,
                          fromUserID: fromUserID,
                          fromUserName: "User \(fromUserID)", // Placeholder for actual user name
                          status: status
                      )
                  }
              }
          }
    }
}










#Preview {
    FriendRequestsView(userID: "001083.34bfd7f586ce42da997ff9b6c73103f2.2322")
}
