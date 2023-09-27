//
//  ContentView.swift
//  ARApp
//
//  Created by Mridang Sheth on 10/15/22.
//

import SwiftUI
import RealityKit
import ARKit
import AVFoundation

struct ContentView : View {
    @State var sceneDepthStr: String
    var body: some View {
        ZStack {
            ARViewContainer(sceneDepthStr: $sceneDepthStr).edgesIgnoringSafeArea(.all)
            VStack {
                Text("Distance: \(self.sceneDepthStr) cm")
                    .background(Color.gray.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding()
                    .font(.title)
                    .bold()
                Spacer()
            }
            
            Button(
                action: {
                    Speaker.sharedInstance.speak(text: "Stop touching me.")
                    print("Picture taken")
                }
            ) {
                Text("Take a Picture").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    
}

struct ARViewContainer: UIViewRepresentable {
    
    @Binding var sceneDepthStr: String
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
        
        // Start AR session
        let session = arView.session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics = .smoothedSceneDepth
        } else {
            // TODO: Raise Error
        }
        session.delegate = context.coordinator
        session.run(config)

        // Add coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        coachingOverlay.session = session
        coachingOverlay.goal = .horizontalPlane
        arView.addSubview(coachingOverlay)
        
        
        
        return arView
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(sceneDepthStr: $sceneDepthStr)
    }
    
    class Coordinator: NSObject, ARSessionDelegate, AVAudioPlayerDelegate {
        @Binding var sceneDepthStr: String
        var  isAudioPlaying: Bool = false
        var readDistance: Bool = false
        
        var audioPlayer: AVAudioPlayer!
        
        var repeatFreq:Float = 5.0
        
        init(sceneDepthStr: Binding<String>) {
            _sceneDepthStr = sceneDepthStr
            
            let beepFile = URL(filePath: Bundle.main.path(forResource: "beep", ofType: "m4a")!)
            audioPlayer =  try? AVAudioPlayer(contentsOf: beepFile)
            super.init()
            audioPlayer.delegate = self
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if let sceneDepth = frame.smoothedSceneDepth {
                let depthData = sceneDepth.depthMap
                let depthWidth = CVPixelBufferGetWidth(depthData) // 256
                let depthHeight = CVPixelBufferGetHeight(depthData) // 192
                
                CVPixelBufferLockBaseAddress(depthData, CVPixelBufferLockFlags(rawValue: 0))
                let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(depthData), to: UnsafeMutablePointer<Float32>.self)
                var minDist: Float32 = 1000000
                for x in 71...121 { //width (0 to 192-1)
                    for y in 103...178 { //height (0 to 256-1)
                        let distXY = floatBuffer[x * depthWidth + y]
                        if minDist > distXY {
                            minDist = distXY
                        }
                    }
                }
                let roundedDist = round(minDist * 100) / 100.0
                DispatchQueue.main.async { [weak self] in
                    self?.sceneDepthStr = "\(Int(roundedDist * 100))"
                    var repeatFreq: Float = 0
                    if roundedDist <= 1 {
                        if !self!.readDistance {
                            self?.readDistance = true
                            Speaker.sharedInstance.speak(text: "Object 3 feet ahead")
                        }
                        repeatFreq = roundedDist * 3
                        if roundedDist < 0.25 {
                            repeatFreq *= 1/5
                        } else if roundedDist < 0.5 {
                            repeatFreq *= 1/2
                        }
                        self?.repeatFreq = repeatFreq
                        
                        if !self!.isAudioPlaying {
                            self?.isAudioPlaying = true
                            self?.audioPlayer.prepareToPlay()
                            self?.playBeep()
                        }
                    } else {
                        if self!.readDistance {
                            self?.readDistance = false
                        }
                        if self!.isAudioPlaying {
                            self?.isAudioPlaying = false
                            self?.audioPlayer.stop()
                        }
                    }
                }
            }
        }
        
        
        @objc func playBeep() {
            audioPlayer.play()
        }
        
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            if isAudioPlaying {
                self.perform(#selector(playBeep), with: nil, afterDelay: Double(self.repeatFreq))
            }
        }
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}


#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView(sceneDepthStr: "")
    }
}
#endif


class Speaker {
    static let sharedInstance = Speaker()
    let speechSynthesizer = AVSpeechSynthesizer()
    
    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.pitchMultiplier = 1.0
        utterance.rate = 0.6
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
}
