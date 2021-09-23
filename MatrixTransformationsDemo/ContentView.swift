//
//  ContentView.swift
//  MatrixTransformationsDemo
//
//  Created by Nien Lam on 9/23/21.
//  Copyright © 2021 Line Break, LLC. All rights reserved.
//

import SwiftUI
import ARKit
import RealityKit
import Combine


// MARK: - View model for handling communication between the UI and ARView.
class ViewModel: ObservableObject {
    let uiSignal = PassthroughSubject<UISignal, Never>()

    enum UISignal {
        case moveForward
        case rotateCCW
        case rotateCW
    }
}


// MARK: - UI Layer.
struct ContentView : View {
    @StateObject var viewModel: ViewModel

    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
 
            // Forward control.
            HStack {
                HStack {
                    Button {
                        viewModel.uiSignal.send(.moveForward)
                    } label: {
                        buttonIcon("arrow.up", color: .blue)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.horizontal, 30)

            // Rotation controls.
            HStack {
                HStack {
                    Button {
                        viewModel.uiSignal.send(.rotateCCW)
                    } label: {
                        buttonIcon("rotate.left", color: .red)
                    }
                }

                HStack {
                    Button {
                        viewModel.uiSignal.send(.rotateCW)
                    } label: {
                        buttonIcon("rotate.right", color: .red)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.horizontal, 30)
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
    }

    // Helper method to render icon.
    func buttonIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .resizable()
            .padding(10)
            .frame(width: 44, height: 44)
            .foregroundColor(.white)
            .background(color)
            .cornerRadius(5)
    }
}


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel

    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var originAnchor: AnchorEntity!
    var pov: AnchorEntity!
    var subscriptions = Set<AnyCancellable>()
    
    var planeEntity: Entity!

    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
        
        setupEntities()
    }

    func setupScene() {
        // Setup world tracking.
        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
        
        // Process UI signals.
        viewModel.uiSignal.sink { [weak self] in
            self?.processUISignal($0)
        }.store(in: &subscriptions)
    }

    func processUISignal(_ signal: ViewModel.UISignal) {
        switch signal {

        case .moveForward:
            moveForward()
            
        case .rotateCCW:
            rotateCCW()
            
        case .rotateCW:
            rotateCW()

        }
    }
    
    // Helper method that creates red box.
    func makeBox() -> Entity {
        let boxMesh   = MeshResource.generateBox(size: 0.025, cornerRadius: 0.002)
        let material  = SimpleMaterial(color: .red, isMetallic: false)
        return ModelEntity(mesh: boxMesh, materials: [material])
    }
    

    func setupEntities() {
        // Create an anchor at scene origin.
        originAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(originAnchor)

        // Add box to origin anchor.
        let originBox = makeBox()
        originAnchor.addChild(originBox)
        
        // Load and add toy biplane entity to origin anchor.
        planeEntity = try! Entity.load(named: "toy_biplane")
        originAnchor.addChild(planeEntity!)
        
        // Play stored animation.
        for animation in planeEntity.availableAnimations {
            planeEntity.playAnimation(animation.repeat())
        }

        // Set initial position and orientation of the biplane.
        
        // Move plane forward.
        planeEntity.position.z  = -0.25
        
        // Rotate plane on y-axis & x-axis
        let yOrientation = simd_quatf(angle: Float.pi / 4, axis: [0, 1, 0])
        let xOrientation = simd_quatf(angle: Float.pi / 4, axis: [1, 0, 0])
        planeEntity.orientation = yOrientation * xOrientation
    }
    
    
    func moveForward() {
        // Move biplane forward in z-axis relative to itself.
        // Distance units are based on model space.
        let transform = Transform(translation: [0, 0, 2])

        planeEntity!.transform.matrix *= transform.matrix
    }

    func rotateCCW() {
        // Roll counter clockwise on z-axis
        let orientation = simd_quatf(angle: -Float.pi / 4, axis: [0, 0, 1])
        let transform = Transform(rotation: orientation)
        
        planeEntity!.transform.matrix *= transform.matrix
    }

    func rotateCW() {
        // Roll counter clockwise on z-axis
        let orientation = simd_quatf(angle: Float.pi / 4, axis: [0, 0, 1])
        let transform = Transform(rotation: orientation)

        planeEntity!.transform.matrix *= transform.matrix
    }
}
