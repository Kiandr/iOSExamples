/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for camera interface.
*/

import UIKit
import AVFoundation
import Metal
import CoreVideo
import Photos
import MobileCoreServices

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
	// MARK: Properties
	
	@IBOutlet weak private var cameraButton: UIButton!
	
	@IBOutlet weak private var photoButton: UIButton!
	
	@IBOutlet weak private var resumeButton: UIButton!
	
	@IBOutlet weak private var cameraUnavailableLabel: UILabel!
	
	@IBOutlet weak private var previewView: FilterMetalView!
	
	private enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}
	
	private var setupResult: SessionSetupResult = .success
	
	private let session = AVCaptureSession()
	
	private var isSessionRunning = false
	
	private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem) // Communicate with the session and other session objects on this queue.
	/*
		In a multi-threaded producer consumer system it's generally a good idea to make sure that producers do not get starved of CPU time by their consumers.
		The VideoDataOutput frames come from a high priority queue, and downstream the preview uses the main queue.
	*/
	private let videoDataOutputQueue = DispatchQueue(label: "video data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

	private let photoOutput = AVCapturePhotoOutput()
	
	private let videoDataOutput = AVCaptureVideoDataOutput()
	
	private var videoDeviceInput: AVCaptureDeviceInput!
	
	private var textureCache: CVMetalTextureCache!
	
	private var previewFilter = RosyCIRenderer()
	
	private var photoFilter = RosyCIRenderer()

	private let syncQueue = DispatchQueue(label: "synchronization queue", attributes: [], autoreleaseFrequency: .workItem) // Synchronize access to currentFilteredPixelBuffer.

	private var renderingEnabled = true
	
	private var currentFilteredPixelBuffer: CVPixelBuffer?
	
	private let processingQueue = DispatchQueue(label: "photo processing queue", attributes: [], autoreleaseFrequency: .workItem)
	
	private let videoDeviceDiscoverySession = AVCaptureDeviceDiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified)!
	
	private var statusBarOrientation: UIInterfaceOrientation = .portrait
	
	// MARK: View Controller Life Cycle
	
	override func viewDidLoad() {
		super.viewDidLoad()

		// Disable UI. The UI is enabled if and only if the session starts running.
		cameraButton.isEnabled = false
		photoButton.isEnabled = false
		
		let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(focusAndExposeTap))
		previewView.addGestureRecognizer(gestureRecognizer)
		
		// Check video authorization status, video access is required
		switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
			case .authorized:
				// The user has previously granted access to the camera
				break
				
			case .notDetermined:
				/*
					The user has not yet been presented with the option to grant video access
					We suspend the session queue to delay session setup until the access request has completed
				*/
				sessionQueue.suspend()
				AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { granted in
					if !granted {
						self.setupResult = .notAuthorized
					}
					self.sessionQueue.resume()
				})
				
			default:
				// The user has previously denied access
				setupResult = .notAuthorized
		}
		
		// Initialize texture cache for metal rendering
		let metalDevice = MTLCreateSystemDefaultDevice()
		var textCache: CVMetalTextureCache?
		if (CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice!, nil, &textCache) != kCVReturnSuccess) {
			print("Unable to allocate texture cache")
			setupResult = .configurationFailed
		}
		else {
			textureCache = textCache
		}
		
		/*
			Setup the capture session.
			In general it is not safe to mutate an AVCaptureSession or any of its
			inputs, outputs, or connections from multiple threads at the same time.
			
			Why not do all of this on the main queue?
			Because AVCaptureSession.startRunning() is a blocking call which can
			take a long time. We dispatch session setup to the sessionQueue so
			that the main queue isn't blocked, which keeps the UI responsive.
		*/
		sessionQueue.async {
			self.configureSession()
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		let interfaceOrientation = UIApplication.shared.statusBarOrientation
		statusBarOrientation = interfaceOrientation

		sessionQueue.async {
			switch self.setupResult {
				case .success:
					// Only setup observers and start the session running if setup succeeded
					self.addObservers()
					if let photoOrientation = interfaceOrientation.videoOrientation {
						self.photoOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation = photoOrientation
					}
					let videoOrientation = self.videoDataOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation
					let videoDevicePosition = self.videoDeviceInput.device.position
					let rotation = FilterMetalView.Rotation(with: interfaceOrientation, videoOrientation: videoOrientation, cameraPosition: videoDevicePosition)
					DispatchQueue.main.async {
						self.previewView.setDeferDrawingUntilNewTexture = true
						self.previewView.mirroring = (videoDevicePosition == .front)
						if let rotation = rotation {
							self.previewView.rotation = rotation
						}
						self.videoDataOutputQueue.async {
							self.renderingEnabled = true
						}
					}
					self.session.startRunning()
					self.isSessionRunning = self.session.isRunning
				
				case .notAuthorized:
					DispatchQueue.main.async {
						let message = NSLocalizedString("AVCamPhotoFilter doesn't have permission to use the camera, please change privacy settings", comment: "Alert message when the user has denied access to the camera")
						let alertController = UIAlertController(title: "AVCamPhotoFilter", message: message, preferredStyle: .alert)
						alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
						alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .`default`, handler: { action in
							UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
						}))
						
						self.present(alertController, animated: true, completion: nil)
					}
					
				case .configurationFailed:
					DispatchQueue.main.async {
						let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
						let alertController = UIAlertController(title: "AVCamPhotoFilter", message: message, preferredStyle: .alert)
						alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
						
						self.present(alertController, animated: true, completion: nil)
					}
			}
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		videoDataOutputQueue.async {
			self.renderingEnabled = false
		}
		sessionQueue.async {
			if self.setupResult == .success {
				self.session.stopRunning()
				self.isSessionRunning = self.session.isRunning
				self.removeObservers()
			}
		}
		
		super.viewWillDisappear(animated)
	}
	
	func didEnterBackground(notification: NSNotification) {
		// Free up resources
		videoDataOutputQueue.async {
			self.renderingEnabled = false
			self.previewFilter.reset()
			self.syncQueue.sync {
				self.currentFilteredPixelBuffer = nil
			}
		}
		processingQueue.async {
			self.photoFilter.reset()
		}
	}
	
	func willEnterForground(notification: NSNotification) {
		videoDataOutputQueue.async {
			self.renderingEnabled = true
		}
	}
	
	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .all
	}

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)

		coordinator.animate(
			alongsideTransition: { context in
				let interfaceOrientation = UIApplication.shared.statusBarOrientation
				self.statusBarOrientation = interfaceOrientation
				self.sessionQueue.async {
					/*
						The photo orientation is based on the interface orientation.
						You could also set the orientation of the photo connection based on the device orientation by observing UIDeviceOrientationDidChangeNotification.
					*/
					if let photoOrientation = interfaceOrientation.videoOrientation {
						self.photoOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation = photoOrientation
					}
					let videoOrientation = self.videoDataOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation
					if let rotation = FilterMetalView.Rotation(with: interfaceOrientation, videoOrientation: videoOrientation, cameraPosition: self.videoDeviceInput.device.position) {
						DispatchQueue.main.async {
							if rotation != self.previewView.rotation {
								self.previewView.setDeferDrawingUntilNewTexture = true
								self.previewView.rotation = rotation
							}
						}
					}
				}
			}, completion: nil
		)
	}
	
	// MARK: KVO and Notifications
	
	private var sessionRunningContext = 0
	
	private func addObservers() {
		NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
		
		session.addObserver(self, forKeyPath: "running", options: NSKeyValueObservingOptions.new, context: &sessionRunningContext)
		
		/*
			A session can only run when the app is full screen. It will be interrupted
			in a multi-app layout, introduced in iOS 9, see also the documentation of
			AVCaptureSessionInterruptionReason. Add observers to handle these session
			interruptions and show a preview is paused message. See the documentation
			of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
		*/
		NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
		NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
		NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
	}
	
	private func removeObservers() {
		NotificationCenter.default.removeObserver(self)
		
		session.removeObserver(self, forKeyPath: "running", context: &sessionRunningContext)
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if context == &sessionRunningContext {
			let newValue = change?[.newKey] as AnyObject?
			guard let isSessionRunning = newValue?.boolValue else { return }
			DispatchQueue.main.async {
				self.cameraButton.isEnabled = (isSessionRunning && self.videoDeviceDiscoverySession.devices.count > 1)
				self.photoButton.isEnabled = isSessionRunning
			}
		}
		else {
			super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
		}
	}
	
	// MARK: Session Management
	
	// Call this on the session queue
	private func configureSession() {
		if setupResult != .success {
			return
		}
		
		guard let videoDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .unspecified) else {
			print("Could not find any video device")
			setupResult = .configurationFailed
			return
		}
		do {
			videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
		}
		catch {
			print("Could not create video device input: \(error)")
			setupResult = .configurationFailed
			return
		}
		
		session.beginConfiguration()
		session.sessionPreset = AVCaptureSessionPresetPhoto
		
		guard session.canAddInput(videoDeviceInput) else {
			print("Could not add video device input to the session")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}
		
		session.addInput(videoDeviceInput)
		if session.canAddOutput(videoDataOutput) {
			session.addOutput(videoDataOutput)
			videoDataOutput.alwaysDiscardsLateVideoFrames = true
			videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
			videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
		}
		else {
			print("Could not add video data output to the session")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}
		if session.canAddOutput(photoOutput) {
			session.addOutput(photoOutput)
		}
		else {
			print("Could not add photo output to the session")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}
		
		session.commitConfiguration()
	}
	
	private func focus(with focusMode: AVCaptureFocusMode, exposureMode: AVCaptureExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
		sessionQueue.async {
			guard let videoDevice = self.videoDeviceInput.device else {
				return
			}
			
			do {
				try videoDevice.lockForConfiguration()
				if videoDevice.isFocusPointOfInterestSupported && videoDevice.isFocusModeSupported(focusMode) {
					videoDevice.focusPointOfInterest = devicePoint
					videoDevice.focusMode = focusMode
				}
				
				if videoDevice.isExposurePointOfInterestSupported && videoDevice.isExposureModeSupported(exposureMode) {
					videoDevice.exposurePointOfInterest = devicePoint
					videoDevice.exposureMode = exposureMode
				}
				
				videoDevice.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
				videoDevice.unlockForConfiguration()
			}
			catch {
				print("Could not lock device for configuration: \(error)")
			}
		}
	}
	
	@IBAction private func focusAndExposeTap(_ gestureRecognizer: UIGestureRecognizer) {
		let location = gestureRecognizer.location(in: previewView)
		guard let texturePoint = previewView.texturePointForView(point: location) else {
			return
		}
		
		let textureRect = CGRect(origin: texturePoint, size: CGSize.zero)
		let deviceRect = videoDataOutput.metadataOutputRectOfInterest(for: textureRect)
		focus(with: .autoFocus, exposureMode: .autoExpose, at: deviceRect.origin, monitorSubjectAreaChange: true)
	}
	
	func subjectAreaDidChange(notification: NSNotification) {
		let devicePoint = CGPoint(x: 0.5, y: 0.5)
		focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
	}
	
	func sessionWasInterrupted(notification: NSNotification) {
		// In iOS 9 and later, the userInfo dictionary contains information on why the session was interrupted.
		if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?, let reasonIntegerValue = userInfoValue.integerValue, let reason = AVCaptureSessionInterruptionReason(rawValue: reasonIntegerValue) {
			print("Capture session was interrupted with reason \(reason)")
			
			if reason == .videoDeviceInUseByAnotherClient {
				// Simply fade-in a button to enable the user to try to resume the session running.
				resumeButton.isHidden = false
				resumeButton.alpha = 0.0
				UIView.animate(withDuration: 0.25) {
					self.resumeButton.alpha = 1.0
				}
			}
			else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
				// Simply fade-in a label to inform the user that the camera is unavailable.
				cameraUnavailableLabel.isHidden = false
				cameraUnavailableLabel.alpha = 0.0
				UIView.animate(withDuration: 0.25) {
					self.cameraUnavailableLabel.alpha = 1.0
				}
			}
		}
	}
	
	func sessionInterruptionEnded(notification: NSNotification) {
		if !resumeButton.isHidden {
			UIView.animate(withDuration: 0.25,
				animations: {
					self.resumeButton.alpha = 0
				}, completion: { finished in
					self.resumeButton.isHidden = true
				}
			)
		}
		if !cameraUnavailableLabel.isHidden {
			UIView.animate(withDuration: 0.25,
				animations: {
					self.cameraUnavailableLabel.alpha = 0
				}, completion: { finished in
					self.cameraUnavailableLabel.isHidden = true
				}
			)
		}
	}
	
	func sessionRuntimeError(notification: NSNotification) {
		guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
			return
		}
		
		let error = AVError(_nsError: errorValue)
		print("Capture session runtime error: \(error)")
		
		/*
			Automatically try to restart the session running if media services were
			reset and the last start running succeeded. Otherwise, enable the user
			to try to resume the session running.
		*/
		if error.code == .mediaServicesWereReset {
			sessionQueue.async {
				if self.isSessionRunning {
					self.session.startRunning()
					self.isSessionRunning = self.session.isRunning
				}
				else {
					DispatchQueue.main.async {
						self.resumeButton.isHidden = false
					}
				}
			}
		}
		else {
			resumeButton.isHidden = false
		}
	}
	
	@IBAction private func resumeInterruptedSession(_ sender: UIButton) {
		sessionQueue.async {
			/*
				The session might fail to start running. A failure to start the session running will be communicated via
				a session runtime error notification. To avoid repeatedly failing to start the session
				running, we only try to restart the session running in the session runtime error handler
				if we aren't trying to resume the session running.
			*/
			self.session.startRunning()
			self.isSessionRunning = self.session.isRunning
			if !self.session.isRunning {
				DispatchQueue.main.async {
						let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
						let alertController = UIAlertController(title: "AVCamPhotoFilter", message: message, preferredStyle: .alert)
						let cancelAction = UIAlertAction(title:NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
						alertController.addAction(cancelAction)
						self.present(alertController, animated: true, completion: nil)
				}
			}
			else {
				DispatchQueue.main.async {
					self.resumeButton.isHidden = true
				}
			}
		}
	}
	
	@IBAction private func changeCamera(_ sender: UIButton) {
		cameraButton.isEnabled = false
		photoButton.isEnabled = false
		videoDataOutputQueue.sync {
			self.renderingEnabled = false
			self.previewFilter.reset()
		}
		syncQueue.sync {
			self.currentFilteredPixelBuffer = nil
		}
		previewView.setDeferDrawingUntilNewTexture = true
		let interfaceOrientation = self.statusBarOrientation

		sessionQueue.async {
			guard let currentVideoDevice = self.videoDeviceInput.device else {
				return
			}
			var preferredPosition = AVCaptureDevicePosition.unspecified
			let currentPhotoOrientation = self.photoOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation
			
			switch currentVideoDevice.position {
				case .unspecified, .front:
					preferredPosition = .back
				
				case .back:
					preferredPosition = .front
			}
			
			let devices = self.videoDeviceDiscoverySession.devices
			if let videoDevice = devices?.filter({ $0.position == preferredPosition }).first {
				var videoDeviceInput: AVCaptureDeviceInput
				do {
					videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
				}
				catch {
					print("Could not create video device input: \(error)")
					self.videoDataOutputQueue.async {
						self.renderingEnabled = true
					}
					return
				}
				self.session.beginConfiguration()
					
				// Remove the existing device input first, since using the front and back camera simultaneously is not supported.
				self.session.removeInput(self.videoDeviceInput)
				
				if self.session.canAddInput(videoDeviceInput) {
					NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: currentVideoDevice)
					NotificationCenter.default.addObserver(self, selector: #selector(self.subjectAreaDidChange), name: NSNotification.Name.AVCaptureDeviceSubjectAreaDidChange, object: videoDevice)

					self.session.addInput(videoDeviceInput)
					self.videoDeviceInput = videoDeviceInput
				}
				else {
					print("Could not add video device input to the session")
					self.session.addInput(self.videoDeviceInput)
				}
				self.photoOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation = currentPhotoOrientation
				
				self.session.commitConfiguration()
			}
			
			let videoPosition = self.videoDeviceInput.device.position
			let videoOrientation = self.videoDataOutput.connection(withMediaType: AVMediaTypeVideo).videoOrientation
			let rotation = FilterMetalView.Rotation(with: interfaceOrientation, videoOrientation: videoOrientation, cameraPosition: videoPosition)
			
			DispatchQueue.main.async {
				self.cameraButton.isEnabled = true
				self.photoButton.isEnabled = true
				self.previewView.mirroring = (videoPosition == .front)
				if let rotation = rotation {
					self.previewView.rotation = rotation
				}
				self.videoDataOutputQueue.async {
					self.renderingEnabled = true
				}
			}
		}
	}
	
	@IBAction private func capturePhoto(_ photoButton: UIButton) {
		let photoSettings = AVCapturePhotoSettings(format: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
		sessionQueue.async {
			self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
		}
	}
	
	// MARK: Video Data Output Delegate
	
	func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
		if !renderingEnabled {
			return
		}
		guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
			return
		}

		if previewFilter.outputFormatDescription == nil {
			/*
				outputRetainedBufferCountHint is the number of pixel buffers we expect to hold on to from the renderer. This value informs the renderer how to size its buffer pool and how many pixel buffers to preallocate.
				- Allow 3 frames of latency to cover the dispatch_async call.
			*/
			previewFilter.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
		}
		guard let filteredPixelBuffer = previewFilter.render(pixelBuffer: pixelBuffer) else {
			DispatchQueue.main.async {
				CVMetalTextureCacheFlush(self.textureCache, 0)
			}
			return
		}
		syncQueue.sync {
			self.currentFilteredPixelBuffer = filteredPixelBuffer
		}
		DispatchQueue.main.async {
			var pixelBuffer: CVPixelBuffer?
			self.syncQueue.sync {
				pixelBuffer = self.currentFilteredPixelBuffer
				self.currentFilteredPixelBuffer = nil
			}
			guard let previewPixelBuffer = pixelBuffer else {
				return
			}
			let width = CVPixelBufferGetWidth(previewPixelBuffer)
			let height = CVPixelBufferGetHeight(previewPixelBuffer)
			
			var cvTextureOut: CVMetalTexture?
			CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, previewPixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTextureOut)
			guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
				print("Failed to create preview texture")
				return
			}
			self.previewView.texture = texture
		}
	}
	
	// MARK: Photo Output Delegate
	
	func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
		guard let photoSampleBuffer = photoSampleBuffer else {
			print("Error capturing photo: \(error)")
			return
		}
		guard let pixelPhotoBuffer = CMSampleBufferGetImageBuffer(photoSampleBuffer), let formatDescription = CMSampleBufferGetFormatDescription(photoSampleBuffer) else {
			print("Error capturing photo: Missing pixel buffer")
			return
		}
		
		let attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, photoSampleBuffer, kCMAttachmentMode_ShouldPropagate)
	
		processingQueue.async {
			if self.photoFilter.outputFormatDescription == nil || !CMFormatDescriptionEqual(self.photoFilter.inputFormatDescription, formatDescription) {
				self.photoFilter.prepare(with: formatDescription, outputRetainedBufferCountHint: 2)
			}

			guard let renderedPixelPhotoBuffer = self.photoFilter.render(pixelBuffer: pixelPhotoBuffer) else {
				print("Failed to apply filter to photo")
				return
			}
		
			guard let jpegData = CameraViewController.jpegData(withPixelBuffer: renderedPixelPhotoBuffer, attachments: attachments) else {
				return
			}
			
			PHPhotoLibrary.requestAuthorization { status in
				if status == .authorized {
					PHPhotoLibrary.shared().performChanges({
						let creationRequest = PHAssetCreationRequest.forAsset()
						creationRequest.addResource(with: .photo, data: jpegData, options: nil)
						}, completionHandler: { success, error in
							if let error = error {
								print("Error occurred while saving photo to photo library: \(error)")
							}
						}
					)
				}
			}
		}
	}
	
	// MARK: Utilities
	
	private class func jpegData(withPixelBuffer pixelBuffer: CVPixelBuffer, attachments: CFDictionary?) -> Data? {
		let ciContext = CIContext()
		let renderedCIImage = CIImage(cvImageBuffer: pixelBuffer)
		guard let renderedCGImage = ciContext.createCGImage(renderedCIImage, from: renderedCIImage.extent) else {
			print("Failed to create CGImage")
			return nil
		}
		
		guard let data = CFDataCreateMutable(kCFAllocatorDefault, 0) else {
			print("Create CFData error!")
			return nil
		}

		guard let cgImageDestination = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else {
			print("Create CGImageDestination error!")
			return nil
		}

		CGImageDestinationAddImage(cgImageDestination, renderedCGImage, attachments)
		if CGImageDestinationFinalize(cgImageDestination) {
			return data as Data
		}
		print("Finalizing CGImageDestination error!")
		return nil
	}
}

extension UIInterfaceOrientation {
	var videoOrientation: AVCaptureVideoOrientation? {
		switch self {
			case .portrait: return .portrait
			case .portraitUpsideDown: return .portraitUpsideDown
			case .landscapeLeft: return .landscapeLeft
			case .landscapeRight: return .landscapeRight
			default: return nil
		}
	}
}

extension FilterMetalView.Rotation {
	init?(with interfaceOrientation: UIInterfaceOrientation, videoOrientation: AVCaptureVideoOrientation, cameraPosition: AVCaptureDevicePosition) {
		/*
			Calculate the rotation between the videoOrientation and the interfaceOrientation.
			The direction of the rotation depends upon the camera position.
		*/
		switch videoOrientation {
			case .portrait:
				switch interfaceOrientation {
					case .landscapeRight:
						if cameraPosition == .front {
							self = .rotate90Degrees
						}
						else {
							self = .rotate270Degrees
						}
					
					case .landscapeLeft:
						if cameraPosition == .front {
							self = .rotate270Degrees
						}
						else {
							self = .rotate90Degrees
						}
						
					case .portrait:
						self = .rotate0Degrees
						
					case .portraitUpsideDown:
						self = .rotate180Degrees
						
					default: return nil
				}
			case .portraitUpsideDown:
				switch interfaceOrientation {
					case .landscapeRight:
						if cameraPosition == .front {
							self = .rotate270Degrees
						}
						else {
							self = .rotate90Degrees
						}
						
					case .landscapeLeft:
						if cameraPosition == .front {
							self = .rotate90Degrees
						}
						else {
							self = .rotate270Degrees
						}
						
					case .portrait:
						self = .rotate180Degrees
						
					case .portraitUpsideDown:
						self = .rotate0Degrees
						
					default: return nil
				}
			
		case .landscapeRight:
			switch interfaceOrientation {
				case .landscapeRight:
					self = .rotate0Degrees
				
				case .landscapeLeft:
					self = .rotate180Degrees
				
				case .portrait:
					if cameraPosition == .front {
						self = .rotate270Degrees
					}
					else {
						self = .rotate90Degrees
					}
				
				case .portraitUpsideDown:
					if cameraPosition == .front {
						self = .rotate90Degrees
					}
					else {
						self = .rotate270Degrees
					}
				
				default: return nil
			}
			
			case .landscapeLeft:
				switch interfaceOrientation {
					case .landscapeLeft:
						self = .rotate0Degrees
						
					case .landscapeRight:
						self = .rotate180Degrees
						
					case .portrait:
						if cameraPosition == .front {
							self = .rotate90Degrees
						}
						else {
							self = .rotate270Degrees
						}
						
					case .portraitUpsideDown:
						if cameraPosition == .front {
							self = .rotate270Degrees
						}
						else {
							self = .rotate90Degrees
						}
						
					default: return nil
				}
		}
	}
}
