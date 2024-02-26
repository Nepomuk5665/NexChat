//
//  home.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 03.01.2024.
//


import SwiftUI
import Firebase
import PopupView
import Combine
import FirebaseMessaging




struct HomeView: View {
    @AppStorage("username") var username: String = ""
    @AppStorage("email") var email: String = ""
    @AppStorage("fullName") var fullname: String = ""
    @AppStorage("shoe") var shoe: String = ""
    @AppStorage("userID") var userID: String = ""
    @State private var friends: [UserSearchResult] = []
    let userIdentifier: String
    @State var showingTopLeading = false
    @State private var newFriendRequest: FriendRequest? = nil
    
    @State private var pushNotificationsAuthorized = false
    @State private var listenerRegistration: ListenerRegistration?
    @State private var showingPopup = false
    @State private var refreshKey = UUID()
    @State private var popupTriggerPublisher = PassthroughSubject<Bool, Never>()
    @State private var newFriendRequestPublisher = PassthroughSubject<FriendRequest, Never>()
    @State private var searchText: String = ""
    @State private var searchResults: [UserSearchResult] = []
    
    @State private var makingNex = false
    @State private var otheruserID = "not making nex"
    
    var body: some View {
        if !makingNex{
            NavigationView {
                HStack {
                    VStack {
                        TextField("Search users...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .onChange(of: searchText, perform: searchUsers)
                        
                        // Display friends when the search text is empty
                        if searchText.isEmpty {
                            ForEach(friends, id: \.userID) { friend in
                                
                                SmallAccountPreviewHome(userID: friend.userID, myuserID: userID, onCameraTap: {
                                    withAnimation{
                                        otheruserID = friend.userID
                                        makingNex = true
                                    }
                                })
                                
                                
                                
                            }
                        } else {
                            // Display search results when searching
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(searchResults, id: \.userID) { result in
                                        
                                        SmallAccountPreview(userID: result.userID, myuserID: userID)
                                            .padding(.horizontal)
                                        
                                        
                                        
                                        
                                        
                                        
                                    }
                                }
                            }
                            
                        }
                    }
                    
                    
                    .onAppear(perform: loadData)
                    .navigationBarBackButtonHidden(true)
                    
                    NavigationLink(destination: FriendRequestsView(userID: userID)) {
                        Image(systemName: "info")
                    }
                }
                .onAppear{
                    Messaging.messaging().token { token, error in
                        if let error = error {
                            print("Error fetching FCM registration token: \(error)")
                        } else if let token = token {
                            print("FCM registration token: \(token)")
                            // Update Firestore with this token
                        }
                    }
                    
                }
                .onAppear {
                    print("HomeView appeared")
                    checkPushNotificationsAuthorization()
                    loadUserData()
                    listenForFriendRequests()
                    
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("FCMToken"), object: nil, queue: nil) { notification in
                        if let userInfo = notification.userInfo, let fcmToken = userInfo["token"] as? String {
                            updateFCMToken(fcmToken: fcmToken)
                        }
                    }
                }
                .onDisappear {
                    NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FCMToken"), object: nil)
                }
                
                .onAppear {
                    checkPushNotificationsAuthorization()
                    loadUserData()
                    listenForFriendRequests()
                    
                    NotificationCenter.default.addObserver(forName: NSNotification.Name("FCMToken"), object: nil, queue: nil) { notification in
                        if let userInfo = notification.userInfo, let fcmToken = userInfo["token"] as? String {
                            updateFCMToken(fcmToken: fcmToken)
                        }
                    }
                }
                .onDisappear {
                    NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FCMToken"), object: nil)
                }
            }
            .id(refreshKey)  // Use the refreshKey to force the view to redraw when it changes
            .popup(isPresented: $showingPopup) {
                if let newFriendRequest = newFriendRequest {
                    SmallAccountPreview(userID: newFriendRequest.fromUserID, myuserID: userID)
                        .id(refreshKey)  // Also use refreshKey here to ensure the preview is updated
                }
            } customize: {
                $0.type(.floater()).position(.topLeading).animation(.spring())
            }
            .onAppear {
                updateFCMTokenOnAppear()
                loadUserData()
                listenForFriendRequests()
            }
            .onDisappear {
                // Remove listener when the view disappears
                listenerRegistration?.remove()
            }
            .onReceive(popupTriggerPublisher) { _ in
                // Trigger the popup after a slight delay to ensure all data is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.showingPopup = true
                    self.refreshKey = UUID()  // Change the key to force the view to update
                }
            }
            
        }
        else{
            CreateNex(userID: otheruserID, myuserID: userID, makingNex: $makingNex)
        }
    }
    
    
    
    private func updateFCMTokenOnAppear() {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("Error fetching FCM registration token: \(error)")
            } else if let token = token {
                print("FCM registration token: \(token)")
                // Update Firestore with this token
                let db = Firestore.firestore()
                db.collection("users").document(userID).updateData(["fcmToken": token]) { error in
                    if let error = error {
                        print("Error updating FCM token: \(error.localizedDescription)")
                    } else {
                        print("Successfully updated FCM token")
                    }
                }
            }
        }
    }
    
    
    private func requestPushNotificationsPermission() {
        print("Requesting push notifications permission...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.pushNotificationsAuthorized = granted
                if granted {
                    print("Push notifications permission granted.")
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    print("User denied push notifications.")
                }
            }
        }
    }
    
    private func checkPushNotificationsAuthorization() {
        print("Checking push notifications authorization...")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.pushNotificationsAuthorized = settings.authorizationStatus == .authorized
                if self.pushNotificationsAuthorized {
                    print("Push notifications are authorized.")
                } else {
                    print("Push notifications are not authorized.")
                }
            }
        }
    }
    
    
    
    
    
    private func loadUserData() {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                
                
                if let username = data["username"] as? String {
                    self.username = username
                }
                
                
                
                self.listenForFriendRequests()
            } else {
                print("Document does not exist or failed to fetch user data: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func updateFCMToken(fcmToken: String) {
        guard !userID.isEmpty else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userID).setData(["fcmToken": fcmToken], merge: true) { error in
            if let error = error {
                print("Error updating FCM token: \(error)")
            } else {
                print("FCM token updated successfully")
            }
        }
    }
    
    
    
    
    
    private func listenForFriendRequests() {
        let db = Firestore.firestore()
        listenerRegistration = db.collection("friendRequests")
            .whereField("toUserID", isEqualTo: userID)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    print("Error listening for friend requests updates: \(error?.localizedDescription ?? "No error")")
                    return
                }
                
                // Fetch the list of friend request IDs for which the popup has been shown
                var shownRequestIDs = UserDefaults.standard.stringArray(forKey: "shownFriendRequestIDs") ?? []
                
                snapshot.documentChanges.forEach { change in
                    if (change.type == .added) {
                        let data = change.document.data()
                        let requestId = change.document.documentID
                        
                        // Check if the popup for this friend request has already been shown
                        if !shownRequestIDs.contains(requestId) {
                            let fromUserID = data["fromUserID"] as? String ?? ""
                            let friendRequest = FriendRequest(
                                id: requestId,
                                fromUserID: fromUserID,
                                fromUserName: "User \(fromUserID)", // Placeholder, replace with actual username if available
                                status: data["status"] as? String ?? ""
                            )
                            self.newFriendRequest = friendRequest
                            
                            // Send a signal to trigger the popup
                            self.popupTriggerPublisher.send(true)
                            
                            // Update the list of shown request IDs and save it to UserDefaults
                            shownRequestIDs.append(requestId)
                            UserDefaults.standard.set(shownRequestIDs, forKey: "shownFriendRequestIDs")
                        }
                    }
                }
            }
    }
    
    
    
    
    
    
    
    private func loadData() {
        userID = userIdentifier
        
        
        
        // Debugging output to check the value of userIdentifier
        print("User Identifier: \(userIdentifier)")
        
        guard !userIdentifier.isEmpty else {
            print("Error: User identifier is empty.")
            // Handle the case where userIdentifier is empty.
            // Maybe display an error messagingmessagingmessagingge or return from the function.
            return
        }
        
        
        let db = Firestore.firestore()
        db.collection("users").document(userIdentifier).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                if let cloudUsername = data["username"] as? String, cloudUsername != self.username {
                    self.username = cloudUsername
                }
                if let cloudEmail = data["email"] as? String, cloudEmail != self.email {
                    self.email = cloudEmail
                }
                if let cloudFullName = data["Display Name"] as? String, cloudFullName != self.fullname {
                    self.fullname = cloudFullName
                }
                if let cloudShoe = data["shoe"] as? String, cloudShoe != self.shoe {
                    self.shoe = cloudShoe
                }
                if let friendsArray = data["friends"] as? [String] {
                    self.fetchFriendsUsernames(friendsIDs: friendsArray)
                } else {
                    print("No friends found")
                    self.friends = []
                }
            }
            
        }
    }
    
    private func fetchFriendsUsernames(friendsIDs: [String]) {
        let db = Firestore.firestore()
        var friendsResults: [UserSearchResult] = []
        let group = DispatchGroup()
        
        for friendUserID in friendsIDs {
            group.enter()
            db.collection("users").document(friendUserID).getDocument { friendDoc, err in
                defer { group.leave() }
                if let friendDoc = friendDoc, friendDoc.exists, let friendData = friendDoc.data() {
                    let friendUsername = friendData["username"] as? String ?? "Unknown User"
                    friendsResults.append(UserSearchResult(username: friendUsername, userID: friendUserID))
                }
            }
        }
        
        group.notify(queue: .main) {
            self.friends = friendsResults
        }
    }
    
    
    private func searchUsers(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        let db = Firestore.firestore()
        let queryLowercased = query.lowercased()
        
        db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: queryLowercased)
            .whereField("username", isLessThan: queryLowercased + "\u{f8ff}")
            .getDocuments { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                    searchResults = []
                } else {
                    self.searchResults = querySnapshot?.documents.compactMap { document in
                        if let username = document.data()["username"] as? String {
                            return UserSearchResult(username: username, userID: document.documentID)
                        }
                        return nil
                    } ?? []
                }
            }
    }
    
}









struct CreateNex: View {
    var userID: String
    var myuserID: String
    
    @State private var tookPic = false
    @State private var Pic = false
    @State private var displayName: String = "Loading..." // Default text while loading
    
    @StateObject private var viewModel = CreateNexViewModel()
    
    @Binding var makingNex: Bool
    
    @State var allowed = true
    
    var body: some View {
        if allowed{
            ZStack {
                Rectangle()
                    .foregroundColor(.black)
                    .ignoresSafeArea(.all)
                VStack{
                    Image(systemName: "cross.circle.fill")
                        .rotationEffect(.degrees(45))
                        .foregroundColor(.gray)
                        .font(.system(size: 30))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading)
                        .onTapGesture {
                            makingNex = false
                        }
                    Spacer()
                }
                VStack {
                    
                    
                    
                    Text("NexChat")
                        .font(.system(size: 30))
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .foregroundStyle(.white)
                    
                    Text("to \(displayName)")
                        .foregroundStyle(.white)
                    
                    GeometryReader { proxy in
                        ZStack {
                            CameraFeedView(tookPic: $tookPic, viewModel: viewModel)
                            
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .cornerRadius(8)
                        }
                    }
                    Rectangle()
                        .frame(height: 80)
                        .opacity(0)
                }
                VStack {
                    Spacer()
                    if !Pic {
                        Button(action: {
                            tookPic = true
                            Pic = true
                        }, label: {
                            Image(systemName: "circle.inset.filled")
                                .frame(maxHeight: .infinity, alignment: .bottom)
                                .font(.system(size: 70))
                                .foregroundStyle(.white)
                        })
                    } else {
                        // Inside the 'else' block where the "Send" button is defined
                        Button(action: {
                            
                            makingNex = false
                            // Ensure images are captured before attempting to upload
                            if let frontImage = viewModel.frontCameraImage, let backImage = viewModel.backCameraImage {
                                // Invoke the upload process
                                viewModel.uploadImages(frontImage: frontImage, backImage: backImage) { result in
                                    switch result {
                                    case .success(let urls):
                                        // On success, create a Firestore document with the image URLs
                                        viewModel.createFirestoreDocument(frontImageURL: urls.front, backImageURL: urls.back)
                                        print("Both images uploaded and document created with URLs: \(urls)")
                                    case .failure(let error):
                                        // Handle any errors
                                        print("Error uploading images: \(error.localizedDescription)")
                                    }
                                }
                            } else {
                                print("One or both images not captured successfully.")
                            }
                        }, label: {
                            Text("Send").foregroundStyle(.white)
                        })
                        
                        
                        
                        
                        
                    }
                }
            }
            .onAppear {
                
                viewModel.userID = self.userID
                viewModel.myuserID = self.myuserID
                
                fetchDisplayName()
            }
        }else{
            VStack{
                Text("You have to allow Camera access before you are allowed to use this feature")
                    .font(.title)
                Image(systemName: "cross")
                    .foregroundColor(.red)
            }
            
        }
    }
    
    func fetchDisplayName() {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(userID)
        
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                self.displayName = data?["Display Name"] as? String ?? "🤔"
            } else {
                print("Document does not exist")
            }
        }
    }
}




import UIKit
import Firebase
import FirebaseStorage


class CreateNexViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var cameraPosition: AVCaptureDevice.Position?
    @Published var frontCameraImage: UIImage?
        @Published var backCameraImage: UIImage?
    
    
    var userID: String = ""
    var myuserID: String = ""

    
        
    
    
    func imageCaptured(_ image: UIImage, cameraPosition: AVCaptureDevice.Position) {
        DispatchQueue.main.async {
            if cameraPosition == .front {
                self.frontCameraImage = image
            } else {
                self.backCameraImage = image
            }
        }
    }


    
    func uploadImages(frontImage: UIImage, backImage: UIImage, completion: @escaping (Result<(front: String, back: String), Error>) -> Void) {
            // Create a dispatch group to manage multiple upload tasks
            let uploadGroup = DispatchGroup()
            
            var frontImageURL: String?
            var backImageURL: String?
            var uploadError: Error?
            
            // Start uploading the front image
            uploadGroup.enter()
            uploadImage(image: frontImage) { result in
                switch result {
                case .success(let url):
                    frontImageURL = url
                case .failure(let error):
                    uploadError = error
                }
                uploadGroup.leave()
            }
            
            // Start uploading the back image
            uploadGroup.enter()
            uploadImage(image: backImage) { result in
                switch result {
                case .success(let url):
                    backImageURL = url
                case .failure(let error):
                    uploadError = error
                }
                uploadGroup.leave()
            }
            
            // Once all uploads are done
            uploadGroup.notify(queue: .main) {
                if let uploadError = uploadError {
                    completion(.failure(uploadError))
                } else if let frontURL = frontImageURL, let backURL = backImageURL {
                    completion(.success((front: frontURL, back: backURL)))
                } else {
                    // Handle unexpected error
                    completion(.failure(NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unexpected error occurred."])))
                }
            }
        }

    
    func uploadImage(image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        let storageRef = Storage.storage().reference()
        let photoRef = storageRef.child("nexPhotos/\(UUID().uuidString).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            return
        }

        photoRef.putData(imageData, metadata: nil) { (metadata, error) in
            guard metadata != nil else {
                completion(.failure(error ?? NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image"])))
                return
            }

            photoRef.downloadURL { (url, error) in
                guard let downloadURL = url else {
                    completion(.failure(error ?? NSError(domain: "URLGenerationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }

                completion(.success(downloadURL.absoluteString))
            }
        }
    }
    
    func frontImageCaptured(_ image: UIImage) {
            DispatchQueue.main.async {
                self.frontCameraImage = image
            }
        }
        
        func backImageCaptured(_ image: UIImage) {
            DispatchQueue.main.async {
                self.backCameraImage = image
            }
        }

    func createFirestoreDocument(frontImageURL: String, backImageURL: String) {
        let db = Firestore.firestore()
        
        // Data to be saved for both sender and receiver
        let nexData = [
            "frontImageURL": frontImageURL,
            "backImageURL": backImageURL,
            "senderID": self.userID,
            "receiverID": self.myuserID,
            "timestamp": Timestamp(),
            "opened": false
        ] as [String : Any]
        
        // Reference to the sender's Nex directory
        let senderRef = db.collection("users").document(self.userID).collection("Nexes").document()
        // Reference to the receiver's Nex directory
        let receiverRef = db.collection("users").document(self.myuserID).collection("Nexes").document(senderRef.documentID) // Use the same document ID for both
        
        // Save the Nex data under both the sender's and receiver's Nex directories
        senderRef.setData(nexData) { error in
            if let error = error {
                print("Error writing document to sender's directory: \(error.localizedDescription)")
            } else {
                print("Document successfully written to sender's directory!")
            }
        }
        
        receiverRef.setData(nexData) { error in
            if let error = error {
                print("Error writing document to receiver's directory: \(error.localizedDescription)")
            } else {
                print("Document successfully written to receiver's directory!")
            }
        }
    }


    
}





import AVFoundation
import FirebaseFirestoreInternal


struct CameraFeedView: UIViewRepresentable {
    @Binding var tookPic: Bool // Bind to the state in SwiftUI view
    var viewModel: CreateNexViewModel
    
    func makeUIView(context: Context) -> CameraView {
        let cameraView = CameraView()
        cameraView.delegate = context.coordinator
        return cameraView
    }
    
    func updateUIView(_ uiView: CameraView, context: Context) {
        if tookPic {
            uiView.captureImage()
        }
    }
    
    func makeCoordinator() -> Coordinator {
            Coordinator(self, tookPic: $tookPic, viewModel: viewModel) // Pass the ViewModel to the Coordinator
        }
    
    class Coordinator: NSObject, CameraViewDelegate {
            var parent: CameraFeedView
            var tookPic: Binding<Bool>
            var viewModel: CreateNexViewModel // Hold a reference to the ViewModel

            init(_ parent: CameraFeedView, tookPic: Binding<Bool>, viewModel: CreateNexViewModel) {
                self.parent = parent
                self.tookPic = tookPic
                self.viewModel = viewModel
            }

        func didCaptureImage(_ image: UIImage, cameraPosition: AVCaptureDevice.Position) {
                    self.viewModel.imageCaptured(image, cameraPosition: cameraPosition)
                }
        }
}




protocol CameraViewDelegate: AnyObject {
    func didCaptureImage(_ image: UIImage, cameraPosition: AVCaptureDevice.Position)
}

class CameraView: UIView, AVCapturePhotoCaptureDelegate {
    private var multiCamSession: AVCaptureMultiCamSession?
    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var frontCameraPhotoOutput: AVCapturePhotoOutput?
    private var backCameraPhotoOutput: AVCapturePhotoOutput?
    private var isFrontCameraActive = true // Tracks which camera is currently active
    private var initialSmallCameraPosition: CGPoint?
    private var lastPiPPosition: CGPoint? = nil
    private let pipPadding: CGFloat = 10
    weak var delegate: CameraViewDelegate?

    private var isPreviewFrozen = false
    
    
    func resetCaptureFlags() {
        hasCapturedFrontCamera = false
        hasCapturedBackCamera = false
    }

    
    func captureImage(fromCameraPosition position: AVCaptureDevice.Position? = nil) {
        guard !isPreviewFrozen else { return } // Ensure we're not trying to capture while the preview is frozen

        let settings = AVCapturePhotoSettings()

        let photoOutput = position == .back ? backCameraPhotoOutput : (position == .front ? frontCameraPhotoOutput : (isFrontCameraActive ? frontCameraPhotoOutput : backCameraPhotoOutput))
        
        if let photoOutput = photoOutput {
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        guard let imageData = photo.fileDataRepresentation(), let image = UIImage(data: imageData) else {
            print("Could not get image data")
            return
        }

        let cameraPosition = output == frontCameraPhotoOutput ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back

        delegate?.didCaptureImage(image, cameraPosition: cameraPosition)

        if cameraPosition == .front {
            hasCapturedFrontCamera = true
            if hasCapturedBackCamera {
                freezePreview() // Freeze the preview if both cameras have captured images
            } else {
                toggleCamera(to: .back)
            }
        } else if cameraPosition == .back {
            hasCapturedBackCamera = true
            if hasCapturedFrontCamera {
                freezePreview() // Freeze the preview if both cameras have captured images
            } else {
                toggleCamera(to: .front)
            }
        }
    }

    private func freezePreview() {
        DispatchQueue.main.async {
            self.multiCamSession?.stopRunning() // Stop the session to freeze the preview
            self.isPreviewFrozen = true // Indicate that the preview is frozen
        }
    }

    // Ensure you have flags to track if each camera has been used for capture.
    var hasCapturedFrontCamera = false
    var hasCapturedBackCamera = false


    // Add a method to toggle between the front and back cameras
    private func toggleCamera(to position: AVCaptureDevice.Position) {
        // Set flags to avoid capturing more than once from each camera
        if position == .front {
            hasCapturedFrontCamera = true
        } else if position == .back {
            hasCapturedBackCamera = true
        }

        // Wait for a short duration before capturing from the newly activated camera to ensure the session is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.captureImage(fromCameraPosition: position)
        }
    }

    private func updatePreviewLayerSizes() {
        // Define the full size and PiP size for the preview layers
        let fullSize = bounds
        let pipSize = CGRect(x: bounds.maxX - 110, y: bounds.minY + 10, width: 100, height: 150)

        if isFrontCameraActive {
            // Set the front layer as the main preview
            frontPreviewLayer?.frame = fullSize
            backPreviewLayer?.frame = pipSize

            // Update zPositions to ensure the PiP layer is above the main preview
            frontPreviewLayer?.zPosition = 0
            backPreviewLayer?.zPosition = 1 // Ensure PiP is in the foreground
            
            // Remove corner radius from the PiP
            backPreviewLayer?.cornerRadius = 0
        } else {
            // Set the back layer as the main preview
            backPreviewLayer?.frame = fullSize
            frontPreviewLayer?.frame = pipSize

            // Update zPositions to ensure the PiP layer is above the main preview
            backPreviewLayer?.zPosition = 0
            frontPreviewLayer?.zPosition = 1 // Ensure PiP is in the foreground

            // Remove corner radius from the PiP
            frontPreviewLayer?.cornerRadius = 10
        }

        // Optionally, if you want to enforce a corner radius for the main preview (not PiP),
        // you can set it here based on which preview is active.
        // For simplicity and based on your requirement, this step is omitted.
    }



    
    
    func unfreezePreview() {
            guard isPreviewFrozen else { return }
            isPreviewFrozen = false
            multiCamSession?.startRunning()
        }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeSession()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeSession()
    }

    func initializeSession() {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("MultiCam not supported on this device")
            return
        }

        multiCamSession = AVCaptureMultiCamSession()
        multiCamSession?.beginConfiguration()

        let frontCamera = setupCameraSession(for: .front)
        let backCamera = setupCameraSession(for: .back)

        setupPhotoOutput(for: frontCamera, position: .front)
        setupPhotoOutput(for: backCamera, position: .back)

        multiCamSession?.commitConfiguration()
        multiCamSession?.startRunning()

        setupPreviewLayers()
        addPanGestureRecognizer()
        addTapGestureRecognizer()
    }

    private func setupCameraSession(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              multiCamSession?.canAddInput(videoInput) ?? false else {
            print("Unable to find or add camera for position \(position)")
            return nil
        }

        multiCamSession?.addInput(videoInput)
        return videoDevice
    }

    private func setupPhotoOutput(for camera: AVCaptureDevice?, position: AVCaptureDevice.Position) {
        guard camera != nil, let session = multiCamSession else { return }
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            if position == .front {
                frontCameraPhotoOutput = photoOutput
            } else {
                backCameraPhotoOutput = photoOutput
            }
        }
    }

    

    private func setupPreviewLayers() {
        guard let session = multiCamSession else { return }

        // Setup for the front camera preview layer
        frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer?.videoGravity = .resizeAspectFill
        frontPreviewLayer?.frame = bounds
        frontPreviewLayer?.cornerRadius = 10
        layer.addSublayer(frontPreviewLayer!)

        // Define a larger padding specifically for the PiP view
        let pipViewPadding: CGFloat = 20 // Larger padding for the PiP view

        // Setup for the back camera preview layer with initial larger padding for the PiP effect
        backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        backPreviewLayer?.videoGravity = .resizeAspectFill
        let backLayerInitialFrame = CGRect(x: bounds.maxX - 100 - pipViewPadding, y: bounds.minY + pipViewPadding, width: 100, height: 150)
        backPreviewLayer?.frame = backLayerInitialFrame
        backPreviewLayer?.cornerRadius = 10
        backPreviewLayer?.masksToBounds = true
        layer.addSublayer(backPreviewLayer!)

        // Initialize lastPiPPosition with the initial position of the back camera's preview layer
        // This allows for immediate toggling between views without first needing to drag the PiP view
        lastPiPPosition = CGPoint(x: bounds.maxX - 100 - pipViewPadding, y: bounds.minY + pipViewPadding)
    }







    private func addPanGestureRecognizer() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        self.isUserInteractionEnabled = true
        self.addGestureRecognizer(panGesture)
    }
    
    private func addTapGestureRecognizer() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        self.addGestureRecognizer(tapGesture)
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let layerToMove = isFrontCameraActive ? backPreviewLayer : frontPreviewLayer else { return }

        let location = gesture.location(in: self) // Get the current location of the gesture within the view.

        switch gesture.state {
        case .began:
            // Capture the starting position of the layer for potential use in later logic.
            initialSmallCameraPosition = layerToMove.frame.origin
        case .changed:
            // Directly update the layer's position based on the gesture's location, adjusting for the layer's size.
            let newOriginX = location.x - (layerToMove.frame.width / 2)
            let newOriginY = location.y - (layerToMove.frame.height / 2)
            layerToMove.frame.origin = CGPoint(x: newOriginX, y: newOriginY)
        case .ended:
            // On gesture end, snap the layer to the nearest corner.
            let finalPosition = nearestCorner(to: layerToMove.frame.origin)
            UIView.animate(withDuration: 0.3) {
                layerToMove.frame.origin = finalPosition
                // Update lastPiPPosition when the gesture ends and the position is finalized.
                self.lastPiPPosition = finalPosition
            }
        default:
            break
        }
    }


    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        let tapLocation = gesture.location(in: self)
        
        // Determine if the tap is within the PIP view's bounds
        let pipFrame = isFrontCameraActive ? backPreviewLayer?.frame : frontPreviewLayer?.frame
        if let pipFrame = pipFrame, pipFrame.contains(tapLocation) {
            toggleCameraView()
        }
    }

    private func toggleCameraView() {
        isFrontCameraActive.toggle()
        updatePreviewLayerPositions()
    }
    func captureImages() {
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            if isFrontCameraActive {
                frontCameraPhotoOutput?.capturePhoto(with: settings, delegate: self)
            } else {
                backCameraPhotoOutput?.capturePhoto(with: settings, delegate: self)
            }
        }

        

    
    private func updatePreviewLayerPositions() {
        guard let activeLayer = isFrontCameraActive ? frontPreviewLayer : backPreviewLayer,
              let inactiveLayer = isFrontCameraActive ? backPreviewLayer : frontPreviewLayer,
              let lastPiPPosition = self.lastPiPPosition else { return }

        let pipFrameSize = CGSize(width: 100, height: 150) // Size for the PiP frame
        let activeFrame = bounds.insetBy(dx: 5, dy: 5) // Apply slight padding for the active camera
        
        // Swap the zPositions of the preview layers to manage which one appears on top.
        activeLayer.zPosition = 0
        inactiveLayer.zPosition = 1

        UIView.animate(withDuration: 0.3) {
            // The previously active camera becomes the PiP view, positioned at the last known PiP position.
            inactiveLayer.frame = CGRect(origin: lastPiPPosition, size: pipFrameSize)
            // The new active camera fills the bounds of the CameraView, with slight padding.
            activeLayer.frame = activeFrame
        }
    }


    private func nearestCorner(to point: CGPoint) -> CGPoint {
        let corners = [
            CGPoint(x: bounds.maxX - 100 - pipPadding, y: bounds.minY + pipPadding), // Top right with padding
            CGPoint(x: bounds.minX + pipPadding, y: bounds.minY + pipPadding), // Top left with padding
            CGPoint(x: bounds.maxX - 100 - pipPadding, y: bounds.maxY - 150 - pipPadding), // Bottom right with padding
            CGPoint(x: bounds.minX + pipPadding, y: bounds.maxY - 150 - pipPadding) // Bottom left with padding
        ]

        let nearestCorner = corners.min(by: { distance(from: point, to: $0) < distance(from: point, to: $1) })!
        return nearestCorner
    }

    private func distance(from pointA: CGPoint, to pointB: CGPoint) -> CGFloat {
        return hypot(pointB.x - pointA.x, pointB.y - pointA.y)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Define padding for the main camera view
        let mainViewPadding: CGFloat = 5 // Smaller padding for the main camera view
        
        // Ensure the preview layer of the active camera has a slight padding
        let activeCameraFrame = bounds.insetBy(dx: mainViewPadding, dy: mainViewPadding)
        let pipCameraFrame = CGRect(x: bounds.maxX - 100 - pipPadding, y: bounds.minY + pipPadding, width: 100, height: 150)
        
        if isFrontCameraActive {
            frontPreviewLayer?.frame = activeCameraFrame // Apply slight padding for the active camera
            backPreviewLayer?.frame = pipCameraFrame // Apply specified padding for the PiP view
        } else {
            backPreviewLayer?.frame = activeCameraFrame // Apply slight padding for the active camera
            frontPreviewLayer?.frame = pipCameraFrame // Apply specified padding for the PiP view
        }
    }



    deinit {
        multiCamSession?.stopRunning()
    }
}

extension CameraView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition of pan and tap gestures
        return true
    }
}







#Preview {
    HomeView(userIdentifier: "001083.34bfd7f586ce42da997ff9b6c73103f2.2322")
}
