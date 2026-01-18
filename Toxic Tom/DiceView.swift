//
//  DiceView.swift
//  Toxic Tom
//
//  D20 (Icosahedron) dice prototype using SceneKit
//

import SwiftUI
import SceneKit

// MARK: - SceneKit D20 View

struct DiceSceneView: UIViewRepresentable {
    let onResult: (Int) -> Void
    let onRollStart: () -> Void
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = context.coordinator.scene
        // Warm dark brown - matches parchment theme
        sceneView.backgroundColor = UIColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1.0)
        sceneView.antialiasingMode = .multisampling4X
        sceneView.autoenablesDefaultLighting = false
        
        // CRITICAL: Set delegate so we get physics callbacks
        sceneView.delegate = context.coordinator
        context.coordinator.sceneView = sceneView
        
        // Enable playing to get delegate callbacks
        sceneView.isPlaying = true
        
        // Tap gesture to roll
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(D20Coordinator.handleTap))
        sceneView.addGestureRecognizer(tapGesture)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {}
    
    func makeCoordinator() -> D20Coordinator {
        D20Coordinator(onResult: onResult, onRollStart: onRollStart)
    }
}

// MARK: - D20 Coordinator

class D20Coordinator: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    var diceNode: SCNNode!
    var sceneView: SCNView?
    var onResult: (Int) -> Void
    var onRollStart: () -> Void
    var isRolling = false
    var hasReportedResult = false
    
    // ROBUST DETECTION STATE (based on research)
    var hasStartedMoving = false          // Must move first before we check for rest
    var consecutiveRestFrames = 0         // Count frames at rest
    var lastDetectedFace = -1             // Last face we detected
    var consecutiveStableFaceFrames = 0   // Same face detected consecutively
    
    // THRESHOLDS (from research: use very small values)
    let movementThreshold: Float = 0.1    // Must exceed this to count as "moved"
    let velocityThreshold: Float = 0.003  // Must be below this to count as "at rest"
    let angularThreshold: Float = 0.003   // Must be below this to count as "at rest"
    let requiredRestFrames = 45           // ~0.75 seconds at 60fps
    let requiredStableFaceFrames = 10     // Same face for ~0.17 seconds
    let floorHeight: Float = 1.0          // Dice must be below this Y
    let cockedThreshold: Float = 0.85     // If best normal·up < this, die is "cocked" (on edge)
    
    // Golden ratio for icosahedron
    let phi: Float = (1.0 + sqrt(5.0)) / 2.0
    
    // Precomputed LOCAL face normals and their values (computed once at init)
    var localFaceNormals: [(normal: SCNVector3, value: Int)] = []
    
    init(onResult: @escaping (Int) -> Void, onRollStart: @escaping () -> Void) {
        self.onResult = onResult
        self.onRollStart = onRollStart
        super.init()
        setupScene()
        precomputeFaceNormals()  // Compute once, use forever
    }
    
    @objc func handleTap() {
        if !isRolling {
            onRollStart()
            rollDice()
        }
    }
    
    // MARK: - Precompute Face Normals (done once at init)
    
    private func precomputeFaceNormals() {
        let scale: Float = 0.55
        let vertices: [SCNVector3] = [
            SCNVector3(0, 1, phi),
            SCNVector3(0, -1, phi),
            SCNVector3(0, 1, -phi),
            SCNVector3(0, -1, -phi),
            SCNVector3(1, phi, 0),
            SCNVector3(-1, phi, 0),
            SCNVector3(1, -phi, 0),
            SCNVector3(-1, -phi, 0),
            SCNVector3(phi, 0, 1),
            SCNVector3(-phi, 0, 1),
            SCNVector3(phi, 0, -1),
            SCNVector3(-phi, 0, -1)
        ].map { SCNVector3($0.x * scale, $0.y * scale, $0.z * scale) }
        
        let faces: [[Int]] = [
            [0, 1, 8], [0, 8, 4], [0, 4, 5], [0, 5, 9], [0, 9, 1],
            [1, 6, 8], [8, 6, 10], [8, 10, 4], [4, 10, 2], [4, 2, 5],
            [5, 2, 11], [5, 11, 9], [9, 11, 7], [9, 7, 1], [1, 7, 6],
            [3, 6, 7], [3, 7, 11], [3, 11, 2], [3, 2, 10], [3, 10, 6]
        ]
        
        let faceValues = [20, 2, 8, 14, 12, 18, 4, 6, 16, 10, 11, 9, 15, 5, 7, 1, 19, 13, 17, 3]
        
        localFaceNormals.removeAll()
        
        for (faceIndex, face) in faces.enumerated() {
            let v0 = vertices[face[0]]
            let v1 = vertices[face[1]]
            let v2 = vertices[face[2]]
            
            // Face center
            let center = SCNVector3(
                (v0.x + v1.x + v2.x) / 3,
                (v0.y + v1.y + v2.y) / 3,
                (v0.z + v1.z + v2.z) / 3
            )
            
            // Cross product for normal
            let edge1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
            let edge2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)
            var normal = SCNVector3(
                edge1.y * edge2.z - edge1.z * edge2.y,
                edge1.z * edge2.x - edge1.x * edge2.z,
                edge1.x * edge2.y - edge1.y * edge2.x
            )
            
            // Normalize
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            normal = SCNVector3(normal.x / length, normal.y / length, normal.z / length)
            
            // Ensure outward pointing (dot with center should be positive)
            let dotWithCenter = normal.x * center.x + normal.y * center.y + normal.z * center.z
            if dotWithCenter < 0 {
                normal = SCNVector3(-normal.x, -normal.y, -normal.z)
            }
            
            localFaceNormals.append((normal: normal, value: faceValues[faceIndex]))
        }
    }
    
    // MARK: - SCNSceneRendererDelegate (ROBUST DETECTION)
    
    func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
        guard isRolling, !hasReportedResult else { return }
        guard let physicsBody = diceNode.physicsBody else { return }
        
        let vel = physicsBody.velocity
        let angVel = physicsBody.angularVelocity
        let velMag = sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)
        let angMag = sqrt(angVel.x * angVel.x + angVel.y * angVel.y + angVel.z * angVel.z)
        
        // STEP 1: Wait until dice has actually MOVED
        // (Prevents false detection during initial drop with zero velocity)
        if !hasStartedMoving {
            if velMag > movementThreshold || angMag > movementThreshold {
                hasStartedMoving = true
            }
            return  // Don't check for rest until we've moved
        }
        
        // STEP 2: Check if dice is at rest (very strict thresholds)
        let position = diceNode.presentation.position
        let isNearFloor = position.y < floorHeight
        let isVelocityLow = velMag < velocityThreshold
        let isAngularLow = angMag < angularThreshold
        
        if isNearFloor && isVelocityLow && isAngularLow {
            consecutiveRestFrames += 1
        } else {
            // Still moving - reset everything
            consecutiveRestFrames = 0
            lastDetectedFace = -1
            consecutiveStableFaceFrames = 0
            return
        }
        
        // STEP 3: Must be at rest for required duration
        guard consecutiveRestFrames >= requiredRestFrames else { return }
        
        // STEP 4: Detect top face using world-space normals
        let detection = detectTopFaceUsingWorldNormals()
        
        // STEP 5: Check if die is "cocked" (landed on edge)
        // If the best normal isn't pointing up enough, the die is on an edge
        if detection.confidence < cockedThreshold {
            // Die is cocked! Apply a small nudge to make it settle properly
            // Reset detection and let it try again
            consecutiveRestFrames = 0
            lastDetectedFace = -1
            consecutiveStableFaceFrames = 0
            
            // Apply a tiny random nudge to tip it over
            let nudge = SCNVector3(
                Float.random(in: -0.05...0.05),
                0.02,  // Tiny upward pop
                Float.random(in: -0.05...0.05)
            )
            diceNode.physicsBody?.applyForce(nudge, asImpulse: true)
            return
        }
        
        // STEP 6: Face must be STABLE (same face detected multiple times)
        if detection.value == lastDetectedFace {
            consecutiveStableFaceFrames += 1
        } else {
            lastDetectedFace = detection.value
            consecutiveStableFaceFrames = 1
        }
        
        // STEP 7: Only report when face is stable
        guard consecutiveStableFaceFrames >= requiredStableFaceFrames else { return }
        
        // SUCCESS: Report result
        hasReportedResult = true
        isRolling = false
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            self.onResult(detection.value)
        }
    }
    
    // MARK: - Detect Top Face
    // Uses MULTIPLE methods and picks the one with highest confidence
    
    private func detectTopFaceUsingWorldNormals() -> (value: Int, confidence: Float) {
        // METHOD 1: Hit test from above (most reliable - uses actual geometry)
        if let hitTestResult = detectUsingHitTest() {
            return hitTestResult
        }
        
        // METHOD 2: Fallback to normal calculation using simd (more numerically stable)
        return detectUsingSimdNormals()
    }
    
    // METHOD 1: Cast a ray from above the dice straight down
    // This literally asks "what face would I see looking down?"
    private func detectUsingHitTest() -> (value: Int, confidence: Float)? {
        let faceValues = [20, 2, 8, 14, 12, 18, 4, 6, 16, 10, 11, 9, 15, 5, 7, 1, 19, 13, 17, 3]
        
        // Get dice position
        let dicePosition = diceNode.presentation.position
        
        // Cast ray from high above the dice straight down
        let rayStart = SCNVector3(dicePosition.x, dicePosition.y + 5, dicePosition.z)
        let rayEnd = SCNVector3(dicePosition.x, dicePosition.y - 5, dicePosition.z)
        
        // Perform hit test
        let hitResults = scene.rootNode.hitTestWithSegment(
            from: rayStart,
            to: rayEnd,
            options: [
                SCNHitTestOption.searchMode.rawValue: NSNumber(value: SCNHitTestSearchMode.all.rawValue),
                SCNHitTestOption.backFaceCulling.rawValue: NSNumber(value: false)
            ]
        )
        
        // Find hit on the dice node
        for hit in hitResults {
            if hit.node == diceNode || hit.node.parent == diceNode {
                let geometryIndex = hit.geometryIndex
                
                // geometryIndex tells us which geometry element (face) was hit
                if geometryIndex >= 0 && geometryIndex < faceValues.count {
                    // Calculate confidence based on the hit normal's alignment with up
                    let hitNormal = hit.worldNormal
                    let confidence = hitNormal.y  // How much the normal points up
                    
                    return (value: faceValues[geometryIndex], confidence: abs(confidence))
                }
            }
        }
        
        return nil
    }
    
    // METHOD 2: Use simd for more numerically stable normal calculations
    private func detectUsingSimdNormals() -> (value: Int, confidence: Float) {
        let presentation = diceNode.presentation
        
        // Get the rotation matrix from the presentation transform
        let transform = presentation.simdWorldTransform
        
        // Extract the 3x3 rotation matrix
        let rotationMatrix = simd_float3x3(
            simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
        
        let worldUp = simd_float3(0, 1, 0)
        
        var bestDot: Float = -Float.infinity
        var bestFaceValue = 1
        
        for faceData in localFaceNormals {
            // Convert SCNVector3 to simd_float3
            let localNormal = simd_float3(faceData.normal.x, faceData.normal.y, faceData.normal.z)
            
            // Transform normal to world space using matrix multiplication
            let worldNormal = simd_normalize(rotationMatrix * localNormal)
            
            // Dot product with world up
            let dot = simd_dot(worldNormal, worldUp)
            
            if dot > bestDot {
                bestDot = dot
                bestFaceValue = faceData.value
            }
        }
        
        return (value: bestFaceValue, confidence: bestDot)
    }
    
    private func setupScene() {
        // MARK: Camera - TOP DOWN with slight tilt for depth
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 40
        cameraNode.position = SCNVector3(0, 10, 2.5)  // Slight tilt for 3D depth
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        
        // MARK: Lighting - Balanced for contrast AND visibility
        
        // Key light - from upper-front for good shadows
        let keyLight = SCNLight()
        keyLight.type = .spot
        keyLight.intensity = 1000
        keyLight.color = UIColor(red: 1.0, green: 0.97, blue: 0.93, alpha: 1.0)
        keyLight.castsShadow = true
        keyLight.shadowRadius = 5
        keyLight.shadowColor = UIColor.black.withAlphaComponent(0.5)
        keyLight.spotInnerAngle = 30
        keyLight.spotOuterAngle = 60
        
        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(3, 10, 4)  // Upper front-right
        keyLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLightNode)
        
        // Fill light - softer, opposite side
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.intensity = 300
        fillLight.color = UIColor(red: 0.85, green: 0.88, blue: 1.0, alpha: 1.0)
        
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(-4, 5, -2)
        scene.rootNode.addChildNode(fillLightNode)
        
        // Low ambient - preserves shadows
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 80
        ambientLight.color = UIColor(red: 0.25, green: 0.25, blue: 0.3, alpha: 1.0)
        
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // MARK: Floor - warm dark surface matching theme
        let floor = SCNFloor()
        floor.reflectivity = 0.1
        floor.firstMaterial?.diffuse.contents = UIColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1.0)
        
        let floorNode = SCNNode(geometry: floor)
        floorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floorNode.physicsBody?.friction = 0.9
        floorNode.physicsBody?.restitution = 0.2
        scene.rootNode.addChildNode(floorNode)
        
        // MARK: Walls - TIGHT containment for portrait screen
        // Portrait phones show less horizontal space, so walls must be narrower
        let wallX: Float = 1.8   // Narrow for horizontal (phone width)
        let wallZ: Float = 2.5   // Slightly more for vertical
        addWall(at: SCNVector3(0, 2, -wallZ), size: SCNVector3(wallX * 2 + 1, 5, 0.3))
        addWall(at: SCNVector3(-wallX, 2, 0), size: SCNVector3(0.3, 5, wallZ * 2 + 1))
        addWall(at: SCNVector3(wallX, 2, 0), size: SCNVector3(0.3, 5, wallZ * 2 + 1))
        addWall(at: SCNVector3(0, 2, wallZ), size: SCNVector3(wallX * 2 + 1, 5, 0.3))
        addWall(at: SCNVector3(0, 4, 0), size: SCNVector3(wallX * 2 + 1, 0.3, wallZ * 2 + 1))  // Ceiling
        
        // MARK: D20 Dice
        diceNode = createD20()
        diceNode.position = SCNVector3(0, 1, 0)  // Centered
        scene.rootNode.addChildNode(diceNode)
    }
    
    private func addWall(at position: SCNVector3, size: SCNVector3) {
        let wall = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: 0)
        wall.firstMaterial?.transparency = 0
        
        let wallNode = SCNNode(geometry: wall)
        wallNode.position = position
        wallNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        wallNode.physicsBody?.friction = 0.3
        wallNode.physicsBody?.restitution = 0.7
        scene.rootNode.addChildNode(wallNode)
    }
    
    // MARK: - Create D20 Icosahedron
    
    private func createD20() -> SCNNode {
        let scale: Float = 0.55  // Smaller dice
        
        // 12 vertices of icosahedron using golden ratio
        let vertices: [SCNVector3] = [
            SCNVector3(0, 1, phi),
            SCNVector3(0, -1, phi),
            SCNVector3(0, 1, -phi),
            SCNVector3(0, -1, -phi),
            SCNVector3(1, phi, 0),
            SCNVector3(-1, phi, 0),
            SCNVector3(1, -phi, 0),
            SCNVector3(-1, -phi, 0),
            SCNVector3(phi, 0, 1),
            SCNVector3(-phi, 0, 1),
            SCNVector3(phi, 0, -1),
            SCNVector3(-phi, 0, -1)
        ].map { SCNVector3($0.x * scale, $0.y * scale, $0.z * scale) }
        
        // 20 triangular faces
        let faces: [[Int]] = [
            [0, 1, 8], [0, 8, 4], [0, 4, 5], [0, 5, 9], [0, 9, 1],
            [1, 6, 8], [8, 6, 10], [8, 10, 4], [4, 10, 2], [4, 2, 5],
            [5, 2, 11], [5, 11, 9], [9, 11, 7], [9, 7, 1], [1, 7, 6],
            [3, 6, 7], [3, 7, 11], [3, 11, 2], [3, 2, 10], [3, 10, 6]
        ]
        
        // D20 numbering - opposite faces sum to 21
        let faceValues = [20, 2, 8, 14, 12, 18, 4, 6, 16, 10, 11, 9, 15, 5, 7, 1, 19, 13, 17, 3]
        
        var allVertices: [SCNVector3] = []
        var allNormals: [SCNVector3] = []
        var allTexCoords: [CGPoint] = []
        
        for face in faces {
            let v0 = vertices[face[0]]
            let v1 = vertices[face[1]]
            let v2 = vertices[face[2]]
            
            // Calculate face normal for rendering
            let edge1 = SCNVector3(v1.x - v0.x, v1.y - v0.y, v1.z - v0.z)
            let edge2 = SCNVector3(v2.x - v0.x, v2.y - v0.y, v2.z - v0.z)
            var normal = SCNVector3(
                edge1.y * edge2.z - edge1.z * edge2.y,
                edge1.z * edge2.x - edge1.x * edge2.z,
                edge1.x * edge2.y - edge1.y * edge2.x
            )
            let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
            normal = SCNVector3(normal.x / length, normal.y / length, normal.z / length)
            
            // Ensure normal points OUTWARD from center
            let faceCenter = SCNVector3(
                (v0.x + v1.x + v2.x) / 3,
                (v0.y + v1.y + v2.y) / 3,
                (v0.z + v1.z + v2.z) / 3
            )
            let dotWithCenter = normal.x * faceCenter.x + normal.y * faceCenter.y + normal.z * faceCenter.z
            if dotWithCenter < 0 {
                normal = SCNVector3(-normal.x, -normal.y, -normal.z)
            }
            
            allVertices.append(contentsOf: [v0, v1, v2])
            allNormals.append(contentsOf: [normal, normal, normal])
            allTexCoords.append(contentsOf: [
                CGPoint(x: 0.5, y: 0.0),
                CGPoint(x: 0.0, y: 1.0),
                CGPoint(x: 1.0, y: 1.0)
            ])
        }
        
        let vertexSource = SCNGeometrySource(vertices: allVertices)
        let normalSource = SCNGeometrySource(normals: allNormals)
        let texCoordSource = SCNGeometrySource(textureCoordinates: allTexCoords)
        
        var materials: [SCNMaterial] = []
        for value in faceValues {
            materials.append(createFaceMaterial(value: value))
        }
        
        var elements: [SCNGeometryElement] = []
        for i in 0..<20 {
            let faceIndices: [Int32] = [Int32(i * 3), Int32(i * 3 + 1), Int32(i * 3 + 2)]
            elements.append(SCNGeometryElement(indices: faceIndices, primitiveType: .triangles))
        }
        
        let geometry = SCNGeometry(sources: [vertexSource, normalSource, texCoordSource], elements: elements)
        geometry.materials = materials
        
        let node = SCNNode(geometry: geometry)
        
        // Physics - tuned for smaller dice
        let shape = SCNPhysicsShape(geometry: geometry, options: [.type: SCNPhysicsShape.ShapeType.convexHull])
        let body = SCNPhysicsBody(type: .dynamic, shape: shape)
        body.mass = 0.8
        body.friction = 0.8
        body.restitution = 0.25
        body.angularDamping = 0.3
        body.damping = 0.15
        node.physicsBody = body
        
        return node
    }
    
    private func createFaceMaterial(value: Int) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = createFaceTexture(value: value)
        material.roughness.contents = 0.3
        material.metalness.contents = 0.0
        return material
    }
    
    private func createFaceTexture(value: Int) -> UIImage {
        let size = CGSize(width: 128, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Parchment/aged paper background - matches app theme
            UIColor(red: 0.95, green: 0.91, blue: 0.85, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Subtle aged texture effect
            UIColor(red: 0.90, green: 0.85, blue: 0.78, alpha: 0.3).setFill()
            let path = UIBezierPath(ovalIn: CGRect(x: 10, y: 10, width: 108, height: 108))
            path.fill()
            
            // Number styling
            let text = "\(value)"
            let fontSize: CGFloat = value >= 10 ? 40 : 50
            
            // Use serif font for medieval feel
            let font = UIFont(name: "Georgia-Bold", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: .bold)
            
            // Dark brown ink color - matches app theme
            let textColor = UIColor(red: 0.22, green: 0.16, blue: 0.11, alpha: 1.0)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2 + 4,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    // MARK: - Roll
    
    func rollDice() {
        // Reset ALL detection state
        isRolling = true
        hasReportedResult = false
        hasStartedMoving = false
        consecutiveRestFrames = 0
        lastDetectedFace = -1
        consecutiveStableFaceFrames = 0
        
        // Haptic
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Reset physics
        diceNode.physicsBody?.clearAllForces()
        diceNode.physicsBody?.velocity = SCNVector3Zero
        diceNode.physicsBody?.angularVelocity = SCNVector4Zero
        
        // Start centered, drop from above
        diceNode.position = SCNVector3(
            Float.random(in: -0.3...0.3),
            3,
            Float.random(in: -0.3...0.3)
        )
        
        diceNode.eulerAngles = SCNVector3(
            Float.random(in: 0...(Float.pi * 2)),
            Float.random(in: 0...(Float.pi * 2)),
            Float.random(in: 0...(Float.pi * 2))
        )
        
        // Apply forces
        let force = SCNVector3(
            Float.random(in: -0.8...0.8),
            Float.random(in: -0.3...0.3),
            Float.random(in: -0.8...0.8)
        )
        
        let torque = SCNVector4(
            Float.random(in: -1...1),
            Float.random(in: -1...1),
            Float.random(in: -1...1),
            Float.random(in: 10...18)
        )
        
        diceNode.physicsBody?.applyForce(force, asImpulse: true)
        diceNode.physicsBody?.applyTorque(torque, asImpulse: true)
        
        // The SCNSceneRendererDelegate (renderer:didSimulatePhysicsAtTime:) 
        // will automatically detect when the dice has stopped and report the result.
        // No timer needed - the delegate is called every frame after physics simulation.
        
        // Safety timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, self.isRolling, !self.hasReportedResult else { return }
            self.hasReportedResult = true
            self.isRolling = false
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            let detection = self.detectTopFaceUsingWorldNormals()
            self.onResult(detection.value)
        }
    }
}

#Preview {
    ContentView()
}
