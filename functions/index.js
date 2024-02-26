const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendFriendRequestNotification = functions.firestore
    .document('friendRequests/{requestId}')
    .onCreate(async (snapshot, context) => {
        // Get the details of the friend request
        const friendRequest = snapshot.data();

        // Fetch the sender's user document to get the user's name
        const senderRef = admin.firestore().collection('users').doc(friendRequest.fromUserID);
        const senderDoc = await senderRef.get();

        if (!senderDoc.exists) {
            console.log('No such sender user!');
            return null;
        }

        const sender = senderDoc.data();
        const senderName = sender.username; // Assuming the user's name is stored in the 'username' field

        // Fetch the recipient's user document to get the FCM token
        const recipientRef = admin.firestore().collection('users').doc(friendRequest.toUserID);
        const recipientDoc = await recipientRef.get();

        if (!recipientDoc.exists) {
            console.log('No such recipient user!');
            return null;
        }

        const recipient = recipientDoc.data();

        // Check if the user has a FCM token
        if (!recipient.fcmToken) {
            console.log('No FCM token for user!');
            return null;
        }

        // Prepare a message for FCM
        const payload = {
            notification: {
                title: 'New Friend Request',
                body: `${senderName} sent you a friend request!`,
                // sound removed from here
            },
            token: recipient.fcmToken,
            apns: {
                payload: {
                    aps: {
                        sound: "rizz-sound-effect.wav"
                    }
                }
            }
        };

        // Send a message to the device corresponding to the provided FCM token
        try {
            const response = await admin.messaging().send(payload);
            console.log('Successfully sent message:', response);

            // Store notification reference in the database
            const notificationRef = admin.firestore().collection('notifications').doc();
            await notificationRef.set({
                userId: friendRequest.toUserID,
                requestId: context.params.requestId,
                notificationId: response.messageId, // or any unique identifier of the notification
                type: 'friendRequest'
            });

            return response;
        } catch (error) {
            console.error('Error sending message:', error);
            return null;
        }
    });








exports.sendFriendRequestAcceptedNotification = functions.firestore
    .document('friendRequests/{requestId}')
    .onUpdate(async (change, context) => {
        const friendRequestBefore = change.before.data();
        const friendRequestAfter = change.after.data();

        console.log(`Processing update for request: ${context.params.requestId}, From status: ${friendRequestBefore.status}, To status: ${friendRequestAfter.status}`);

        if (friendRequestBefore.status === 'pending' && friendRequestAfter.status === 'accepted') {
            console.log(`Friend request accepted, preparing to send notification...`);

            const senderRef = admin.firestore().collection('users').doc(friendRequestAfter.fromUserID);
            const senderDoc = await senderRef.get();

            if (!senderDoc.exists) {
                console.log('Sender user not found!');
                return;
            }

            const sender = senderDoc.data();
            if (!sender.fcmToken) {
                console.log(`Sender FCM token not found for user: ${friendRequestAfter.fromUserID}`);
                return;
            }

            const recipientRef = admin.firestore().collection('users').doc(friendRequestAfter.toUserID);
            const recipientDoc = await recipientRef.get();
            if (!recipientDoc.exists) {
                console.log('Recipient user not found!');
                return;
            }

            const recipient = recipientDoc.data();
            const recipientName = recipient.username || 'Unknown User';
            console.log(`Sending notification to: ${friendRequestAfter.fromUserID}, Recipient: ${recipientName}`);

            const payload = {
                notification: {
                    title: 'Friend Request Accepted',
                    body: `${recipientName} accepted your friend request!`,
                },
                token: sender.fcmToken,
                apns: {
                    payload: {
                        aps: {
                            sound: "rizz-sound-effect.wav"
                        }
                    }
                }
            };

            try {
                const response = await admin.messaging().send(payload);
                console.log(`Notification sent, Message ID: ${response.messageId}`);

                await admin.firestore().collection('friendRequests').doc(context.params.requestId).update({
                    notified: true
                });
                console.log(`Friend request marked as notified: ${context.params.requestId}`);

                return response;
            } catch (error) {
                console.error(`Error sending notification: `, error);
                return null;
            }
        } else {
            console.log(`Friend request status not updated from 'pending' to 'accepted' or already notified. Current status: ${friendRequestAfter.status}`);
        }
        return null;
    });












exports.sendChatMessageNotification = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
        const message = snapshot.data();
        
        const senderId = message.sender_id;
        const recipientId = message.receiver_id;

        if (!senderId || !recipientId) {
            console.log(`Invalid senderId (${senderId}) or recipientId (${recipientId}).`);
            return null;
        }

        const senderRef = admin.firestore().collection('users').doc(senderId);
        const senderDoc = await senderRef.get();
        if (!senderDoc.exists) {
            console.log('No such sender user!');
            return null;
        }

        const sender = senderDoc.data();
        const senderName = sender.username; // Assuming the user's name is stored in the 'username' field

        const recipientRef = admin.firestore().collection('users').doc(recipientId);
        const recipientDoc = await recipientRef.get();
        if (!recipientDoc.exists) {
            console.log('No such recipient user!');
            return null;
        }

        const recipient = recipientDoc.data();
        if (!recipient.fcmToken) {
            console.log('No FCM token for recipient!');
            return null;
        }

        const payload = {
            notification: {
                title: 'New Chat Message',
                body: `${senderName} sent you a chat!`,
            },
            token: recipient.fcmToken,
            android: {
                notification: {
                    sound: "rizz-sound-effect.wav"
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: "rizz-sound-effect.wav"
                    }
                }
            }
        };

        try {
            const response = await admin.messaging().send(payload);
            console.log('Successfully sent message:', response);
            return response;
        } catch (error) {
            console.error('Error sending message:', error);
            return null;
        }
    });





exports.sendTypingNotification = functions.firestore
    .document('typingIndicators/{chatId}')
    .onWrite(async (change, context) => {
        const chatId = context.params.chatId;
        const typingIndicator = change.after.data();
        const senderId = typingIndicator.senderID;
        const recipientId = typingIndicator.receiverID;
        const isTyping = typingIndicator.isTyping;

        if (!senderId || !recipientId || !isTyping) {
            console.log(`Either senderId, recipientId is missing, or isTyping is false.`);
            return null;
        }

        // Fetch the last typing notification timestamp
        const typingNotificationRef = admin.firestore().collection('typingNotifications').doc(chatId);
        const typingNotificationDoc = await typingNotificationRef.get();
        const lastNotificationTime = typingNotificationDoc.exists ? typingNotificationDoc.data().lastNotificationTime : null;

        // Check if the cooldown period has passed
        const now = admin.firestore.Timestamp.now();
        const cooldownPeriodInSeconds = 30; // e.g., 30 seconds
        if (lastNotificationTime && now.seconds - lastNotificationTime.seconds < cooldownPeriodInSeconds) {
            console.log('Cooldown period has not passed yet.');
            return null;
        }

        // Fetch sender and recipient information
        const senderRef = admin.firestore().collection('users').doc(senderId);
        const senderDoc = await senderRef.get();
        if (!senderDoc.exists) {
            console.log('No such sender user!');
            return null;
        }

        const sender = senderDoc.data();
        const senderName = sender.username;

        const recipientRef = admin.firestore().collection('users').doc(recipientId);
        const recipientDoc = await recipientRef.get();
        if (!recipientDoc.exists) {
            console.log('No such recipient user!');
            return null;
        }

        const recipient = recipientDoc.data();
        if (!recipient.fcmToken) {
            console.log('No FCM token for recipient!');
            return null;
        }

        // Prepare the notification payload
        const payload = {
            notification: {
                title: `${senderName} is typing...`,
                body: ''
            },
            token: recipient.fcmToken,
            android: {
                notification: {
                    sound: "rizz-sound-effect.wav"
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: "rizz-sound-effect.wav"
                    }
                }
            }
        };

        // Send the notification
        try {
            const response = await admin.messaging().send(payload);
            console.log('Successfully sent typing notification:', response);

            // Update the last notification time
            await typingNotificationRef.set({ lastNotificationTime: now }, { merge: true });

            return response;
        } catch (error) {
            console.error('Error sending typing notification:', error);
            return null;
        }
    });