private var boost:Bool = false

@objc (MSHFView) public class MSHFView: UIView, MSHFAudioDelegate, MSHFAudioProcessingDelegate {
    private var cachedLength = 0
    internal var cachedNumberOfPoints = 0
    private var silentSince: Int64 = 0
    private var MSHFHidden = false

    @objc private var shouldUpdate = false
    @objc internal var disableBatterySaver = false
    private var _autoHide = true
    @objc internal var autoHide: Bool {
        get {
            _autoHide
        }
        set(value) {
            if value && (silentSince < (Int64(Date().timeIntervalSince1970) - 1)) {
                MSHFHidden = true
                alpha = 0.0
            } else {
                MSHFHidden = false
                alpha = 1.0
            }
        }
    }
    
    @objc internal var numberOfPoints = 0
    @objc internal var gain: Float = 0.0
    @objc internal var limiter = 0.0
    @objc internal var waveOffset: CGFloat = 0.0
    @objc internal var sensitivity: CGFloat = 0.0
    @objc internal var displayLink: CADisplayLink?
    internal var points: UnsafeMutablePointer<CGPoint> = UnsafeMutablePointer<CGPoint>.allocate(capacity: 0)
    internal var siriEnabled = false
    internal var waveColor: UIColor?
    internal var subwaveColor: UIColor?
    internal var subSubwaveColor: UIColor?
    private var audioSource: MSHFAudioSource?
    @objc internal var audioProcessing: MSHFAudioProcessing?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override convenience init(frame: CGRect) {
      self.init(frame: frame, audioSource: MSHFAudioSourceASS())
    }

    @objc public init(frame: CGRect, audioSource: MSHFAudioSource?) {

      super.init(frame: frame)

      numberOfPoints = 8
      waveOffset = 0
      gain = 0
      limiter = 0
      sensitivity = 1
      disableBatterySaver = false
      autoHide = false
      MSHFHidden = autoHide

      if autoHide {
          self.alpha = 0.0
      } else {
          self.alpha = 1.0
      }

      if let audioSource = audioSource {
          self.audioSource = audioSource
      }
      self.audioSource?.delegate = self

      audioProcessing = MSHFAudioProcessing(bufferSize: 1024)
      audioProcessing!.delegate = self
      audioProcessing!.fft = true

      initializeWaveLayers()

      shouldUpdate = true

      cachedLength = numberOfPoints
      points = unsafeBitCast(malloc(MemoryLayout<CGPoint>.size * Int(numberOfPoints)), to: UnsafeMutablePointer<CGPoint>.self)

      let MSHFPrefsFile = "/var/mobile/Library/Preferences/com.ryannair05.mitsuhaforever.plist"
      if let prefs = NSDictionary(contentsOfFile:MSHFPrefsFile) {
          boost = prefs["MSHFAirpodsSensBoost"] as? Bool ?? false
      }
    }

  @objc internal func stop() {
    if audioSource?.isRunning ?? true && !disableBatterySaver {
        audioSource?.stop()
    }
  }

  @objc internal func start() {
    // let identifier = ProcessInfo.processInfo.processName
    // if (identifier == "Music") || (identifier == "Spotify") || NSClassFromString("SBMediaController")?.sharedInstance().isPlaying ?? false || FileManager.default.fileExists(atPath: "/Library/MobileSubstrate/DynamicLibraries/RoadRunner.dylib") {
        audioSource?.start()
    // }
  }

  internal func initializeWaveLayers() {

  }

  internal func resetWaveLayers() {

  }

  internal func configureDisplayLink() {
    displayLink = CADisplayLink(target: self, selector: #selector(redraw))

    displayLink!.add(to: RunLoop.current,forMode: .default)
    displayLink!.isPaused = false

    displayLink!.preferredFramesPerSecond = 60
  }

  @objc public func updateWave(_ waveColor: UIColor,subwaveColor: UIColor) {

  }

  @objc public func updateWave(_ waveColor: UIColor,subwaveColor: UIColor,subSubwaveColor: UIColor) {

  }

  @objc internal func redraw() {
       if autoHide {
          if silentSince < (Int64(Date().timeIntervalSince1970) - 1) {
              if MSHFHidden {
                  MSHFHidden = false
                  UIView.animate(
                      withDuration: 0.5,
                      animations: {
                          self.alpha = 0.0
                      })
              }
          } else if !MSHFHidden {
              MSHFHidden = true
              UIView.animate(
                  withDuration: 0.5,
                  animations: {
                      self.alpha = 1.0
                })
          }
      } 
    }

  public func updateBuffer(_ bufferData: UnsafeMutablePointer<Float>, withLength length: Int32) {
      if autoHide {
          for i in 0..<(length / 4) {
              if Double(bufferData[Int(i)]) > 0.000005 || Double(bufferData[Int(i)]) < -0.000005 {
                  silentSince = Int64(Date().timeIntervalSince1970)
                  break
              }
          }
      }

      audioProcessing?.process(bufferData, withLength: length)
  }

  internal func setSampleData(_ data: UnsafeMutablePointer<Float>?, length: Int32) {
      let compressionRate = Int(length) / Int(numberOfPoints)
      let pixelFixer: Float = (Float(bounds.size.width) / Float(numberOfPoints))

      if cachedLength != numberOfPoints {
          free(points)
          points =  unsafeBitCast(malloc(MemoryLayout<CGPoint>.size * Int(numberOfPoints)), to: UnsafeMutablePointer<CGPoint>.self)
          cachedLength = numberOfPoints
      }

      if boost {

          for i in 0..<numberOfPoints {
              points[i].x = CGFloat(i) * CGFloat(pixelFixer)
              var pureValue: CGFloat = CGFloat(data![i * compressionRate] * gain)

              if pureValue == 0.0 {
                  points[i].y = waveOffset
                  continue
              }

              if limiter != 0 {
                  pureValue = abs(Float(pureValue)) < Float(limiter)
                      ? pureValue
                      : (pureValue < 0 ? -1 * CGFloat(limiter) : CGFloat(limiter))
              }

              points[i].y = (pureValue * sensitivity)

              while abs(points[i].y) < 1.5 {
                  points[i].y *= 25
              }
              points[i].y += waveOffset
          }
      }
      else {
        for i in 0..<numberOfPoints {
          points[i].x = CGFloat(i) * CGFloat(pixelFixer)
          var pureValue: CGFloat = CGFloat(data![i * compressionRate] * gain)

          if limiter != 0 {
              pureValue = abs(Float(pureValue)) < Float(limiter)
                  ? pureValue
                  : (pureValue < 0 ? -1 * CGFloat(limiter) : CGFloat(limiter))
          }

          points[i].y = (pureValue * sensitivity) + waveOffset

          if points[i].y.isNaN {
              points[i].y = waveOffset
          }
        }
      }
    }
}