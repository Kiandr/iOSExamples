/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	PlayerViewController is a subclass of UIViewController which manages the UIView used for playback and also sets up AVPictureInPictureController for video playback in picture in picture.
*/

import AVFoundation
import UIKit
import AVKit

/*
	KVO context used to differentiate KVO callbacks for this class versus other
	classes in its class hierarchy.
*/
private var playerViewControllerKVOContext = 0

/*
    Manages the view used for playback and sets up the `AVPictureInPictureController`
    for video playback in picture in picture.
*/
class PlayerViewController: UIViewController, AVPictureInPictureControllerDelegate {
	// MARK: - Properties
	
	lazy var player = AVPlayer()
	
    var pictureInPictureController: AVPictureInPictureController!
	
	var playerView: PlayerView {
		return self.view as! PlayerView
	}
	
	var playerLayer: AVPlayerLayer? {
		return playerView.playerLayer
	}
	
	var playerItem: AVPlayerItem? = nil {
		didSet {
			/* 
				If needed, configure player item here before associating it with a player
				(example: adding outputs, setting text style rules, selecting media options)
			*/
			player.replaceCurrentItem(with: playerItem)
			
			if playerItem == nil {
				cleanUpPlayerPeriodicTimeObserver()
			}
			else {
				setupPlayerPeriodicTimeObserver()
			}
		}
	}
	
	var timeObserverToken: AnyObject?
	
	// Attempt to load and test these asset keys before playing
	static let assetKeysRequiredToPlay = [
		"playable",
		"hasProtectedContent"
	]
	
	var currentTime: Double {
		get {
			return CMTimeGetSeconds(player.currentTime())
		}
		
		set {
			let newTime = CMTimeMakeWithSeconds(newValue, 1)
			player.seek(to: newTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
		}
	}
	
	var duration: Double {
		guard let currentItem = player.currentItem else { return 0.0 }
		
		return CMTimeGetSeconds(currentItem.duration)
	}
	
	// MARK: - IBOutlets
	
	@IBOutlet weak var timeSlider: UISlider!
	@IBOutlet weak var playPauseButton: UIBarButtonItem!
	@IBOutlet weak var pictureInPictureButton: UIBarButtonItem!
	@IBOutlet weak var toolbar: UIToolbar!
	
	// MARK: - IBActions
	
	@IBAction func playPauseButtonWasPressed(_ sender: UIButton) {
		if player.rate != 1.0 {
			// Not playing foward, so play.
			
			if currentTime == duration {
				// At end, so got back to beginning.
				currentTime = 0.0
			}
			
			player.play()
		}
		else {
			// Playing, so pause.
			player.pause()
		}
	}
	
	@IBAction func togglePictureInPictureMode(_ sender: UIButton) {
		/*
			Toggle picture in picture mode.
		
			If active, stop picture in picture and return to inline playback.
		
			If not active, initiate picture in picture.
		
			Both these calls will trigger delegate callbacks which should be used
			to set up UI appropriate to the state of the application.
		*/
		if pictureInPictureController.isPictureInPictureActive {
			pictureInPictureController.stopPictureInPicture()
		}
		else {
			pictureInPictureController.startPictureInPicture()
		}
	}
	
	@IBAction func timeSliderDidChange(_ sender: UISlider) {
		currentTime = Double(sender.value)
	}
	
	// MARK: - View Handling
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		/*
            Update the UI when these player properties change.
		
            Use the context parameter to distinguish KVO for our particular observers
			and not those destined for a subclass that also happens
			to be observing these properties.
		*/
		addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.duration), options: [.new, .initial], context: &playerViewControllerKVOContext)
		addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.rate), options: [.new, .initial], context: &playerViewControllerKVOContext)
		addObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.status), options: [.new, .initial], context: &playerViewControllerKVOContext)
		
		playerView.playerLayer.player = player
		
		setupPlayback()
		
		timeSlider.translatesAutoresizingMaskIntoConstraints = true
		timeSlider.autoresizingMask = .flexibleWidth
		
		// Set the UIImage provided by AVPictureInPictureController as the image of the pictureInPictureButton
		let backingButton = pictureInPictureButton.customView as! UIButton
		backingButton.setImage(AVPictureInPictureController.pictureInPictureButtonStartImage(compatibleWith: nil), for: UIControlState.normal)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		
		player.pause()
		
		cleanUpPlayerPeriodicTimeObserver()
		
		removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.duration), context: &playerViewControllerKVOContext)
		removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.rate), context: &playerViewControllerKVOContext)
		removeObserver(self, forKeyPath: #keyPath(PlayerViewController.player.currentItem.status), context: &playerViewControllerKVOContext)
	}
	
	private func setupPlayback() {
		
		let movieURL = Bundle.main.url(forResource: "samplemovie", withExtension: "mov")!
		let asset = AVURLAsset(url: movieURL, options: nil)
		/*
			Create a new `AVPlayerItem` and make it our player's current item.
		
			Using `AVAsset` now runs the risk of blocking the current thread (the
			main UI thread) whilst I/O happens to populate the properties. It's prudent
			to defer our work until the properties we need have been loaded.
		
			These properties can be passed in at initialization to `AVPlayerItem`,
			which are then loaded automatically by `AVPlayer`.
		*/
		self.playerItem = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: PlayerViewController.assetKeysRequiredToPlay)
	}
	
	private func setupPlayerPeriodicTimeObserver() {
		// Only add the time observer if one hasn't been created yet.
		guard timeObserverToken == nil else { return }
		
		let time = CMTimeMake(1, 1)
		
		// Use a weak self variable to avoid a retain cycle in the block.
		timeObserverToken = player.addPeriodicTimeObserver(forInterval: time, queue:DispatchQueue.main) {
			[weak self] time in
			self?.timeSlider.value = Float(CMTimeGetSeconds(time))
		} as AnyObject?
	}
	
	private func cleanUpPlayerPeriodicTimeObserver() {
		if let timeObserverToken = timeObserverToken {
			player.removeTimeObserver(timeObserverToken)
			self.timeObserverToken = nil
		}
	}
	
	private func setupPictureInPicturePlayback() {
		/*
			Check to make sure Picture in Picture is supported for the current
			setup (application configuration, hardware, etc.).
		*/
		if AVPictureInPictureController.isPictureInPictureSupported() {
			/*
				Create `AVPictureInPictureController` with our `playerLayer`.
				Set self as delegate to receive callbacks for picture in picture events.
				Add observer to be notified when pictureInPicturePossible changes value,
				so that we can enable `pictureInPictureButton`.
			*/
			pictureInPictureController = AVPictureInPictureController(playerLayer: playerView.playerLayer)
			pictureInPictureController.delegate = self
			
			addObserver(self, forKeyPath: #keyPath(PlayerViewController.pictureInPictureController.pictureInPicturePossible), options: [.new, .initial], context: &playerViewControllerKVOContext)
		}
		else {
			pictureInPictureButton.isEnabled = false
		}
	}
	
	// MARK: - AVPictureInPictureControllerDelegate
	
	func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		/* 
			If your application contains a video library or other interesting views,
			this delegate callback can be used to dismiss player view controller
			and to present the user with a selection of videos to play next.
		*/
		toolbar.isHidden = true
	}
	
	func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
		/* 
			Picture in picture mode will stop soon, show the toolbar.
		*/
		toolbar.isHidden = false
	}
	
	func pictureInPictureControllerFailedToStartPictureInPicture(pictureInPictureController: AVPictureInPictureController, withError error: NSError) {
		/*
			Picture in picture failed to start with an error, restore UI to continue
			inline playback. Show the toolbar.
		*/
		toolbar.isHidden = false
		handle(error: error)
	}
	
	// MARK: - KVO
	
	// Update our UI when `player` or `player.currentItem` changes
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		// Only respond to KVO changes that are specific to this view controller class.
		guard context == &playerViewControllerKVOContext else {
           super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
           return
		}
		
		if keyPath == #keyPath(PlayerViewController.player.currentItem.duration) {
			// Update `timeSlider` and enable/disable controls when `duration` > 0.0
			
			/* 
				Handle `NSNull` value for `NSKeyValueChangeNewKey`, i.e. when
				`player.currentItem` is nil.
			*/
			let newDuration: CMTime
			if let newDurationAsValue = change?[NSKeyValueChangeKey.newKey] as? NSValue {
				newDuration = newDurationAsValue.timeValue
			}
			else {
				newDuration = kCMTimeZero
			}
			let hasValidDuration = newDuration.isNumeric && newDuration.value != 0
			let newDurationSeconds = hasValidDuration ? CMTimeGetSeconds(newDuration) : 0.0
			
			timeSlider.maximumValue = Float(newDurationSeconds)
			
			let currentTime = CMTimeGetSeconds(player.currentTime())
			timeSlider.value = hasValidDuration ? Float(currentTime) : 0.0
			
			playPauseButton.isEnabled = hasValidDuration
			timeSlider.isEnabled = hasValidDuration
		}
		else if keyPath == #keyPath(PlayerViewController.player.rate) {
			// Update playPauseButton type.
			let newRate = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).doubleValue

			let style: UIBarButtonSystemItem = newRate == 0.0 ? .play : .pause
			let newPlayPauseButton = UIBarButtonItem(barButtonSystemItem: style, target: self, action: #selector(PlayerViewController.playPauseButtonWasPressed(_:)))
			
			// Replace the current button with the updated button in the toolbar.
			var items = toolbar.items!
			
			if let playPauseItemIndex = items.index(of: playPauseButton) {
				items[playPauseItemIndex] = newPlayPauseButton
				
				playPauseButton = newPlayPauseButton
				
				toolbar.setItems(items, animated: false)
			}
		}
		else if keyPath == #keyPath(PlayerViewController.player.currentItem.status) {
			// Display an error if status becomes Failed
			
			/* 
				Handle `NSNull` value for `NSKeyValueChangeNewKey`, i.e. when 
				`player.currentItem` is nil.
			*/
			let newStatus: AVPlayerItemStatus
			if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
				newStatus = AVPlayerItemStatus(rawValue: newStatusAsNumber.intValue)!
			}
			else {
				newStatus = .unknown
			}
			
			if newStatus == .failed {
                handle(error: player.currentItem?.error as NSError?)
			}
			else if newStatus == .readyToPlay {
				
				if let asset = player.currentItem?.asset {
					
					/* 
						First test whether the values of `assetKeysRequiredToPlay` we need
						have been successfully loaded.
					*/
					for key in PlayerViewController.assetKeysRequiredToPlay {
						var error: NSError?
                        if asset.statusOfValue(forKey: key, error: &error) == .failed {
                            self.handle(error: error)
							return
						}
					}
					
					if !asset.isPlayable || asset.hasProtectedContent {
						// We can't play this asset.
                        self.handle(error: nil)
						return
					}
					
					/*
						The player item is ready to play,
						setup picture in picture.
					*/
					if pictureInPictureController == nil {
						setupPictureInPicturePlayback()
					}
				}
			}
		}
		else if keyPath == #keyPath(PlayerViewController.pictureInPictureController.pictureInPicturePossible) {
			/* 
				Enable the `pictureInPictureButton` only if `pictureInPicturePossible`
				is true. If this returns false, it might mean that the application
				was not configured as shown in the AppDelegate.
			*/
			let newValue = change?[NSKeyValueChangeKey.newKey] as! NSNumber
			let isPictureInPicturePossible: Bool = newValue.boolValue

			pictureInPictureButton.isEnabled = isPictureInPicturePossible
		}

	}
	
	// Trigger KVO for anyone observing our properties affected by player and player.currentItem
	override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
		let affectedKeyPathsMappingByKey: [String: Set<String>] = [
			"duration":     [#keyPath(PlayerViewController.player.currentItem.duration)],
			"rate":         [#keyPath(PlayerViewController.player.rate)]
		]
		
		return affectedKeyPathsMappingByKey[key] ?? super.keyPathsForValuesAffectingValue(forKey: key)
	}
	
	// MARK: - Error Handling
	
	func handle(error: NSError?) {
		let alertController = UIAlertController(title: "Error", message: error?.localizedDescription, preferredStyle: .alert)
		
		let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
		
		alertController.addAction(alertAction)
		
		present(alertController, animated: true, completion: nil)
	}
}

