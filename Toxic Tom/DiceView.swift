//
//  DiceView.swift
//  Toxic Tom
//
//  Dice rolling animation prototype using SceneKit
//

import SwiftUI
import SceneKit

// MARK: - SceneKit Dice View (UIViewRepresentable wrapper)

struct DiceSceneView: UIViewRepresentable {
    @Binding var shouldRoll: Bool
    @Binding var isRolling: Bool
    @Binding var result: Int?
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.scene
        sceneView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
        sceneView.antialiasingMode = .multisampling4X
        sceneView.autoenablesDefaultLighting = false
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        if shouldRoll && !isRolling {
            DispatchQueue.main.async {
                self.isRolling = true
                self.shouldRoll = false
            }
            context.coordinator.rollDice { finalResult in
                DispatchQueue.main.async {
                    self.result = finalResult
                    self.isRolling = false
                }
            }
        }
    }
    
    func makeCoordinator() -> DiceCoordinator {
        DiceCoordinator()
    }
}

// MARK: - Dice Coordinator (Manages the SceneKit scene)

class DiceCoordinator: NSObject {
    let scene = SCNScene()
    var diceNode: SCNNode!
    var checkTimer: Timer?
    
    override init() {
        super.init()
        setupScene()
    }
    
    private func setupScene() {
        // MARK: Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 45
        cameraNode.position = SCNVector3(0, 8, 12)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // MARK: Lighting - Dramatic single source (Nordic style)
        
        // Key light - warm, dramatic
        let keyLight = SCNLight()
        keyLight.type = .spot
        keyLight.intensity = 1200
        keyLight.color = UIColor(red: 1.0, green: 0.95, blue: 0.9, alpha: 1.0)
        keyLight.castsShadow = true
        keyLight.shadowRadius = 8
        keyLight.shadowColor = UIColor.black.withAlphaComponent(0.6)
        keyLight.spotInnerAngle = 30
        keyLight.spotOuterAngle = 60
        
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(3, 10, 5)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)
        
        // Fill light - subtle, cool
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 200
        fillLight.color = UIColor(red: 0.8, green: 0.85, blue: 1.0, alpha: 1.0)
        
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-5, 4, 3)
        scene.rootNode.addChildNode(fillLightNode)
        
        // Ambient - very subtle
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 100
        ambientLight.color = UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1.0)
        
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // MARK: Floor - dark slate
        let floor = SCNFloor()
        floor.reflectivity = 0.15
        floor.firstMaterial?.diffuse.contents = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
        floor.firstMaterial?.roughness.contents = 0.7
        
        let floorNode = SCNNode(geometry: floor)
        floorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floorNode.physicsBody?.friction = 0.8
        floorNode.physicsBody?.restitution = 0.3
        scene.rootNode.addChildNode(floorNode)
        
        // MARK: Invisible walls to keep dice in view
        addInvisibleWall(at: SCNVector3(0, 2, -4), size: SCNVector3(10, 5, 0.5))  // Back
        addInvisibleWall(at: SCNVector3(-5, 2, 0), size: SCNVector3(0.5, 5, 10))  // Left
        addInvisibleWall(at: SCNVector3(5, 2, 0), size: SCNVector3(0.5, 5, 10))   // Right
        addInvisibleWall(at: SCNVector3(0, 2, 6), size: SCNVector3(10, 5, 0.5))   // Front
        
        // MARK: Dice
        diceNode = createDice()
        diceNode.position = SCNVector3(0, 3, 0)
        scene.rootNode.addChildNode(diceNode)
    }
    
    private func addInvisibleWall(at position: SCNVector3, size: SCNVector3) {
        let wall = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0)
        wall.firstMaterial?.transparency = 0
        
        let wallNode = SCNNode(geometry: wall)
        wallNode.position = position
        wallNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        wallNode.physicsBody?.friction = 0.5
        wallNode.physicsBody?.restitution = 0.6
        scene.rootNode.addChildNode(wallNode)
    }
    
    private func createDice() -> SCNNode {
        // Create a cube with slight chamfer for realistic dice look
        let box = SCNBox(width: 1.5, height: 1.5, length: 1.5, chamferRadius: 0.12)
        
        // Create materials for each face (bone/ivory colored - Nordic minimalist)
        // Order: front, right, back, left, top, bottom
        // Standard dice: opposite faces sum to 7 (1-6, 2-5, 3-4)
        let faces = [1, 3, 6, 4, 2, 5] // front, right, back, left, top, bottom
        
        var materials: [SCNMaterial] = []
        for faceValue in faces {
            let material = createDiceFaceMaterial(value: faceValue)
            materials.append(material)
        }
        
        box.materials = materials
        
        let diceNode = SCNNode(geometry: box)
        
        // Physics
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: box, options: nil))
        physicsBody.mass = 1.0
        physicsBody.friction = 0.6
        physicsBody.restitution = 0.4  // Bounce
        physicsBody.angularDamping = 0.3
        physicsBody.linearDamping = 0.1
        diceNode.physicsBody = physicsBody
        
        return diceNode
    }
    
    private func createDiceFaceMaterial(value: Int) -> SCNMaterial {
        let material = SCNMaterial()
        
        // Base color - bone/ivory
        material.diffuse.contents = UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0)
        material.roughness.contents = 0.4
        material.metalness.contents = 0.0
        
        // Create texture with dots for the dice face
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let image = renderer.image { context in
            // Background
            UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Dots - dark charcoal color
            UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).setFill()
            
            let dotRadius: CGFloat = 16
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let offset: CGFloat = 55
            
            // Draw dots based on value
            switch value {
            case 1:
                drawDot(in: context.cgContext, at: center, radius: dotRadius)
            case 2:
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y - offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y + offset), radius: dotRadius)
            case 3:
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y - offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: center, radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y + offset), radius: dotRadius)
            case 4:
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y - offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y - offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y + offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y + offset), radius: dotRadius)
            case 5:
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y - offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y - offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: center, radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y + offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y + offset), radius: dotRadius)
            case 6:
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y - offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y - offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x - offset, y: center.y + offset), radius: dotRadius)
                drawDot(in: context.cgContext, at: CGPoint(x: center.x + offset, y: center.y + offset), radius: dotRadius)
            default:
                break
            }
        }
        
        material.diffuse.contents = image
        return material
    }
    
    private func drawDot(in context: CGContext, at point: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.fillEllipse(in: rect)
    }
    
    // MARK: - Roll Dice
    
    func rollDice(completion: @escaping (Int) -> Void) {
        // Haptic feedback - start
        let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator.prepare()
        impactGenerator.impactOccurred()
        
        // Reset position
        diceNode.physicsBody?.clearAllForces()
        diceNode.physicsBody?.velocity = SCNVector3Zero
        diceNode.physicsBody?.angularVelocity = SCNVector4Zero
        diceNode.position = SCNVector3(
            Float.random(in: -0.5...0.5),
            5,
            Float.random(in: -0.5...0.5)
        )
        
        // Random starting rotation
        diceNode.eulerAngles = SCNVector3(
            Float.random(in: 0...(Float.pi * 2)),
            Float.random(in: 0...(Float.pi * 2)),
            Float.random(in: 0...(Float.pi * 2))
        )
        
        // Apply force and torque for dramatic roll
        let force = SCNVector3(
            Float.random(in: -8...8),
            Float.random(in: -3...3),
            Float.random(in: -8...8)
        )
        
        let torque = SCNVector4(
            Float.random(in: -1...1),
            Float.random(in: -1...1),
            Float.random(in: -1...1),
            Float.random(in: 15...25)  // Strong spin
        )
        
        diceNode.physicsBody?.applyForce(force, asImpulse: true)
        diceNode.physicsBody?.applyTorque(torque, asImpulse: true)
        
        // Check for when dice settles
        checkTimer?.invalidate()
        var settledFrames = 0
        let requiredSettledFrames = 30  // ~0.5 seconds of stillness
        
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let velocity = self.diceNode.physicsBody?.velocity ?? SCNVector3Zero
            let angularVel = self.diceNode.physicsBody?.angularVelocity ?? SCNVector4Zero
            
            let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
            let angularSpeed = abs(angularVel.w)
            
            if speed < 0.05 && angularSpeed < 0.1 {
                settledFrames += 1
                
                if settledFrames >= requiredSettledFrames {
                    timer.invalidate()
                    
                    // Haptic feedback - landing
                    let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
                    heavyImpact.impactOccurred()
                    
                    // Determine which face is up
                    let result = self.determineTopFace()
                    completion(result)
                }
            } else {
                settledFrames = 0
            }
        }
        
        // Timeout after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.checkTimer?.isValid == true {
                self?.checkTimer?.invalidate()
                completion(Int.random(in: 1...6))  // Fallback random result
            }
        }
    }
    
    private func determineTopFace() -> Int {
        // Get the dice's current rotation
        let transform = diceNode.presentation.transform
        
        // Define face normals in local space
        let faceNormals: [(normal: SCNVector3, value: Int)] = [
            (SCNVector3(0, 0, 1), 1),   // Front
            (SCNVector3(1, 0, 0), 3),   // Right
            (SCNVector3(0, 0, -1), 6),  // Back
            (SCNVector3(-1, 0, 0), 4),  // Left
            (SCNVector3(0, 1, 0), 2),   // Top
            (SCNVector3(0, -1, 0), 5),  // Bottom
        ]
        
        let worldUp = SCNVector3(0, 1, 0)
        var maxDot: Float = -2
        var topFaceValue = 1
        
        for (normal, value) in faceNormals {
            // Transform normal to world space
            let worldNormal = SCNVector3(
                transform.m11 * normal.x + transform.m21 * normal.y + transform.m31 * normal.z,
                transform.m12 * normal.x + transform.m22 * normal.y + transform.m32 * normal.z,
                transform.m13 * normal.x + transform.m23 * normal.y + transform.m33 * normal.z
            )
            
            // Dot product with world up
            let dot = worldNormal.x * worldUp.x + worldNormal.y * worldUp.y + worldNormal.z * worldUp.z
            
            if dot > maxDot {
                maxDot = dot
                topFaceValue = value
            }
        }
        
        return topFaceValue
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}

