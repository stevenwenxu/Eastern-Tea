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
    var selectedChooseLangBtn: UIButton!
    var selectedRecordButton: UIButton!
    @IBOutlet var selectLanguageContainerBottom: NSLayoutConstraint!
    @IBOutlet weak var selectLanguageContainer: UIView!

    var languageTypeA: LanguageType = .english
    var languageTypeB: LanguageType = .chinese

    @IBOutlet weak var speechLabel: UILabel!
    
    let normal = UIImage(named: "recordButton")
    var waveImages = [UIImage]()
//    let chatManager = ChatManager()
    var userId : UInt = 0
    
    var inputText = ""

    private var isRecordingInProgress = false {
        didSet {
            if (self.isRecordingInProgress) {
                self.selectedRecordButton.setImage(UIImage(named: "tmp-1"), for: .normal)
                self.selectedRecordButton.imageView?.animationImages = self.waveImages
                self.selectedRecordButton.imageView?.animationDuration = 0
                self.selectedRecordButton.imageView?.startAnimating()
            } else {
                self.selectedRecordButton.imageView?.stopAnimating()
                self.selectedRecordButton.setImage(self.normal, for: .normal)
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

        for i in 0...40 {
            self.waveImages.append(UIImage(named: "tmp-\(i)")!)
        }
    }

    @IBAction func recordButtonTapped(sender: UIButton) {
        // QuickBlox Chat stuffs

        self.selectedRecordButton = sender
        let isLeftButton = sender == self.recordButtonA
        let languageTypeFrom = (isLeftButton) ? self.languageTypeA : self.languageTypeB
        let languageTypeTo = (!isLeftButton) ? self.languageTypeA : self.languageTypeB
        
        if audioEngine.isRunning || self.isRecordingInProgress {
            self.audioEngine.stop()
            self.recognitionRequest?.endAudio()
            audioEngine.inputNode?.removeTap(onBus: 0)
            self.isRecordingInProgress = false
            NetworkManager.sharedInstance.getTranslate(originText: self.inputText, from: languageTypeFrom, to: languageTypeTo) { string in
                if let str = string {
                    self.model.textToSpeech(text: str, languageType: languageTypeTo)
                    let manager = SocketIOManger()
                    manager.getConnected()

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

    @IBAction func languageButtonDidTap(_ sender: UIButton) {
        UIView.animate(withDuration: 0.5) {
            self.selectLanguageContainerBottom.constant = 0
            self.view.layoutIfNeeded()
        }
        self.selectedChooseLangBtn = sender
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "selectLanguageSegue") {
            let selectLanguageVC = segue.destination as! SelectLanguageViewController
            selectLanguageVC.delegate = self
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
            } else {
                if let weakSelf = self {
                    weakSelf.inputText = "Oops there's an error"
                    weakSelf.speechLabel.text = "Oops there's an error"
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
        UIView.animate(withDuration: 0.5) {
            self.selectedChooseLangBtn?.setTitle(languageType.rawValue, for: .normal)
            self.selectLanguageContainerBottom.constant = -250
            self.view.layoutIfNeeded()
        }

        if self.chooseLangButtonA == self.selectedChooseLangBtn {
            self.languageTypeA = languageType
        } else {
            self.languageTypeB = languageType
        }
    }

    // MARK: - SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        self.recordButtonA.isEnabled = available
        self.recordButtonB.isEnabled = available
    }


}
