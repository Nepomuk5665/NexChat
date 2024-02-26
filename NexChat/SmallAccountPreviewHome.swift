//
//  SmallAccountPreviewHome.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 19.01.2024.
//

import SwiftUI
import Firebase

struct SmallAccountPreviewHome: View {
    var userID: String
    var myuserID: String
    var onCameraTap: (() -> Void)?

    @State private var refreshKey = UUID()
    
    @State private var displayName: String = "Loading..."
    @State private var shoeBaseURL: String = "https://images.stockx.com/360/Air-Jordan-11-Retro-DMP-Defining-Moments-2023-GS/Images/Air-Jordan-11-Retro-DMP-Defining-Moments-2023-GS/Lv2/img"
    
    @State private var isFriend: Bool = false
    @State private var friendRequestStatus: String? = nil
    @State private var isRequestSentByMe: Bool = false
    @State private var newChat = false
    
    @State private var deliverd = false
    
    @State private var opend = false
    
    
    @State private var lastMessageTimestamp: Date?
    
    @State private var received = false
    
    @State private var lastMessageIdFromOtherUser: String?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            
            NavigationLink(destination: ChatView(userID: userID, myuserID: myuserID)) {
                Rectangle()
                    .fill(.white)
                    .frame(height: 60)
                
            }
            
            
            VStack {
                
                HStack {
                    
                    
                    
                    
                    NavigationLink(destination: PreviewUser(userID: userID)) {
                        ShoePreview(baseURL: shoeBaseURL)
                            .id(refreshKey)
                            .frame(width: 83, height: 60)
                        
                    }
                    
                    VStack {
                        Text(displayName)
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading)
                        
                        if newChat {
                            HStack {
                                Rectangle()
                                    .fill(.blue)
                                    .frame(width: 20, height: 20)
                                    .cornerRadius(4)
                                
                                Text("New Chat")
                                    .bold()
                                    .foregroundStyle(.blue)
                                
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        else if received{
                            HStack {
                                Image(systemName: "envelope.open")
                                
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                
                                if let receivedTimestamp = self.lastMessageTimestamp {
                                    Text("received • \(timeAgoSinceDate(receivedTimestamp))")
                                        .foregroundStyle(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                        else if deliverd{
                            HStack{
                                
                                Image(systemName: "righttriangle.fill")
                                    .rotationEffect(.degrees(-45))
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                
                                if let lastMessageTimestamp = lastMessageTimestamp {
                                    Text("delivered • \(timeAgoSinceDate(lastMessageTimestamp))")
                                        .foregroundStyle(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .font(.system(size: 14))
                                }
                                
                                
                                
                                
                                
                            }
                            
                        }
                        else if opend {
                            HStack{
                                
                                Image(systemName: "righttriangle")
                                    .rotationEffect(.degrees(-45))
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                
                                if let lastMessageTimestamp = lastMessageTimestamp {
                                    Text("opened • \(timeAgoSinceDate(lastMessageTimestamp))")
                                        .foregroundStyle(.gray)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .font(.system(size: 14))
                                }
                                
                                
                                
                                
                            }
                        }
                    }
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .onTapGesture {
                            print("Making Nex")
                            onCameraTap?()
                        }
                    
                }
                .padding(.leading)
                Rectangle()
                    .frame(height: 0.2)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            
            loadUserData()
            checkForUnreadMessages()
            getLastMessageInfo()
        }
        .onReceive(timer) { _ in
            
            getLastMessageInfo()
        }
    }
    
    
    
    
    
    private func getLastMessageInfo() {
        let db = Firestore.firestore()
        let chatID = getChatID(myuserID: myuserID, userID: userID)
        
        db.collection("chats").document(chatID).collection("messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error fetching last message: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents, let lastMessageData = documents.first?.data() else {
                    print("No documents found or data could not be fetched.")
                    return
                }
                
                self.lastMessageTimestamp = (lastMessageData["timestamp"] as? Timestamp)?.dateValue()
                
                let lastMessageSenderId = lastMessageData["sender_id"] as? String
                let isLastMessageRead = lastMessageData["read"] as? Bool ?? false
                
                // Reset all flags initially
                self.received = false
                self.deliverd = false
                self.opend = false
                
                print("Debug Info: Sender ID: \(lastMessageSenderId ?? "nil"), Is Read: \(isLastMessageRead)")
                
                if lastMessageSenderId == userID {
                    // The last message was from the other user
                    if !isLastMessageRead {
                        // The last message from the other user is not read
                        self.received = true
                        print("Last message from other user is received and not read. Sender ID: \(lastMessageSenderId ?? "nil"), Is Read: \(isLastMessageRead)")
                    } else {
                        // The last message from the other user is read
                        // You can decide if you want to mark it as opened or keep it as received based on your app's requirements.
                        // For now, we will keep it as 'received' even if read.
                        self.received = true
                        print("Last message from other user is received and read. Sender ID: \(lastMessageSenderId ?? "nil"), Is Read: \(isLastMessageRead)")
                    }
                } else if lastMessageSenderId == myuserID {
                    // The last message was from the current user
                    if !isLastMessageRead {
                        // The last message from the current user is not read by the other user
                        self.deliverd = true
                        print("Last message from current user is delivered and not read. Sender ID: \(lastMessageSenderId ?? "nil"), Is Read: \(isLastMessageRead)")
                    } else {
                        // The last message from the current user is read by the other user
                        self.opend = true
                        print("Last message from current user is opened by other user. Sender ID: \(lastMessageSenderId ?? "nil"), Is Read: \(isLastMessageRead)")
                    }
                }
            }
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    private func checkForUnreadMessages() {
        let db = Firestore.firestore()
        let chatID = getChatID(myuserID: myuserID, userID: userID)
        
        // Set up a listener for unread messages
        db.collection("chats").document(chatID).collection("messages")
            .whereField("receiver_id", isEqualTo: myuserID)
            .whereField("read", isEqualTo: false)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("Error fetching unread messages: \(error.localizedDescription)")
                    return
                }
                
                // If there are unread messages, set newChat to true
                self.newChat = !(querySnapshot?.documents.isEmpty ?? true)
            }
    }
    
    private func getChatID(myuserID: String, userID: String) -> String {
        let sortedIDs = [myuserID, userID].sorted()
        let chatID = sortedIDs.joined(separator: "_")
        return chatID
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
    
    
    func timeAgoSinceDate(_ date: Date, numericDates: Bool = true) -> String {
        let calendar = Calendar.current
        let now = Date()
        let unitFlags: Set<Calendar.Component> = [.minute, .hour, .day, .weekOfYear, .month, .year, .second]
        let components = calendar.dateComponents(unitFlags, from: date, to: now)
        
        if let year = components.year, year >= 1 {
            return year == 1 ? "1 year ago" : "\(year)y ago"
        } else if let month = components.month, month >= 1 {
            return month == 1 ? "1 month ago" : "\(month)mo ago"
        } else if let week = components.weekOfYear, week >= 1 {
            return week == 1 ? "1 week ago" : "\(week)w ago"
        } else if let day = components.day, day >= 1 {
            return day == 1 ? "1 day ago" : "\(day)d ago"
        } else if let hour = components.hour, hour >= 1 {
            return hour == 1 ? "1 hour ago" : "\(hour)h ago"
        } else if let minute = components.minute, minute >= 1 {
            return minute == 1 ? "1 minute ago" : "\(minute)m ago"
        } else if let second = components.second, second >= 10 {
            return second == 1 ? "1 second ago" : "\(second)s ago"
        } else {
            return "just now"
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
    SmallAccountPreviewHome(userID: "001083.34bfd7f586ce42da997ff9b6c73103f2.2322", myuserID: "000644.3c8d5a8165f4403db1497ed5a0ab9c22.1411")
}
