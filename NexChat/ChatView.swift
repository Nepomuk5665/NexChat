//
//  ChatView.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 19.01.2024.
//

import SwiftUI
import Firebase
import Combine
import Shimmer


struct ChatView: View {
  var userID: String // The ID of the user you are chatting with
  var myuserID: String // Your user ID
   
  @State private var messageListenerRegistration: ListenerRegistration?
   
  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
   
  @State private var messages: [Message] = []
  @State private var newMessageText = ""
   
  @State private var shouldMarkMessagesAsRead = false
  @State private var bounce = 1
   
  @State private var isinchat = false
   
  @State private var istyping = false
   
  @State private var lastTypingTime = Date()
  @State private var typingTimer: Timer?
   
  @State private var cancellables: Set<AnyCancellable> = []
  let appWillResignActivePublisher = NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
   
  @Environment(\.scenePhase) private var scenePhase
   
  @State private var nexes: [Nex] = []
   
   
  var body: some View {
    VStack {
      // Messages list
      ZStack{
        ScrollViewReader { scrollProxy in // <- Use ScrollViewReader
          ScrollView (.vertical, showsIndicators: false) {
            // Inside your ScrollView
            VStack {
              ForEach(messages, id: \.id) { message in
                MessageView(message: message, isCurrentUser: message.senderID == myuserID)
              }
              NexPreviewView(nexes: nexes, myuserID: myuserID, userID: userID)
            }

          }
          .padding(.leading)
          .padding(.trailing)
          .onChange(of: messages) { _ in // <- Scroll when messages change
            scrollToBottom(proxy: scrollProxy)
          }
          .onChange(of: newMessageText) { _ in // <- Scroll when the user is typing
            scrollToBottom(proxy: scrollProxy)
          }
          .onAppear { // <- Scroll when the view appears
             
            scrollToBottom(proxy: scrollProxy)
          }
          .onChange(of: newMessageText) { _ in
            // Call function to update typing indicator in Firestore
            setTypingIndicator(isTyping: !newMessageText.isEmpty)
          }
          .onDisappear {
            // Remove the listener when the view disappears
            messageListenerRegistration?.remove()
          }
          .onAppear {
            shouldMarkMessagesAsRead = true
            loadMessages()
            loadNexes()
            updateUserStatus(isInChat: true)
            listenToOtherUserTypingStatus()
             
            // Subscribe to app lifecycle notifications
            appWillResignActivePublisher
              .receive(on: RunLoop.main)
              .sink { _ in
                updateUserStatus(isInChat: false)
              }
              .store(in: &cancellables)
          }
          .onDisappear {
            shouldMarkMessagesAsRead = false
            messageListenerRegistration?.remove()
            updateUserStatus(isInChat: false)
             
            // Cancel the subscriptions
            cancellables.forEach { $0.cancel() }
            cancellables.removeAll()
          }
          .onReceive(appWillResignActivePublisher) { _ in
            updateUserStatus(isInChat: false)
          }
          .onChange(of: scenePhase) { newScenePhase in
            switch newScenePhase {
            case .background, .inactive:
              // App is moving to the background or is inactive, update the inChat status to false
              updateUserStatus(isInChat: false)
            case .active:
              // App is active, update the inChat status to true
              updateUserStatus(isInChat: true)
            @unknown default:
              break
            }
          }
           
        }
        VStack {
          Spacer()
           
          if isinchat && !istyping {
            Image(systemName: "person.2")
              .foregroundStyle(.yellow)
              .frame(maxWidth: .infinity, alignment: .trailing)
              .padding()
              .transition(.opacity)
              .animation(.default, value: isinchat && !istyping)
          } else if isinchat && istyping {
            Image(systemName: "ellipsis.message")
              .foregroundStyle(.yellow)
              .symbolEffect(.bounce.up.byLayer, value: bounce)
              .frame(maxWidth: .infinity, alignment: .trailing)
              .padding()
              .onReceive(timer) { _ in
                withAnimation {
                  bounce += 1
                }
              }
              .transition(.opacity)
              .animation(.default, value: isinchat && istyping)
          }
        }
         
         
         
      }
       
       
      // Message input field
      HStack {
        TextField("Message", text: $newMessageText)
          .textFieldStyle(RoundedBorderTextFieldStyle())
         
          .padding()
         
        Button("Send") {
          sendMessage()
        }
        .padding()
      }
    }
    .navigationBarTitle("Chat", displayMode: .inline)
     
     
    .onAppear {
      shouldMarkMessagesAsRead = true
      loadMessages()
      updateUserStatus(isInChat: true)
      listenToOtherUserTypingStatus() // Add this line
    }
     
     
    .onDisappear {
      shouldMarkMessagesAsRead = false
      messageListenerRegistration?.remove()
      updateUserStatus(isInChat: false)
    }
     
     
  }
   
  private func timeSinceLastTyping() -> Double {
    return -lastTypingTime.timeIntervalSinceNow
  }
   
   
  private func loadNexes() {
    let db = Firestore.firestore()

    // Assuming Nexes are saved under each user's "Nexes" subcollection
    let myNexesRef = db.collection("users").document(myuserID).collection("Nexes")
    let partnerNexesRef = db.collection("users").document(userID).collection("Nexes")

    // Listen to my Nexes
    myNexesRef.whereField("receiverID", isEqualTo: userID).addSnapshotListener { (querySnapshot, error) in
      guard let documents = querySnapshot?.documents else {
        print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
        return
      }
      let myNexes = documents.compactMap { try? $0.data(as: Nex.self) }
      self.nexes.append(contentsOf: myNexes)

      // Deduplication (if 'Nex' is now 'Hashable')
      self.nexes = Array(Set(self.nexes))
    }

    // Listen to partner's Nexes
    partnerNexesRef.whereField("receiverID", isEqualTo: myuserID).addSnapshotListener { (querySnapshot, error) in
      guard let documents = querySnapshot?.documents else {
        print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
        return
      }
      let partnerNexes = documents.compactMap { try? $0.data(as: Nex.self) }
      self.nexes.append(contentsOf: partnerNexes)

      // Deduplication (if 'Nex' is now 'Hashable')
      self.nexes = Array(Set(self.nexes))
    }
  }




   
   
  private func updateUserStatus(isInChat: Bool) {
    let db = Firestore.firestore()
    let chatID = getChatID(myuserID: myuserID, userID: userID)
     
    // Update your user's 'inChat' status
    db.collection("chats").document(chatID).collection("users").document(myuserID).setData([
      "inChat": isInChat,
      "lastSeen": Timestamp()
    ], merge: true)
     
    // Start listening to the other user's 'inChat' status
    if isInChat {
      listenToOtherUserStatus()
    } else {
      // Stop listening to the other user's 'inChat' status
      // Implement this if needed
    }
  }
   
   
  private func listenToOtherUserStatus() {
    let db = Firestore.firestore()
    let chatID = getChatID(myuserID: myuserID, userID: userID)
     
    db.collection("chats").document(chatID).collection("users").document(userID)
      .addSnapshotListener { documentSnapshot, error in
        guard let document = documentSnapshot else {
          print("Error fetching document: \(error!)")
          return
        }
        guard let data = document.data() else {
          print("Document data was empty.")
          return
        }
        withAnimation{
          self.isinchat = data["inChat"] as? Bool ?? false
        }
      }
  }
   
   
  private func setTypingIndicator(isTyping: Bool) {
    let currentTime = Date()
    lastTypingTime = currentTime
     
    if isTyping {
      typingTimer?.invalidate()
      typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
        if currentTime == self.lastTypingTime {
          // The user hasn't typed for 2 seconds, set isTyping to false
          self.updateTypingStatusInFirestore(isTyping: false)
        }
      }
    }
     
    updateTypingStatusInFirestore(isTyping: isTyping)
  }
   
   
  private func updateTypingStatusInFirestore(isTyping: Bool) {
    let db = Firestore.firestore()
    let chatID = getChatID(myuserID: myuserID, userID: userID)
     
    db.collection("typingIndicators").document(chatID).setData([
      "senderID": myuserID,
      "receiverID": userID,
      "isTyping": isTyping,
      "lastTyped": isTyping ? Timestamp() : nil
    ], merge: true)
  }
   
   
  private func listenToOtherUserTypingStatus() {
    let db = Firestore.firestore()
    let chatID = getChatID(myuserID: myuserID, userID: userID)
     
    db.collection("typingIndicators").document(chatID)
      .addSnapshotListener { documentSnapshot, error in
        guard let document = documentSnapshot else {
          print("Error fetching document: \(error!)")
          return
        }
        guard let data = document.data() else {
          print("Document data was empty.")
          return
        }
        if let otherUserID = data["senderID"] as? String, otherUserID == userID {
          withAnimation{
            self.istyping = data["isTyping"] as? Bool ?? false
          }
          // Consider checking 'lastTyped' timestamp to determine if you should show typing indicator
        }
      }
  }
   
   
   
   
  private func markChatAsViewed() {
    let db = Firestore.firestore()
    let chatID = getChatID(myuserID: myuserID, userID: userID)
     
    db.collection("chats").document(chatID).updateData([
      "notificationsViewed": true
    ]) { err in
      if let err = err {
        print("Error updating document: \(err)")
      } else {
        print("Document successfully updated")
      }
    }
  }
   
   
   
   
  private func scrollToBottom(proxy: ScrollViewProxy) {
    if let lastMessage = messages.last {
      withAnimation {
        proxy.scrollTo(lastMessage.id, anchor: .bottom)
      }
    }
  }
   
   
   
   
   
   
  private func loadMessages() {
    let chatID = getChatID(myuserID: myuserID, userID: userID)
    let db = Firestore.firestore()
    let messagesRef = db.collection("chats").document(chatID).collection("messages")
     
    messagesRef
      .order(by: "timestamp", descending: false)
      .addSnapshotListener { querySnapshot, error in
        guard let snapshot = querySnapshot else {
          print("Error fetching snapshots: \(error!)")
          return
        }
        self.messages = snapshot.documents.compactMap { doc -> Message? in
          try? doc.data(as: Message.self)
        }
         
        if shouldMarkMessagesAsRead {
          markMessagesAsRead()
        }
      }
  }
   
   
   
  private func markMessagesAsRead() {
    let chatID = getChatID(myuserID: myuserID, userID: userID)
    let db = Firestore.firestore()
    let messagesRef = db.collection("chats").document(chatID).collection("messages")
     
    for message in self.messages where message.receiverID == self.myuserID && !message.read {
      let messageId = message.id ?? ""
      let messageRef = messagesRef.document(messageId)
      messageRef.updateData(["read": true, "receivedTimestamp": Timestamp()]) { err in
        if let err = err {
          print("Error updating document \(messageId): \(err)")
        } else {
          print("Document \(messageId) successfully updated")
        }
      }
    }
  }
   
   
   
  private func sendMessage() {
    let db = Firestore.firestore()
    let chatID = getChatID(myuserID: myuserID, userID: userID)
     
    let newMessage = Message(
      senderID: myuserID,
      receiverID: userID,
      content: newMessageText,
      timestamp: Timestamp(),
      read: false // Set the read flag to false for new messages
    )
     
    var ref: DocumentReference? = nil
    ref = db.collection("chats").document(chatID).collection("messages").addDocument(data: newMessage.dictionary) { err in
      if let err = err {
        print("Error adding document: \(err)")
      } else {
        print("Document added with ID: \(ref!.documentID)")
        // Clear the received flag when the current user sends a message
         
        // Removed the line referencing lastMessageIdFromOtherUser
      }
    }
    newMessageText = ""
  }
   
   
   
   
   
   
   
   
   
   
   
   
  private func getChatID(myuserID: String, userID: String) -> String {
    // Ensure chatID is always the same regardless of who is the sender or receiver
    return [myuserID, userID].sorted().joined(separator: "_")
  }
   
   
   
   
   
}




struct NexPreviewView: View {
  var nexes: [Nex]
  var myuserID: String
  var userID: String

  var body: some View {
    ForEach(nexes, id: \.id) { nex in
      if (nex.senderID == myuserID && nex.receiverID == userID) || (nex.senderID == userID && nex.receiverID == myuserID) {
        NexSmallPreview(SentByMe: nex.senderID == myuserID, Seen: nex.opened)
      }
    }
  }
}








struct Nex: Identifiable, Codable, Hashable {
  @DocumentID var id: String? // Unique identifier for Firestore documents
  var frontImageURL: String
  var backImageURL: String
  var senderID: String
  var receiverID: String
  var timestamp: Timestamp
  var opened: Bool

  enum CodingKeys: String, CodingKey {
    case id
    case frontImageURL = "frontImageURL"
    case backImageURL = "backImageURL"
    case senderID = "senderID"
    case receiverID = "receiverID"
    case timestamp = "timestamp"
    case opened = "opened"
  }

  // Implementation of Hashable protocol
  func hash(into hasher: inout Hasher) {
    hasher.combine(id) // Assume `id` is the primary unique identifier
  }

  // Equatable conformance is provided automatically for structs,
  // but it's based on all properties. If you only want to compare using `id`,
  // you can override the equality operator.
  static func == (lhs: Nex, rhs: Nex) -> Bool {
    lhs.id == rhs.id
  }
}








struct Message: Identifiable, Codable, Equatable {
  @DocumentID var id: String?
  var senderID: String
  var receiverID: String
  var content: String
  var timestamp: Timestamp
  var read: Bool
  var readTimestamp: Timestamp?
  var receivedTimestamp: Timestamp?
   
  enum CodingKeys: String, CodingKey {
    case id
    case senderID = "sender_id"
    case receiverID = "receiver_id"
    case content
    case timestamp
    case read
    case readTimestamp
    case receivedTimestamp
  }
   
  var dictionary: [String: Any] {
    var dict: [String: Any] = [
      "sender_id": senderID,
      "receiver_id": receiverID,
      "content": content,
      "timestamp": timestamp,
      "read": read
    ]
    if let readTimestamp = readTimestamp {
      dict["readTimestamp"] = readTimestamp
    }
    if let receivedTimestamp = receivedTimestamp {
      dict["receivedTimestamp"] = receivedTimestamp
    }
    return dict
  }
   
  static func == (lhs: Message, rhs: Message) -> Bool {
    return lhs.id == rhs.id &&
    lhs.senderID == rhs.senderID &&
    lhs.receiverID == rhs.receiverID &&
    lhs.content == rhs.content &&
    lhs.timestamp.dateValue() == rhs.timestamp.dateValue() &&
    lhs.read == rhs.read &&
    lhs.readTimestamp?.dateValue() == rhs.readTimestamp?.dateValue() &&
    lhs.receivedTimestamp?.dateValue() == rhs.receivedTimestamp?.dateValue()
  }
}

struct NexSmallPreview: View {
  var SentByMe: Bool
  var Seen: Bool
  var body: some View {
    HStack{
      Spacer()
      if !Seen{
        if !SentByMe{
          Rectangle()
            .frame(width: 30, height: 30)
            .cornerRadius(7.5)
            .foregroundColor(SentByMe ? .gray : .red)
            .padding(.top)
            .padding(.bottom)
        }else{
          Image(systemName: "righttriangle.fill")
            .rotationEffect(.degrees(-45))
            .frame(width: 30, height: 30)
            .foregroundColor(.red)
        }
      }else{
        if SentByMe{
          Image(systemName: "righttriangle")
            .rotationEffect(.degrees(-45))
            .frame(width: 30, height: 30)
            .foregroundColor(.red)
        }else{
          RoundedRectangle(cornerRadius: 7.5)
            .stroke(.red, lineWidth: 1)
            .frame(width: 30, height: 30)
        }
      }
      Text(SentByMe ? "Sent Nex" : "Nex Nex")
      Spacer()
    }.padding(.leading)
      .padding(.trailing)
     
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(SentByMe ? .gray : .yellow, lineWidth: 1)
         
      ).padding(.leading)
      .padding(.trailing)
  }
}


// Representing the view for a single message
struct MessageView: View {
  let message: Message
  let isCurrentUser: Bool // Determines message alignment
   
  var body: some View {
    HStack {
      if isCurrentUser {
        Spacer()
        Text(message.content)
          .padding()
          .background(Color.blue)
          .cornerRadius(10)
          .foregroundColor(.white)
      } else {
        Text(message.content)
          .padding()
          .background(Color.gray)
          .cornerRadius(10)
          .foregroundColor(.white)
        Spacer()
      }
    }
  }
}




#Preview{
    ChatView(userID: "001194.4cccbf2267024cb5b5bd4187cb3102a2.2035", myuserID: "000644.3c8d5a8165f4403db1497ed5a0ab9c22.1411")
}
