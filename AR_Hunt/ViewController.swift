//
//  Created by 张嘉夫 on 16/12/29.
//  Copyright © 2016年 张嘉夫. All rights reserved.
//
import UIKit
import SceneKit
import AVFoundation
import CoreLocation

protocol ViewControllerDelegate {
  func viewController(controller: ViewController, tappedTarget: ARItem)
}

class ViewController: UIViewController {
  
  @IBOutlet weak var sceneView: SCNView!
  @IBOutlet weak var leftIndicator: UILabel!
  @IBOutlet weak var rightIndicator: UILabel!
  var cameraSession: AVCaptureSession?
  var cameraLayer: AVCaptureVideoPreviewLayer?
  var target: ARItem!
  var locationManger = CLLocationManager()
  var heading: Double = 0
  var userLocation = CLLocation()
  var delegate: ViewControllerDelegate?
  
  let scene = SCNScene()
  let cameraNode = SCNNode()
  let targetNode = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0))
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    loadCamera()
    self.cameraSession?.startRunning()
    self.locationManger.delegate = self
    self.locationManger.startUpdatingHeading()
    
    sceneView.scene = scene
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(x: 0, y: 0, z: 10)
    scene.rootNode.addChildNode(cameraNode)
    setupTarget()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func createCaptureSession() -> (session: AVCaptureSession?, error: NSError?) {
    var error: NSError?
    var captureSession: AVCaptureSession?
    
    let backVideoDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back)
    
    if backVideoDevice != nil {
      var videoInput: AVCaptureDeviceInput!
      do {
        videoInput = try AVCaptureDeviceInput(device: backVideoDevice)
      } catch let error1 as NSError {
        error = error1
        videoInput = nil
      }
      
      if error == nil {
        captureSession = AVCaptureSession()
        
        if captureSession!.canAddInput(videoInput) {
          captureSession!.addInput(videoInput)
        } else {
          error = NSError(domain: "", code: 0, userInfo: ["description": "Error adding video input."])
        }
      } else {
        error = NSError(domain: "", code: 1, userInfo: ["description": "Error creating capture device input."])
      }
    } else {
      error = NSError(domain: "", code: 2, userInfo: ["description": "Back video device not found."])
    }
    
    return (session: captureSession, error: error)
  }
  
  func loadCamera() {
    let captureSessionResult = createCaptureSession()
    
    guard captureSessionResult.error == nil, let session = captureSessionResult.session else {
      print("Error creating capture session")
      return
    }
    
    self.cameraSession = session
    
    if let cameraLayer = AVCaptureVideoPreviewLayer(session: self.cameraSession) {
      cameraLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
      cameraLayer.frame = self.view.bounds
      self.view.layer.insertSublayer(cameraLayer, at: 0)
      self.cameraLayer = cameraLayer
    }
  }
  
  func repositionTarget() {
    let heading = getHeadingForDirectionFromCoordinate(from: userLocation, to: target.location)
    
    let delta = heading - self.heading
    
    if delta < -15.0 {
      leftIndicator.isHidden = false
      rightIndicator.isHidden = true
    } else if delta > 15 {
      leftIndicator.isHidden = true
      rightIndicator.isHidden = false
    } else {
      leftIndicator.isHidden = true
      rightIndicator.isHidden = true
    }
    
    let distance = userLocation.distance(from: target.location)
    
    if let node = target.itemNode {
      if node.parent == nil {
        node.position = SCNVector3(x: Float(delta), y: 0, z: Float(-distance))
        scene.rootNode.addChildNode(node)
      } else {
        node.removeAllActions()
        node.runAction(SCNAction.move(to: SCNVector3(x: Float(delta), y: 0, z: Float(-distance)), duration: 0.2))
      }
    }
  }
  
  func radiansToDegrees(_ radians: Double) -> Double {
    return (radians) * (180.0 / M_PI)
  }
  
  func degreesToRadians(_ degrees: Double) -> Double {
    return (degrees) * (M_PI / 180.0)
  }
  
  func getHeadingForDirectionFromCoordinate(from: CLLocation, to: CLLocation) -> Double {
    let fLat = degreesToRadians(from.coordinate.latitude)
    let fLng = degreesToRadians(from.coordinate.longitude)
    let tLat = degreesToRadians(to.coordinate.latitude)
    let tLng = degreesToRadians(to.coordinate.longitude)
    
    let degree = radiansToDegrees(atan2(sin(tLng-fLng)*cos(tLat), cos(fLat)*sin(tLat)-sin(fLat)*cos(tLat)*cos(tLng-fLng)))
    
    if degree >= 0 {
      return degree
    } else {
      return degree + 360
    }
  }

  func setupTarget() {
    let scene = SCNScene(named: "art.scnassets/\(target.itemDescription).dae")
    let enemy = scene?.rootNode.childNode(withName: target.itemDescription, recursively: true)
    
    if target.itemDescription == "dragon" {
      enemy?.position = SCNVector3(x: 0, y: -15, z: 0)
    } else {
      enemy?.position = SCNVector3(x: 0, y: 0, z: 0)
    }
    
    let node = SCNNode()
    node.addChildNode(enemy!)
    node.name = "enemy"
    self.target.itemNode = node
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    //1
    let touch = touches.first!
    let location = touch.location(in: sceneView)
    let hitResult = sceneView.hitTest(location, options: nil)
    let fireBall = SCNParticleSystem(named: "Fireball.scnp", inDirectory: nil)
    
    let emitterNode = SCNNode()
    emitterNode.position = SCNVector3(x: 0, y: -5, z: 10)
    emitterNode.addParticleSystem(fireBall!)
    scene.rootNode.addChildNode(emitterNode)
    
    if hitResult.first != nil {
      target.itemNode?.runAction(SCNAction.sequence([SCNAction.wait(duration: 0.5), SCNAction.removeFromParentNode(), SCNAction.hide()]))
      let sequence = SCNAction.sequence(
        [SCNAction.move(to: target.itemNode!.position, duration: 0.5),
          SCNAction.wait(duration: 3.5),
          SCNAction.run({_ in
            self.delegate?.viewController(controller: self, tappedTarget: self.target)
          })])
      emitterNode.runAction(sequence)
    } else {
      emitterNode.runAction(SCNAction.move(to: SCNVector3(x: 0, y: 0, z: -30), duration: 0.5))
    }
  }
}

extension ViewController: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    self.heading = fmod(newHeading.trueHeading, 360.0)
    repositionTarget()
  }
}
