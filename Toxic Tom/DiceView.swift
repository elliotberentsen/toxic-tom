//
//  DiceView.swift
//  Toxic Tom
//
//  2×D6 Dice using SceneKit - Two classic dice for medieval authenticity
//

import SwiftUI
import SceneKit

// MARK: - SceneKit 2×D6 View

struct DiceSceneView: UIViewRepresentable {
    let onResult: (Int) -> Void
    let onRollStart: () -> Void
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.scene
        // Match the wood background tone for areas outside the floor
        sceneView.backgroundColor = UIColor(red: 0.18, green: 0.12, blue: 0.08, alpha: 1.0)
        sceneView.antialiasingMode = .multisampling4X
        sceneView.autoenablesDefaultLighting = false
        
        // Set delegate for physics callbacks
        sceneView.delegate = context.coordinator
        context.coordinator.sceneView = sceneView
        
        // Enable playing to get delegate callbacks
        sceneView.isPlaying = true
        
        // Tap gesture to roll
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(DiceCoordinator.handleTap))
        sceneView.addGestureRecognizer(tapGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    func makeCoordinator() -> DiceCoordinator {
        DiceCoordinator(onResult: onResult, onRollStart: onRollStart)
    }
}

// MARK: - Dice Coordinator

class DiceCoordinator: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    var sceneView: SCNView?
    var onResult: (Int) -> Void
    var onRollStart: () -> Void
    
    // Two dice nodes
    var dice1Node: SCNNode!
    var dice2Node: SCNNode!
    
    // Rolling state
    var isRolling = false
    var hasReportedResult = false
    
    // Per-die tracking
    var dice1HasMoved = false
    var dice2HasMoved = false
    var dice1RestFrames = 0
    var dice2RestFrames = 0
    var dice1VisualRestFrames = 0
    var dice2VisualRestFrames = 0
    var dice1LastPosition: SCNVector3?
    var dice2LastPosition: SCNVector3?
    
    // Stable face tracking
    var lastTotalValue = -1
    var stableValueFrames = 0
    
    // Thresholds - balanced for speed and accuracy
    let movementThreshold: Float = 0.05
    let velocityThreshold: Float = 0.003      // Slightly higher - still very stable
    let angularThreshold: Float = 0.003       // Slightly higher - still very stable
    let visualThreshold: Float = 0.0005       // Slightly more tolerance
    let requiredPhysicsRestFrames = 25        // ~0.42 seconds of physics rest
    let requiredVisualRestFrames = 18         // ~0.3 seconds of visual stability
    let requiredStableValueFrames = 12        // ~0.2 seconds of same value
    let floorHeight: Float = 0.6
    
    init(onResult: @escaping (Int) -> Void, onRollStart: @escaping () -> Void) {
        self.onResult = onResult
        self.onRollStart = onRollStart
        super.init()
        setupScene()
    }
    
    @objc func handleTap() {
        if !isRolling {
            onRollStart()
            rollDice()
        }
    }
    
    // MARK: - Scene Setup
    
    private func setupScene() {
        // Camera - top down with slight angle, wider FOV to see more
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, 7, 2.5)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // Lighting
        setupLighting()
        
        // Floor - wooden table surface with medieval feel
        let floor = SCNFloor()
        floor.reflectivity = 0.03  // Very subtle reflection (wood isn't shiny)
        
        // Apply wood texture
        if let woodTexture = UIImage(named: "wood-background") {
            floor.firstMaterial?.diffuse.contents = woodTexture
            // Scale the texture so wood grain looks natural (higher = more repetitions = smaller grain)
            floor.firstMaterial?.diffuse.contentsTransform = SCNMatrix4MakeScale(25, 25, 1)
            floor.firstMaterial?.diffuse.wrapS = .repeat
            floor.firstMaterial?.diffuse.wrapT = .repeat
        } else {
            // Fallback to dark wood color if image not found
            floor.firstMaterial?.diffuse.contents = UIColor(red: 0.15, green: 0.10, blue: 0.07, alpha: 1.0)
        }
        
        // Add subtle normal/roughness for realism
        floor.firstMaterial?.roughness.contents = 0.7  // Wood is somewhat rough
        floor.firstMaterial?.metalness.contents = 0.0  // Wood isn't metallic
        
        let floorNode = SCNNode(geometry: floor)
        floorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floorNode.physicsBody?.friction = 0.6
        floorNode.physicsBody?.restitution = 0.5  // Bouncy floor!
        scene.rootNode.addChildNode(floorNode)
        
        // Walls - TIGHT containment to keep dice visible on screen
        // Phone screens are portrait (narrow width), so horizontal walls must be closer
        let wallX: Float = 1.2    // Narrow horizontal bounds (left/right)
        let wallZ: Float = 1.8    // Slightly more vertical space (front/back)
        
        // Back wall
        addWall(at: SCNVector3(0, 1.5, -wallZ), size: SCNVector3(wallX * 2 + 0.5, 4, 0.2))
        // Left wall
        addWall(at: SCNVector3(-wallX, 1.5, 0), size: SCNVector3(0.2, 4, wallZ * 2 + 0.5))
        // Right wall
        addWall(at: SCNVector3(wallX, 1.5, 0), size: SCNVector3(0.2, 4, wallZ * 2 + 0.5))
        // Front wall
        addWall(at: SCNVector3(0, 1.5, wallZ), size: SCNVector3(wallX * 2 + 0.5, 4, 0.2))
        // Ceiling
        addWall(at: SCNVector3(0, 3.5, 0), size: SCNVector3(wallX * 2 + 0.5, 0.2, wallZ * 2 + 0.5))
        
        // Create two dice - positioned within visible bounds
        dice1Node = createD6()
        dice1Node.position = SCNVector3(-0.4, 1, 0)
        scene.rootNode.addChildNode(dice1Node)
        
        dice2Node = createD6()
        dice2Node.position = SCNVector3(0.4, 1, 0)
        scene.rootNode.addChildNode(dice2Node)
    }
    
    private func setupLighting() {
        // Key light - warm candlelight/tavern feel
        let keyLight = SCNLight()
        keyLight.type = .spot
        keyLight.intensity = 1000
        keyLight.color = UIColor(red: 1.0, green: 0.92, blue: 0.8, alpha: 1.0)  // Warm/golden
        keyLight.castsShadow = true
        keyLight.shadowRadius = 5
        keyLight.shadowColor = UIColor.black.withAlphaComponent(0.6)  // Stronger shadows on wood
        keyLight.spotInnerAngle = 35
        keyLight.spotOuterAngle = 70
        
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(2, 8, 3)
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)
        
        // Fill light - subtle warm tone
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 300
        fillLight.color = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1.0)  // Warm fill
        
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-3, 5, -2)
        scene.rootNode.addChildNode(fillLightNode)
        
        // Ambient - warm ambient for tavern atmosphere
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 150
        ambientLight.color = UIColor(red: 0.4, green: 0.32, blue: 0.25, alpha: 1.0)  // Warm brown ambient
        
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
    }
    
    private func addWall(at position: SCNVector3, size: SCNVector3) {
        let wall = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0)
        wall.firstMaterial?.transparency = 0
        
        let wallNode = SCNNode(geometry: wall)
        wallNode.position = position
        wallNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        wallNode.physicsBody?.friction = 0.4
        wallNode.physicsBody?.restitution = 0.6
        scene.rootNode.addChildNode(wallNode)
    }
    
    // MARK: - Create D6 Cube
    
    private func createD6() -> SCNNode {
        let size: CGFloat = 0.5
        let chamfer: CGFloat = 0.05
        
        let cube = SCNBox(width: size, height: size, length: size, chamferRadius: chamfer)
        
        // SCNBox material order (verified from Apple docs):
        // materials[0] = Front  (+Z)
        // materials[1] = Right  (+X)
        // materials[2] = Back   (-Z)
        // materials[3] = Left   (-X)
        // materials[4] = Top    (+Y)
        // materials[5] = Bottom (-Y)
        //
        // Standard D6: opposite faces sum to 7 (1↔6, 2↔5, 3↔4)
        let materials = [
            createFaceMaterial(value: 2),  // [0] Front  (+Z) - 2 opposite 5
            createFaceMaterial(value: 3),  // [1] Right  (+X) - 3 opposite 4
            createFaceMaterial(value: 5),  // [2] Back   (-Z) - 5 opposite 2
            createFaceMaterial(value: 4),  // [3] Left   (-X) - 4 opposite 3
            createFaceMaterial(value: 1),  // [4] Top    (+Y) - 1 opposite 6
            createFaceMaterial(value: 6),  // [5] Bottom (-Y) - 6 opposite 1
        ]
        cube.materials = materials
        
        let node = SCNNode(geometry: cube)
        
        // Physics body - lots of bouncing, but natural spin
        let shape = SCNPhysicsShape(geometry: cube, options: nil)
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = 0.4              // Light = very reactive
        body.friction = 0.6          // Allows lots of rolling
        body.restitution = 0.55      // Bouncy! Multiple bounces
        body.angularDamping = 0.15   // Spin continues much longer
        body.damping = 0.08          // Movement lasts a long time
        node.physicsBody = body
        
        return node
    }
    
    private func createFaceMaterial(value: Int) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = createFaceTexture(value: value)
        material.roughness.contents = 0.45  // Slightly worn but still has some smoothness
        material.metalness.contents = 0.0   // Not metallic
        return material
    }
    
    private func createFaceTexture(value: Int) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Clean aged bone color - natural ivory that has yellowed with age
            // No artificial patterns - just authentic aged material color
            UIColor(red: 0.91, green: 0.86, blue: 0.78, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw pips (dots) - warm dark brown, hand-carved look
            let pipColor = UIColor(red: 0.22, green: 0.15, blue: 0.10, alpha: 1.0)
            pipColor.setFill()
            
            let pipRadius: CGFloat = 22
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let offset: CGFloat = 65
            
            // Pip positions for each value
            switch value {
            case 1:
                drawPip(at: center, radius: pipRadius)
            case 2:
                drawPip(at: CGPoint(x: center.x - offset, y: center.y - offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y + offset), radius: pipRadius)
            case 3:
                drawPip(at: CGPoint(x: center.x - offset, y: center.y - offset), radius: pipRadius)
                drawPip(at: center, radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y + offset), radius: pipRadius)
            case 4:
                drawPip(at: CGPoint(x: center.x - offset, y: center.y - offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y - offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x - offset, y: center.y + offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y + offset), radius: pipRadius)
            case 5:
                drawPip(at: CGPoint(x: center.x - offset, y: center.y - offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y - offset), radius: pipRadius)
                drawPip(at: center, radius: pipRadius)
                drawPip(at: CGPoint(x: center.x - offset, y: center.y + offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y + offset), radius: pipRadius)
            case 6:
                drawPip(at: CGPoint(x: center.x - offset, y: center.y - offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y - offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x - offset, y: center.y), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x - offset, y: center.y + offset), radius: pipRadius)
                drawPip(at: CGPoint(x: center.x + offset, y: center.y + offset), radius: pipRadius)
            default:
                break
            }
        }
    }
    
    private func drawPip(at point: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        UIBezierPath(ovalIn: rect).fill()
    }
    
    // MARK: - Roll Dice
    
    func rollDice() {
        // Reset all state
        isRolling = true
        hasReportedResult = false
        dice1HasMoved = false
        dice2HasMoved = false
        dice1RestFrames = 0
        dice2RestFrames = 0
        dice1VisualRestFrames = 0
        dice2VisualRestFrames = 0
        dice1LastPosition = nil
        dice2LastPosition = nil
        lastTotalValue = -1
        stableValueFrames = 0
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Reset and position dice
        resetDie(dice1Node, atX: Float.random(in: -0.5...(-0.2)))
        resetDie(dice2Node, atX: Float.random(in: 0.2...0.5))
        
        // Apply random forces to each die
        applyRandomForces(to: dice1Node)
        applyRandomForces(to: dice2Node)
        
        // Safety timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self = self, self.isRolling, !self.hasReportedResult else { return }
            self.forceReportResult()
        }
    }
    
    private func resetDie(_ node: SCNNode, atX x: Float) {
        node.physicsBody?.clearAllForces()
        node.physicsBody?.velocity = SCNVector3Zero
        node.physicsBody?.angularVelocity = SCNVector4Zero
        
        // Start from player's side with height for big bounces
        node.position = SCNVector3(
            x + Float.random(in: -0.1...0.1),
            1.0,   // Good height for bouncing
            Float.random(in: 0.6...0.9)  // From player's side
        )
        
        // Random starting orientation
        node.eulerAngles = SCNVector3(
            Float.random(in: 0...(Float.pi * 2)),
            Float.random(in: 0...(Float.pi * 2)),
            Float.random(in: 0...(Float.pi * 2))
        )
    }
    
    private func applyRandomForces(to node: SCNNode) {
        // Energetic throw for lots of bouncing, but natural-looking spin
        // The key: high velocity = lots of bounces, but moderate initial spin
        
        // Strong throw velocity - creates bouncing energy
        let throwVelocity = SCNVector3(
            Float.random(in: -0.4...0.4),     // Left/right variance
            Float.random(in: 0.8...1.2),      // Strong upward arc = big bounces
            Float.random(in: -1.5...(-1.0))   // Strong forward momentum
        )
        node.physicsBody?.velocity = throwVelocity
        
        // Moderate initial spin - NOT aggressive, natural looking
        // The spin will BUILD from all the bouncing
        let initialSpin = SCNVector4(
            Float.random(in: -1...1),   // Random spin axis
            Float.random(in: -1...1),
            Float.random(in: -1...1),
            Float.random(in: 1.2...2.0) // Natural start, builds from bounces
        )
        node.physicsBody?.applyTorque(initialSpin, asImpulse: true)
    }
    
    // MARK: - Physics Delegate
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        guard isRolling, !hasReportedResult else { return }
        
        // Check each die independently
        let die1Status = checkDieStatus(
            node: dice1Node,
            hasMoved: &dice1HasMoved,
            restFrames: &dice1RestFrames,
            visualRestFrames: &dice1VisualRestFrames,
            lastPosition: &dice1LastPosition
        )
        
        let die2Status = checkDieStatus(
            node: dice2Node,
            hasMoved: &dice2HasMoved,
            restFrames: &dice2RestFrames,
            visualRestFrames: &dice2VisualRestFrames,
            lastPosition: &dice2LastPosition
        )
        
        // Both dice must be fully at rest
        guard die1Status == .stable && die2Status == .stable else {
            lastTotalValue = -1
            stableValueFrames = 0
            return
        }
        
        // Detect top face of each die
        let value1 = detectTopFace(of: dice1Node)
        let value2 = detectTopFace(of: dice2Node)
        let total = value1 + value2
        
        // Verify stable result
        if total == lastTotalValue {
            stableValueFrames += 1
        } else {
            lastTotalValue = total
            stableValueFrames = 1
        }
        
        guard stableValueFrames >= requiredStableValueFrames else { return }
        
        // Success! Report result
        reportResult(total)
    }
    
    enum DieStatus {
        case moving
        case physicsResting
        case stable
    }
    
    private func checkDieStatus(
        node: SCNNode,
        hasMoved: inout Bool,
        restFrames: inout Int,
        visualRestFrames: inout Int,
        lastPosition: inout SCNVector3?
    ) -> DieStatus {
        guard let body = node.physicsBody else { return .moving }
        
        let presentation = node.presentation
        let position = presentation.position
        
        let vel = body.velocity
        let angVel = body.angularVelocity
        let velMag = sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)
        let angMag = sqrt(angVel.x * angVel.x + angVel.y * angVel.y + angVel.z * angVel.z)
        
        // Step 1: Wait for movement to start
        if !hasMoved {
            if velMag > movementThreshold || angMag > movementThreshold {
                hasMoved = true
                lastPosition = position
            }
            return .moving
        }
        
        // Step 2: Check physics rest (both linear and angular velocity must be very low)
        let nearFloor = position.y < floorHeight
        let physicsAtRest = nearFloor && velMag < velocityThreshold && angMag < angularThreshold
        
        if physicsAtRest {
            restFrames += 1
        } else {
            restFrames = 0
            visualRestFrames = 0
            lastPosition = position
            return .moving
        }
        
        guard restFrames >= requiredPhysicsRestFrames else {
            lastPosition = position
            return .physicsResting
        }
        
        // Step 3: Check visual stability (position only - physics handles rotation)
        if let lastPos = lastPosition {
            let posDelta = sqrt(
                pow(position.x - lastPos.x, 2) +
                pow(position.y - lastPos.y, 2) +
                pow(position.z - lastPos.z, 2)
            )
            
            if posDelta < visualThreshold {
                visualRestFrames += 1
            } else {
                visualRestFrames = 0
            }
        }
        
        lastPosition = position
        
        guard visualRestFrames >= requiredVisualRestFrames else {
            return .physicsResting
        }
        
        return .stable
    }
    
    // MARK: - Face Detection (Using convertVector for accuracy)
    
    private func detectTopFace(of node: SCNNode) -> Int {
        // Define the local normal direction for each face value
        // These correspond to our material assignments:
        // Front (+Z) = 2, Right (+X) = 3, Back (-Z) = 5
        // Left (-X) = 4, Top (+Y) = 1, Bottom (-Y) = 6
        let faceNormals: [(value: Int, normal: SCNVector3)] = [
            (1, SCNVector3(0, 1, 0)),   // Top face (+Y)
            (6, SCNVector3(0, -1, 0)),  // Bottom face (-Y)
            (3, SCNVector3(1, 0, 0)),   // Right face (+X)
            (4, SCNVector3(-1, 0, 0)),  // Left face (-X)
            (2, SCNVector3(0, 0, 1)),   // Front face (+Z)
            (5, SCNVector3(0, 0, -1)),  // Back face (-Z)
        ]
        
        var bestValue = 1
        var maxUpComponent: Float = -Float.infinity
        
        let presentation = node.presentation
        
        for face in faceNormals {
            // Convert the local face normal to world space
            // This is the most reliable method as it uses SceneKit's own transform
            let worldNormal = presentation.convertVector(face.normal, to: nil)
            
            // The Y component tells us how much this face points "up"
            // (This is the dot product with world up vector (0, 1, 0))
            if worldNormal.y > maxUpComponent {
                maxUpComponent = worldNormal.y
                bestValue = face.value
            }
        }
        
        return bestValue
    }
    
    // MARK: - Report Result
    
    private func reportResult(_ total: Int) {
        hasReportedResult = true
        isRolling = false
        
        DispatchQueue.main.async { [weak self] in
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            self?.onResult(total)
        }
    }
    
    private func forceReportResult() {
        let value1 = detectTopFace(of: dice1Node)
        let value2 = detectTopFace(of: dice2Node)
        reportResult(value1 + value2)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
