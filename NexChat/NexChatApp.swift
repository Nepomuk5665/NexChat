//
//  NexChatApp.swift
//  NexChat
//
//  Created by Nepomuk Crhonek on 02.01.2024.
//

import SwiftUI
import Firebase


@main
struct NexChatApp: App {
    @AppStorage("userID") var userID: String = ""
    @AppStorage("username") var username: String = ""
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            if userID.isEmpty || username.isEmpty {
                Startup()
            } else {
                HomeView(userIdentifier: userID)
            }
        }
        
    }
    
    

}


