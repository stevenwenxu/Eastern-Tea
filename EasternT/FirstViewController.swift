//
//  FirstViewController.swift
//  EasternT
//
//  Created by Steven Xu on 2016-09-16.
//  Copyright © 2016 EasternT. All rights reserved.
//

import Foundation
import UIKit
import Speech

protocol WriteValueBackDelegate : class {
    func writeValueBack(languageType: LanguageType)
}

class FirstViewController: UIViewController, SFSpeechRecognizerDelegate, WriteValueBackDelegate {

    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @IBOutlet weak var recordButtonA: UIButton!
    @IBOutlet weak var recordButtonB: UIButton!
    @IBOutlet weak var chooseLangButtonA: UIButton!
    @IBOutlet weak var chooseLangButtonB: UIButton!
    var languageTypeA: LanguageType = .english
    var languageTypeB: LanguageType = .chinese

    @IBOutlet weak var speechLabel: UILabel!
    
    var indexToggle : Int = 0
    let doge = UIImage(named: "doge")
    let normal = UIImage(named: "recordButton")

    var inputText = ""

    private var isRecordingInProgress = false {
        didSet {
            if (self.isRecordingInProgress) {
                self.recordButtonA.setImage(self.doge, for: .normal)
                self.recordButtonB.setImage(self.doge, for: .normal)
            } else {
                self.recordButtonA.setImage(self.normal, for: .normal)
                self.recordButtonB.setImage(self.normal, for: .normal)
            }
        }
    }

    let model = ETBrain()

    // MARK: - View Controller life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        TokenManager.sharedInstance.refreshToken()
        self.speechRecognizer.delegate = self
        self.requestPermission()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = segue.destination as? SelectLanguageViewController {
            if segue.identifier == "LanguageSelectionSegue2" {
                self.indexToggle = 1
            } else {
                self.indexToggle = 0
            }
            controller.delegate = self
        }
            }

    @IBAction func recordButtonTapped(sender: UIButton) {
        // QuickBlox Chat stuffs
        let chatManager = ChatManager()
        let user = QBUUser()
        user.externalUserID = 17850765
        user.password = "12345678"
        chatManager.connectUser(user: user)
        let user2 = QBUUser()
        user2.externalUserID = 17850786
        user2.password = "12345678"
        chatManager.connectUser(user: user2)

        chatManager.createChatDialogAndSendMessage(dialogName: "first", messageText: "fuck you", userIds: [17850765, 17850786])
        
        
        let isLeftButton = sender == self.recordButtonA
        let languageTypeFrom = (isLeftButton) ? self.languageTypeA : self.languageTypeB
        let languageTypeTo = (!isLeftButton) ? self.languageTypeA : self.languageTypeB
        
        if audioEngine.isRunning {
            self.audioEngine.stop()
            self.recognitionRequest?.endAudio()
            self.isRecordingInProgress = false
            NetworkManager.sharedInstance.getTranslate(originText: self.inputText, from: languageTypeFrom, to: languageTypeTo) { string in
                if let str = string {
                    self.model.textToSpeech(text: str, languageType: languageTypeTo)
                }
            }
        } else {
            do {
                speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: languageTypeStringMapB[languageTypeFrom]!))!
                speechRecognizer.delegate = self
                
                try self.startRecording()
                self.isRecordingInProgress = true
            } catch {
                NSLog("Got exception in startRecording: \(error)")
            }
        }
    }

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButtonA.isEnabled = true
                    self.recordButtonB.isEnabled = true

                default:
                    NSLog("Permission not right!!")
                    self.recordButtonA.isEnabled = false
                    self.recordButtonB.isEnabled = false
                }
            }
        }
    }

    func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = self.recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)

        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }

        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true

        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        self.recognitionTask = self.speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in

            var isFinal = false
            if let error = error {
                NSLog("Got error in recording: \(error)")
            }

            if let weakSelf = self, let result = result {
                weakSelf.inputText = result.bestTranscription.formattedString
                weakSelf.speechLabel.text = result.bestTranscription.formattedString
                isFinal = result.isFinal

                if error != nil || isFinal {
                    weakSelf.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    weakSelf.recognitionRequest = nil
                    weakSelf.recognitionTask = nil
                    weakSelf.isRecordingInProgress = false
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        self.audioEngine.prepare()
        try self.audioEngine.start()
        self.speechLabel.text = "(Go ahead, I'm listening)"
    }
    
    // MARK: - WriteValueBackDelegate
    
    func writeValueBack(languageType: LanguageType) {
        if 1 == self.indexToggle {
            self.chooseLangButtonA.setTitle(languageType.rawValue, for: .normal)
            self.languageTypeA = languageType
        } else {
            self.chooseLangButtonB.setTitle(languageType.rawValue, for: .normal)
            self.languageTypeB = languageType
        }
    }

    // MARK: - SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        self.recordButtonA.isEnabled = available
        self.recordButtonA.isEnabled = available
    }


}
