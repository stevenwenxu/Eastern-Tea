//
//  ChatManager.swift
//  EasternT
//
//  Created by Calvin Zhou on 2016-09-17.
//  Copyright © 2016 EasternT. All rights reserved.
//

import Foundation
import Quickblox

class ChatManager : NSObject, QBChatDelegate {
    
    func signupAndLoginUser(userLogin: String, password:String) ->Void {
        let user = QBUUser()
        user.login = userLogin
        user.password = password
//        QBRequest.signUp(user, successBlock: <#T##((QBResponse, QBUUser?) -> Void)?##((QBResponse, QBUUser?) -> Void)?##(QBResponse, QBUUser?) -> Void#>, errorBlock: <#T##QBRequestErrorBlock?##QBRequestErrorBlock?##(QBResponse) -> Void#>)
        QBRequest.logIn(withUserLogin: userLogin, password: password, successBlock: { (repsonse, user) in
            print("succeed")
            }) { (response) in
                print("failed")
        }
    }

    
    func connectUser(user:QBUUser) -> Void {
        QBChat.instance().connect(with: user) { (error) in
            print("wtf?? " + error.debugDescription)
        }

    }
    
    func createChatDialogAndSendMessage(dialogName: String, messageText: String, userIds: [NSNumber])->Void {
        let privateChatDialog = QBChatDialog(dialogID: nil, type: QBChatDialogType.private)
        privateChatDialog.name = dialogName
        privateChatDialog.occupantIDs = userIds
        QBRequest.createDialog(privateChatDialog, successBlock: { (response: QBResponse?, createdDialog : QBChatDialog?) -> Void in
            print("fuck yell")
        }) { (responce : QBResponse!) -> Void in
            
        }
        
        QBChat.instance().addDelegate(self)

        let message: QBChatMessage = QBChatMessage()
        message.text = messageText
        let params : NSMutableDictionary = NSMutableDictionary()
        params["save_to_history"] = true
        message.customParameters = params
        
        privateChatDialog.send(message, completionBlock: { (error) in
            print("Sending message" + message.text!)
        });
    }
    
    func chatDidReceiveMessage(message: QBChatMessage!) {
        print("You got the message" + message.text!)
    }
}
    
