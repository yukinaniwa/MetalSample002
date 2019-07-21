//
//  ViewController.swift
//  MetalSample
//
//  Created by yuki naniwa on 2019/07/12.
//  Copyright © 2019 yuki naniwa. All rights reserved.
//

import UIKit
import MetalKit

struct Shader {
    static let main = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexIn {
            float4 position [[ attribute(0) ]];
        };

        vertex float4 vertex_main(const VertexIn vertex_in[[ stage_in ]]) {
            return vertex_in.position;
        }

        fragment float4 fragment_main() {
            return float4(0.7333, 0.5137, 0.2667, 1);
        }
    """
}

final class MetalViewController: UIViewController {
    
    @IBOutlet private weak var errorLabel: UILabel!
    
    private var mtlDevice: MTLDevice!
    private var mtlView: MTKView!
    private var meshBufferAllocator: MTKMeshBufferAllocator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .darkGray
        
        self.errorLabel.isHidden = true
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            self.errorLabel.isHidden = false
            print("MTLCreateSystemDefaultDevice Error: isSimulator = \(UIDevice.isSimulator)")
            return
        }
        
        self.mtlDevice = device
        
        self.mtlView = MTKView(frame: self.view.bounds, device: self.mtlDevice)
        self.mtlView.clearColor = MTLClearColor(red: 0.33, green: 0.33, blue: 0.33, alpha: 1.0)
        
        self.meshBufferAllocator = MTKMeshBufferAllocator(device: self.mtlDevice)
        
        let ratio: Float = Float(self.view.bounds.width / self.view.bounds.height)
        let mdlMesh = MDLMesh(sphereWithExtent: [0.75, 0.75*ratio, 0.75], segments: [24, 24], inwardNormals: false, geometryType: .triangles, allocator: self.meshBufferAllocator)
        
        guard let commanyQueue = device.makeCommandQueue() else {
            preconditionFailure()
        }
        
        do {
            let mesh = try MTKMesh(mesh: mdlMesh, device: self.mtlDevice)
            let library = try self.mtlDevice.makeLibrary(source: Shader.main, options: nil)
            
            let vertexFunction = library.makeFunction(name: "vertex_main")
            let fragmentFunction = library.makeFunction(name: "fragment_main")
            
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
            
            let piplineState = try self.mtlDevice.makeRenderPipelineState(descriptor: descriptor)
            
            guard let commandBuffer = commanyQueue.makeCommandBuffer(), let passDescriptor = self.mtlView.currentRenderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
                preconditionFailure()
            }
            
            renderEncoder.setRenderPipelineState(piplineState)
            
            renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer, offset: 0, index: 0)
            
            guard let subMesh = mesh.submeshes.first else {
                preconditionFailure()
            }
            
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: subMesh.indexCount, indexType: subMesh.indexType, indexBuffer: subMesh.indexBuffer.buffer, indexBufferOffset: 0)
            
            renderEncoder.endEncoding()
            
            guard let drawable = self.mtlView.currentDrawable else {
                preconditionFailure()
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
            
        } catch {
            print("render \(error)")
        }
        
        self.view.addSubview(self.mtlView)
        
        ///
        print("[Metal]: Device: \(String(describing: self.mtlDevice))")
    }


}

