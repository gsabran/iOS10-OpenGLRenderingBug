//
//  PlayerController.swift
//  TestVideoTextureBug
//
//  Created by Guillaume Sabran on 9/14/16.
//  Copyright © 2016 Guillaume Sabran. All rights reserved.
//

import Foundation
import UIKit

import SceneKit
import SpriteKit
import AVFoundation
import CoreGraphics

class PlayerController: SCNScene {

	var scnView: SCNView!
	var scnScene: SCNScene!
	var mainNode: SCNNode!
	var videoPlayer: AVPlayer!
	var videoOutput: AVPlayerItemVideoOutput!
	var playerItem: AVPlayerItem?
	var canvasScene: SKScene!
	var imageLayer = CALayer()

	convenience init(view: SCNView) {
		self.init()
		setUpScene(on: view)
		setUpVideo()
	}

	private func setUpScene(on view: SCNView) {
		//scnView = SCNView(frame: view.bounds, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.openGLES2])
		scnView = view
		scnView.frame = view.bounds
		scnView.showsStatistics = true
		scnView.allowsCameraControl = true
		scnView.scene = self
		scnView.isPlaying = true

		print("scnView renderingAPI is metal", scnView.renderingAPI == SCNRenderingAPI.metal)
		print("scnView renderingAPI is opengl", scnView.renderingAPI == SCNRenderingAPI.openGLES2)

		scnView.delegate = self


		let cameraNode = SCNNode()
		cameraNode.camera = SCNCamera()
		cameraNode.camera?.zNear = 0.1
		cameraNode.camera?.zFar = 150.0
		cameraNode.position = SCNVector3(x: 0.0, y: 0.0, z: 25.0)
		rootNode.addChildNode(cameraNode)

		mainNode = SCNNode()
		mainNode.geometry = SCNBox(width: 5.0, height: 5.0, length: 5.0, chamferRadius: 0.0)
		mainNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
		rootNode.addChildNode(mainNode)
	}

	private func setUpVideo() {
		let item = AVPlayerItem(url: URL(fileURLWithPath: Bundle.main.path(forResource: "test", ofType: "mp4")!))
		item.addObserver(
			self,
			forKeyPath: "status",
			options: .new,
			context: nil
		)

		NotificationCenter.default
			.addObserver(
				self,
				selector: #selector(restartVideo),
				name: .AVPlayerItemDidPlayToEndTime,
				object: item
		)
		videoPlayer = AVPlayer(playerItem: item)

		let pixelBufferAttributes = [
			kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB),
			kCVPixelBufferCGImageCompatibilityKey as String: true,
			kCVPixelBufferOpenGLESCompatibilityKey as String: true
		]
		videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferAttributes)
		item.add(videoOutput)

		playerItem = item
	}

	override func observeValue(forKeyPath keyPath: String?,
	                           of object: Any?,
	                           change: [NSKeyValueChangeKey : Any]?,
	                           context: UnsafeMutableRawPointer?) {

		if let player = videoPlayer,
			let object = object as? AVPlayerItem,
			let item = player.currentItem, object == item,
			let key = keyPath, key == "status" {

			// Checks whether the video has buffered enough, and starts to play.
			if item.status == .readyToPlay, let size = item.asset.tracks(
				withMediaType: AVMediaTypeVideo).first?.naturalSize {
				self.videoIsReadyToPlay(item: item, size: size)
			}
		}
	}

	func currentPixelBuffer() -> CVPixelBuffer? {
		guard let playerItem = playerItem, playerItem.status == .readyToPlay else {
			print("no pixel buffer")
			return nil
		}

		let currentTime = playerItem.currentTime()
		return videoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil)
	}

	private func videoIsReadyToPlay(item: AVPlayerItem, size: CGSize) {
		// Creates a 2D node that streams the video player output.
		/*let videoNode = SKVideoNode(avPlayer: videoPlayer)
		videoNode.position = CGPoint(x: size.width/2, y: size.height/2)
		videoNode.size = size

		// Creates a 2D canvas scene to map it as texture for the sky.
		canvasScene = SKScene()
		canvasScene.backgroundColor = UIColor.black
		canvasScene.size = size
		canvasScene.addChild(videoNode)*/

		let material = SCNMaterial()
		material.diffuse.contents = imageLayer
		mainNode.geometry?.materials = [ material ]

		videoPlayer.play()
	}

	func updateFrame() {
		print("updateFrame")
		if let pixelBuffer = currentPixelBuffer() {
			CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)));

			let width = CVPixelBufferGetWidth(pixelBuffer)
			let height = CVPixelBufferGetHeight(pixelBuffer)
			let pixels = CVPixelBufferGetBaseAddress(pixelBuffer)!

			let pixelWrapper = CGDataProvider(dataInfo: nil, data: pixels, size: CVPixelBufferGetDataSize(pixelBuffer), releaseData: { _, _, _ in
				// print("releaseData")
				return
			})!

			// Get a color-space ref... can't this be done only once?
			let colorSpaceRef = CGColorSpaceCreateDeviceRGB()

			// Get a CGImage from the data (the CGImage is used in the drawLayer: delegate method above)

			let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
			if let currentCGImage = CGImage(width: width,
			                                height: height,
			                                bitsPerComponent: 8,
			                                bitsPerPixel: 32,
			                                bytesPerRow: 4 * width,
			                                space: colorSpaceRef, bitmapInfo: [.byteOrder32Big, bitmapInfo],
			                                provider: pixelWrapper,
			                                decode: nil,
			                                shouldInterpolate: false,
			                                intent: .defaultIntent) {
				print("has set image for content")
				self.imageLayer.contents = currentCGImage
			} else {
				print("could not got current image")
			}

			// Clean up
			CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
		}
	}


	func restartVideo() {
		videoPlayer.seek(to: CMTime(seconds: 0.0, preferredTimescale: 1))
		videoPlayer.play()
	}
}

extension PlayerController: SCNSceneRendererDelegate {
	func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
		updateFrame()
	}
}
