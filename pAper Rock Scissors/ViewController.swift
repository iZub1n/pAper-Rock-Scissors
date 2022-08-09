//
//  ViewController.swift
//  pAper Rock Scissors
//
//  Created by Zubin Singh on 8/8/22.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var computerMove = Int.random(in: 1..<4)
    
    var gameOn = true
    
    var playerCount = 0
    
    var computerCount = 0
    
    var objArray = [SCNNode]()
    
    var sceneController = MainScene()
    
    let handPoseModel = handPoseImageClassifier().model
    
    let serialQueue = DispatchQueue(label: "com.iZub1n.dispactchqueuem1")
    
    private var visionRequests = [VNRequest]()
    
    private var timer = Timer()
    
    
    @IBAction func RefreshButtonPressed(_ sender: UIBarButtonItem) {
        clearScene()
        computerCount = 0
        playerCount = 0
        computerMove = Int.random(in: 1..<4)
        gameOn = true
    }
    
    @IBAction func NextRoundButtonPressed(_ sender: UIBarButtonItem) {
        clearScene()
        computerMove = Int.random(in: 1..<4)
        gameOn = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        if let scene = sceneController.scene {
          // Set the scene to the view
          sceneView.scene = scene
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        configuration.planeDetection = .horizontal
               
        // Run the view's session
        sceneView.session.run(configuration)
       
        setupCoreML()

        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.loopCoreMLUpdate), userInfo: nil, repeats: true)
          
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Core ML Functiona
    
    private func setupCoreML() {
            guard let selectedModel = try? VNCoreMLModel(for: handPoseModel) else {
                fatalError("Could not load model.")
            }
            
            let classificationRequest = VNCoreMLRequest(model: selectedModel,
                                                        completionHandler: classificationCompleteHandler)
            classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
            visionRequests = [classificationRequest]
        }
    
    @objc private func loopCoreMLUpdate() {
          serialQueue.async {
              self.updateCoreML()
          }
      }

    // MARK: - ARSCNViewDelegate
}

extension ViewController {
    private func updateCoreML() {
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        
        let deviceOrientation = UIDevice.current.orientation.getImagePropertyOrientation()
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixbuff!, orientation: deviceOrientation,options: [:])
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }
    
    private func classificationCompleteHandler(request: VNRequest, error: Error?) {
            if error != nil {
                print("Error: " + (error?.localizedDescription)!)
                return
            }
            guard let observations = request.results else {
                return
            }
            
        if gameOn{
            let classifications = observations[0...2]
                .compactMap({ $0 as? VNClassificationObservation })
                .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
                .joined(separator: "\n")
            
            print("Classifications: \(classifications)")
            
        DispatchQueue.main.async { [self] in
                let topPrediction = classifications.components(separatedBy: "\n")[0]
                let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
                guard let topPredictionScore: Float = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces)) else { return }
                
                if (topPredictionScore > 0.95) {
                    print("Top prediction: \(topPredictionName) - score: \(String(describing: topPredictionScore))")
                    
                    self.clearScene()
                    
                    if computerMove == 1{
                        self.displayRock()
                    }
                    else if computerMove == 2{
                        self.displayPaper()
                    }
                    else{
                        self.displayScissors()
                    }
                    
                    let currMove = self.getMoveNum(topPredictionName)
                    
                    self.determineMoveResult(currMove)
                    
                    self.updateScoreUI()
                    
                    gameOn = false
                    
                }
                    
                }
            }
        }
    
    func updateScoreUI(){
        let scoreCard = "You: \(playerCount) || Bot: \(computerCount)"
        self.navigationItem.title = scoreCard
    }
    
    func getMoveNum(_ move: String) -> Int{
        if move == "Rock"{
            return 1
        }
        else if move == "Paper"{
            return 2
        }
        return 3
        
    }
    
    func determineMoveResult(_ playerMove: Int){
        if playerMove != computerMove{
            if playerMove == 1 && computerMove == 2{
                computerCount+=1
            }
            else if playerMove == 1 && computerMove == 3{
                playerCount+=1
            }
            else if playerMove == 2 && computerMove == 1{
                playerCount+=1
            }
            else if playerMove == 2 && computerMove == 3{
                computerCount+=1
            }
            else if playerMove == 3 && computerMove == 1{
                computerCount+=1
            }
            else if playerMove == 3 && computerMove == 2{
                playerCount+=1
            }
        }
    }
    
    func clearScene(){
        if !objArray.isEmpty{
            for obj in objArray{
                obj.removeFromParentNode()
            }
        }
    }
    
    func displayRock() {
        let rockScene = SCNSphere(radius: 0.05)
        
        rockScene.firstMaterial?.diffuse.contents = UIColor.brown
        
        let rockNode = SCNNode(geometry: rockScene)
        
        rockNode.position = SCNVector3(x: 0, y: 0, z: -0.5)
        
        objArray.append(rockNode)
        
        sceneView.scene.rootNode.addChildNode(rockNode)
    }
    
    func displayPaper() {
        let paperScene = SCNPlane(width: 0.05, height: 0.05)
        
        paperScene.firstMaterial?.diffuse.contents = UIColor.white
        
        let paperNode = SCNNode(geometry: paperScene)
        
        paperNode.position = SCNVector3(x: 0, y: 0, z: -0.5)
        
        objArray.append(paperNode)
        
        sceneView.scene.rootNode.addChildNode(paperNode)
    }
    
    func displayScissors() {
        let scissorsScene = SCNCone(topRadius: 0.03, bottomRadius: 0, height: 0.07)
        
        scissorsScene.firstMaterial?.diffuse.contents = UIColor.blue
        
        let scissorsNode = SCNNode(geometry: scissorsScene)
        
        scissorsNode.position = SCNVector3(x: 0, y: 0, z: -0.5)
        
        objArray.append(scissorsNode)
        
        sceneView.scene.rootNode.addChildNode(scissorsNode)
    }

}

extension UIDeviceOrientation {
    func getImagePropertyOrientation() -> CGImagePropertyOrientation {
        switch self {
        case UIDeviceOrientation.portrait, .faceUp: return CGImagePropertyOrientation.right
        case UIDeviceOrientation.portraitUpsideDown, .faceDown: return CGImagePropertyOrientation.left
        case UIDeviceOrientation.landscapeLeft: return CGImagePropertyOrientation.up
        case UIDeviceOrientation.landscapeRight: return CGImagePropertyOrientation.down
        case UIDeviceOrientation.unknown: return CGImagePropertyOrientation.right
        }
    }
}
