@objc (MSHFConfig) final public class MSHFConfig: NSObject {

    @objc private var enabled = false
    private var application: String?
    @objc private var style = 0
    @objc private var colorMode = 0
    private var enableDynamicGain = false
    private var enableAutoUIColor = false
    @objc private var enableCoverArtBugFix = false
    private var disableBatterySaver = false
    private var enableFFT = false
    private var enableAutoHide = false
    private var gain = 0.0
    private var limiter = 0.0
    private var waveColor: UIColor?
    private var subwaveColor: UIColor?
    private var subSubwaveColor: UIColor?
    private var calculatedColor: UIColor?
    internal var numberOfPoints: UInt = 0
    private var fps: CGFloat = 0.0
    @objc private var waveOffset: CGFloat = 0.0
    @objc private var waveOffsetOffset: CGFloat = 0.0
    private var sensitivity: CGFloat = 0.0
    private var dynamicColorAlpha: CGFloat = 0.0
    private var barSpacing: CGFloat = 0.0
    private var barCornerRadius: CGFloat = 0.0
    private var lineThickness: CGFloat = 0.0
    private var ignoreColorFlow = false
    private var enableCircleArtwork = false
    @objc private var view: MSHFView?

    init(dictionary dict: NSDictionary) {
        super.init()
        setDictionary(dict)
        let MSHFPreferencesChanged = "com.ryannair05.mitsuhaforever/ReloadPrefs"
        let darwinNotificationCenter = DarwinNotificationsManager.sharedInstance()
        darwinNotificationCenter!.register(forNotificationName: MSHFPreferencesChanged, callback: {
            self.reload()
        })
    }

    @objc public func initializeView(withFrame frame: CGRect) {
        var superview: UIView? = nil
        var index: Int = 0

        if view != nil {
            if view?.superview != nil {
                superview = view!.superview
                index = superview?.subviews.firstIndex(of: view!) ?? NSNotFound
            }

            view!.stop()
            view!.removeFromSuperview()
        }

        switch style {
            case 1:
                view = MSHFBarView(frame: frame)
                (view as? MSHFBarView)?.barSpacing = barSpacing
                (view as? MSHFBarView)?.barCornerRadius = barCornerRadius
            case 2:
                view = MSHFLineView(frame: frame)
                (view as? MSHFLineView)?.lineThickness = lineThickness
            case 3:
                view = MSHFDotView(frame: frame)
                (view as? MSHFDotView)?.barSpacing = barSpacing
            case 4:
                view = MSHFSiriView(frame: frame)
            default:
                view = MSHFJelloView(frame: frame)
        }

        if superview != nil {
            if index == NSNotFound {
                superview!.addSubview(view!)
            } else {
                superview!.insertSubview(view!, at: index)
            }
        }

        configureView()
    }

    private func configureView() {
        view!.autoHide = enableAutoHide
        view!.displayLink?.preferredFramesPerSecond = Int(fps)
        view!.numberOfPoints = Int(numberOfPoints)
        view!.waveOffset = waveOffset + waveOffsetOffset
        view!.gain = Float(gain)
        view!.limiter = limiter
        view!.sensitivity = sensitivity
        view!.audioProcessing?.fft = enableFFT
        view!.disableBatterySaver = disableBatterySaver
        view!.siriEnabled = colorMode == 1

        if colorMode == 2 && waveColor != nil {
            if style == 4 {
                view!.updateWave(
                    waveColor!.copy() as! UIColor,
                    subwaveColor: waveColor!.copy() as! UIColor,
                    subSubwaveColor: waveColor!.copy() as! UIColor)
            } else {
                view!.updateWave(
                    waveColor!.copy() as! UIColor,
                    subwaveColor: waveColor!.copy() as! UIColor)
            }
        } else if colorMode == 1 && waveColor != nil && subwaveColor != nil && subSubwaveColor != nil {
            view!.updateWave(
                waveColor!.copy() as! UIColor,
                subwaveColor: subwaveColor!.copy() as! UIColor,
                subSubwaveColor: subSubwaveColor!.copy() as! UIColor)
        } else if calculatedColor != nil {
            view!.updateWave(
                calculatedColor!.copy() as! UIColor,
                subwaveColor: calculatedColor!.copy() as! UIColor)
        }
    }

    private func getAverageColor(from image: UIImage?, withAlpha alpha: Double) -> UIColor {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        let ctx = UIGraphicsGetCurrentContext()
        ctx!.interpolationQuality = .medium

        image?.draw(in: CGRect(x: 0, y: 0, width: 1, height: 1), blendMode: .copy, alpha: 1)

        let data : [UInt8] = Array(UnsafeBufferPointer(start: ctx?.data?.bindMemory(to: UInt8.self, capacity: 4), count: 4))

        let color = UIColor(
            red: CGFloat(data[2]) / 255.0, 
            green: CGFloat(data[1]) / 255.0,
            blue: CGFloat(data[0]) / 255.0,
            alpha: CGFloat(alpha))

        UIGraphicsEndImageContext()
        return color
    }

    @objc public func colorizeView(_ image: UIImage?) {
        if view == nil {
            return
        }
        if colorMode != 2 {
            var color = waveColor!
            var scolor = waveColor!
            var sscolor = waveColor!

            if colorMode == 1 {
                color = UIColor(red: 1.0,
                    green: 0.0,
                    blue: 0.0,
                    alpha: dynamicColorAlpha)
                scolor = UIColor(red: 0.0,
                    green: 1.0,
                    blue: 0.0,
                    alpha: dynamicColorAlpha)
                sscolor = UIColor(red: 0.0,
                    green: 0.0,
                    blue: 1.0,
                    alpha: dynamicColorAlpha)
            } else {
                color = getAverageColor(from: image,
                    withAlpha: Double(dynamicColorAlpha))
                calculatedColor = color
            }

            if colorMode == 1 {
                view!.updateWave(color,
                    subwaveColor: scolor,
                    subSubwaveColor: sscolor)
            } else if style == 4 {
                view!.updateWave(color,
                    subwaveColor: color,
                    subSubwaveColor: color)
            }
            else {
                view!.updateWave(color,
                    subwaveColor: color)
            }
        } else {
            let color = waveColor!
            if style == 4 {
                view!.updateWave(color,
                    subwaveColor: color,
                    subSubwaveColor: color)
            } else {
                view!.updateWave(color,
                    subwaveColor: color)
            }
        }
    }

    private func setDictionary(_ dict: NSDictionary?) {
        application = (dict?["application"] as! String)
        enabled = dict?["enabled"] as? Bool ?? true

        enableDynamicGain = dict?["enableDynamicGain"] as? Bool ?? false
        style = dict?["style"] as? Int ?? 0
        colorMode = dict?["colorMode"] as? Int ?? 0
        enableAutoUIColor = dict?["enableAutoUIColor"] as? Bool ?? true
        ignoreColorFlow = dict?["ignoreColorFlow"] as? Bool ?? false
        enableCircleArtwork = dict?["enableCircleArtwork"] as? Bool ?? false
        enableCoverArtBugFix = dict?["enableCoverArtBugFix"] as? Bool ?? false
        disableBatterySaver = dict?["disableBatterySaver"] as? Bool ?? false
        enableFFT = dict?["enableFFT"] as? Bool ?? false
        enableAutoHide = dict?["enableAutoHide"] as? Bool ?? true

        if dict?["waveColor"] != nil {
            if dict!["waveColor"] is UIColor {
                waveColor = (dict!["waveColor"] as! UIColor)
            } else if dict!["waveColor"] is NSString {
                waveColor = LCPParseColorString(
                    dict?["waveColor"] as? String,
                    "#000000:0.5")
            } else {
                waveColor = UIColor.black.withAlphaComponent(0.5)
            }
        } else {
            waveColor = UIColor.black.withAlphaComponent(0.5)
        }

      if dict?["subwaveColor"] != nil {
            if dict!["subwaveColor"] is UIColor {
                subwaveColor = (dict!["subwaveColor"] as! UIColor)
            } else if dict!["subwaveColor"] is NSString {
                subwaveColor = LCPParseColorString(
                    dict!["subwaveColor"] as? String,
                    "#000000:0.5")
            } else {
                subwaveColor = UIColor.black.withAlphaComponent(0.5)
            }
        } else {
            subwaveColor = UIColor.black.withAlphaComponent(0.5)
        }
      if dict?["subSubwaveColor"] != nil {
            if dict?["subSubwaveColor"] is UIColor {
                subwaveColor = (dict?["subSubwaveColor"] as! UIColor)
            } else if dict?["subSubwaveColor"] is NSString {
                subwaveColor = LCPParseColorString(
                    dict?["subSubwaveColor"] as? String,
                    "#000000:0.5")
            } else {
                subwaveColor = UIColor.black.withAlphaComponent(0.5)
            }
        } else {
            subwaveColor = UIColor.black.withAlphaComponent(0.5)
        }
      gain = dict?["gain"] as? Double ?? 50
      limiter = dict?["limiter"] as? Double ?? 0
      numberOfPoints = dict?["numberOfPoints"] as? UInt ?? 8
      sensitivity = dict?["sensitivity"] as? CGFloat ?? 1
      dynamicColorAlpha = dict?["dynamicColorAlpha"] as? CGFloat ?? 0.6

      barSpacing = dict?["barSpacing"] as? CGFloat ?? 5
      barCornerRadius = dict?["barCornerRadius"] as? CGFloat ?? 0
      lineThickness = dict?["lineThickness"] as? CGFloat ?? 5

      waveOffset = dict?["waveOffset"] as? CGFloat ?? 0
      waveOffset = (dict?["negateOffset"] as? Bool ?? false
            ? waveOffset * -1
            : waveOffset)

        fps = dict?["fps"] as? CGFloat ?? 24
    }

    private class func parseConfig(forApplication name: String?) -> NSDictionary {
        var prefs: [AnyHashable : Any] = [:]
        prefs["application"] = name

        let MSHFPrefsFile = "/var/mobile/Library/Preferences/com.ryannair05.mitsuhaforever.plist"

        if let file = NSDictionary(contentsOfFile: MSHFPrefsFile) as Dictionary? {
            for key in file.keys {
                guard let key = key as? String else {
                    continue
                }
                prefs[key] = file[key as NSObject]
            }
        }

        for key in prefs.keys {
            guard let key = key as? String else {
                continue
            }
            let removedKey = key.replacingOccurrences(of: "MSHF\(name ?? "")", with: "")
            let lowerCaseKey = "\((removedKey as NSString).substring(to: 1).lowercased())\((removedKey as NSString).substring(from: 1))"

            prefs[lowerCaseKey] = prefs[key]
        }

        prefs["gain"] = prefs["gain"] ?? NSNumber(value: 50)
        prefs["subwaveColor"] = prefs["waveColor"]
        prefs["subSubwaveColor"] = prefs["waveColor"]
        prefs["waveOffset"] = prefs["waveOffset"] ?? NSNumber(value: 0)

        return prefs as NSDictionary
    }

    private func reload() {
        let oldStyle = style
        setDictionary(MSHFConfig.parseConfig(forApplication: application))
        if view != nil {
            if style != oldStyle {
                initializeView(withFrame: view!.frame)
                view!.start()
            } else {
                configureView()
            }
        }
    }

    @objc public class func loadConfig(forApplication name: String?) -> MSHFConfig? {
        return MSHFConfig(
            dictionary: MSHFConfig.parseConfig(forApplication: name))
    }
}