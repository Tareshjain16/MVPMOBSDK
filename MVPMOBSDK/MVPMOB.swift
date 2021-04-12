//
//  MVPMOB.swift
//  MVPMOBSDK
//
//  Created by CDN on 18/02/21.
//

import Foundation
import cmbSDK

public protocol MVPMOBDelegate {
    
    func didConnectionStateChange(status : Bool)
    func didReceiveScanData(arryScanData : [[String : Any]])
    func didReceieveConnectionError(error : Error)
}

public class MVPMOB: NSObject, CMBReaderDeviceDelegate {
    
    public var delegate : MVPMOBDelegate?
    
    var readerDevice: CMBReaderDevice!
    var isScanning:Bool = false
    var controller : UIViewController?
    //----------------------------------------------------------------------------
    // If usePreconfiguredDeviceType is true, then the app will create a reader
    // using the values of deviceClass/cameraMode. Otherwise, the app presents
    // a pick list for the user to select either MX-1xxx, MX-100, or the built-in
    // camera.
    //----------------------------------------------------------------------------
    let usePreconfiguredDevice = false
    var deviceClass:DataManDeviceClass = DataManDeviceClass_MX
    var cameraMode:CDMCameraMode = CDMCameraMode.noAimer
    
    
    public class  var sharedManager : MVPMOB {
        
        struct Static {
            static var instance : MVPMOB? = nil
        }
        if !(Static.instance != nil) {
            
            Static.instance = MVPMOB()
        }
        
        return Static.instance!
    }
    
   /* private override init() {
        super.init()
        print("Add observer")
        // Add our observer for when the app becomes active (to reconnect if necessary)
        NotificationCenter.default.addObserver(self, selector: #selector(self.appBecameActive), name:UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    
    deinit {
        print("Remove observer")
        NotificationCenter.default.removeObserver(self)
    }*/
    
    // MARK: OBSERVER METHODS
    
    //----------------------------------------------------------------------------
    // When an applicaiton is suspended, the connection to the scanning device is
    // automatically closed by iOS; thus when we are resumed (become active) we
    // have to restore the connection (assuming we had one). This is the observer
    // we will use to do this.
    //----------------------------------------------------------------------------
    @objc func appBecameActive() {
        if readerDevice != nil && readerDevice.availability == CMBReaderAvailibilityAvailable && readerDevice.connectionState != CMBConnectionStateConnecting && readerDevice.connectionState != CMBConnectionStateConnected {
            readerDevice.connect(completion: { error in
                if error != nil {
                    // handle connection error
                    self.delegate?.didReceieveConnectionError(error: error!)
                }
            })
        }
    }
    
    //MARK: Public class
    public func initializeDevice(viewController : UIViewController){
        self.controller = viewController
        self.checkCameraAccess()
    }
    
    public func startScanning(){
        self.readerDevice?.startScanning()
        isScanning = !isScanning
    }
    
    public func stopScanning(){
        if isScanning {
            self.readerDevice?.stopScanning()
        }
        isScanning = !isScanning
        
    }
    
    public func disconnectDevice(){
        if (self.readerDevice != nil) &&
            self.readerDevice!.connectionState == CMBConnectionStateConnected {
            self.readerDevice?.stopScanning()
        }
        
        // If we have connection to a reader, disconnect
        if (self.readerDevice != nil) &&
            self.readerDevice!.connectionState == CMBConnectionStateConnected {
            self.readerDevice!.disconnect()
        }
    }
    
    //MARK: customization of overlay
    public  func setViewportVisible(_ value: Bool) {
        MWOverlay.setViewportVisible(value)
    }
    
    
    public func setTargetRectVisible(_ value: Bool) {
        MWOverlay.setTargetRectVisible(value)
    }
    
    
    public func setBlinkingLineVisible(_ value: Bool) {
        MWOverlay.setBlinkingLineVisible(value)
    }
    
    public func setViewportLineWidth(_ value: Float) {
        MWOverlay.setViewportLineWidth(value)
    }
    
    public func setBlinkingLineWidth(_ value: Float) {
        
        MWOverlay.setBlinkingLineWidth(value)
    }
    
    public func setLocationLineWidth(_ value: Float) {
        MWOverlay.setLocationLineWidth(value)
    }
    
    public func setTargetRectLineWidth(_ value: Float) {
        MWOverlay.setTargetRectLineWidth(value)
    }
    
    public func setViewportAlpha(_ value: Float) {
        MWOverlay.setViewportAlpha(value)
    }
    
    public func setTargetRectLineAlpha(_ value: Float) {
        MWOverlay.setTargetRectLineAlpha(value)
    }
    
    public func  setViewportLineAlpha(_ value: Float) {
        
        MWOverlay.setViewportLineAlpha(value)
    }
    
    public func setBlinkingLineAlpha(_ value: Float) {
        MWOverlay.setBlinkingLineAlpha(value)
    }
    
    public func setBlinkingSpeed(_ value: Float) {
        
        MWOverlay.setBlinkingSpeed(value)
    }
    
    public func  setViewportLineRGBColor(_ value: Int32) {
        MWOverlay.setViewportLineRGBColor(value)
    }
    
    public func setBlinkingLineRGBColor(_ value: Int32) {
        MWOverlay.setBlinkingLineRGBColor(value)
    }
    
    public func setTargetRectLineRGBColor(_ value: Int32) {
        MWOverlay.setTargetRectLineRGBColor(value)
    }
    
    public func setLocationLineRGBColor(_ value: Int32) {
        MWOverlay.setLocationLineRGBColor(value)
    }
    
    public func setViewportLineUIColor(_ value: UIColor?) {
        MWOverlay.setViewportLineUIColor(value)
    }
    
    public func setBlinkingLineUIColor(_ value: UIColor?) {
        
        MWOverlay.setBlinkingLineUIColor(value)
    }
    
    public func setTargetRectLineUIColor(_ value: UIColor?) {
        
        MWOverlay.setTargetRectLineUIColor(value)
    }
    
    public func setLocationLineUIColor(_ value: UIColor?) {
        MWOverlay.setLocationLineUIColor(value)
    }

    // MARK: UPDATE Status
    
    
    func connectDevice(){
        self.deviceClass = DataManDeviceClass_PhoneCamera
        self.cameraMode = CDMCameraMode.noAimer
        self.createReaderDevice()
    }
    
    func updateUIByConnectionState() {
        if self.readerDevice != nil && self.readerDevice.connectionState == CMBConnectionStateConnected{
            print("  Connected  ")
            self.delegate?.didConnectionStateChange(status: true)
            
        }
        else{
            print("  Disconnected  ")
            self.delegate?.didConnectionStateChange(status: false)
        }
    }
    
    
    func createReaderDevice() {
        self.readerDevice?.disconnect()
        
        switch self.deviceClass {
        
        //***************************************************************************************
        // Create a camera reader (for either the built-in camera or an MX-100)
        //
        // NOTE: if we are connecting to a MX-100 (cameraMode == kCDMCameraModeActiveAimer) then
        //       no license key is needed. However, if we're scanning using the built-in camera
        //       of the mobile phone or tablet, then the SDK requires a license key. Refer to
        //       the SDK's documentation on obtaining a license key as well as the methods for
        //       passing the key to the SDK (in this example, we're relying on an entry in
        //       plist.info--there are also readerOfDeviceCamera methods where it can be passed
        //       as a parameter).
        //***************************************************************************************
        case DataManDeviceClass_PhoneCamera:
            self.readerDevice = CMBReaderDevice.readerOfDeviceCamera(with: self.cameraMode, previewOptions:CDMPreviewOption.init(rawValue: 0), previewView:nil)
            readerDevice.delegate = self
            break
        default:
            break
        }
        
        self.readerDevice.delegate = self
        self.connectToReaderDevice()
        self.updateUIByConnectionState()
    }
    
    // MARK: CONNECT - DISCONNECT
    
    // Before the self.readerDevice can be configured or used, a connection needs to be established
    func connectToReaderDevice(){
        if self.readerDevice.availability == CMBReaderAvailibilityAvailable && self.readerDevice.connectionState == CMBConnectionStateDisconnected {
            
            if self.readerDevice.deviceClass == DataManDeviceClass_PhoneCamera && self.cameraMode == CDMCameraMode.activeAimer {
                print("Connecting")
            }
            
            self.readerDevice.connect(completion: { (error:Error?) in
                if error != nil {
                    self.delegate?.didReceieveConnectionError(error: error!)
                }
            })
        }
    }
    
    func configureReaderDevice() {
        //----------------------------------------------
        // Explicitly enable the symbologies we need
        //----------------------------------------------
        
        self.readerDevice.setSymbology(CMBSymbologyDotcode, enabled: true, completion: {(_ error: Error?) -> Void in
            if error != nil {
                // Failed to enable that symbology, Possible causes are: reader disconnected, out of battery or cable unplugged, or symbology not supported by the current readerDevice
                print("FALIED TO ENABLE [CMBSymbologyDotcode], \(error!.localizedDescription)")
            }
        })
        
        self.readerDevice.setSymbology(CMBSymbologyDataMatrix, enabled:true, completion: {(_ error: Error?) -> Void in
            if error != nil {
                print("FALIED TO ENABLE [CMBSymbologyDataMatrix], \(error!.localizedDescription)")
            }
        })
        self.readerDevice.setSymbology(CMBSymbologyC128, enabled:true, completion: {(_ error: Error?) -> Void in
            if error != nil {
                print("FALIED TO ENABLE [CMBSymbologyC128], \(error!.localizedDescription)")
            }
        })
        self.readerDevice.setSymbology(CMBSymbologyUpcEan, enabled:true, completion: {(_ error: Error?) -> Void in
            if error != nil {
                print("FALIED TO ENABLE [CMBSymbologyUpcEan], \(error!.localizedDescription)")
            }
        })
        
        //-------------------------------------------------------
        // Explicitly disable symbologies we know we don't need
        //-------------------------------------------------------
        self.readerDevice.setSymbology(CMBSymbologyCodaBar, enabled:false, completion: {(_ error: Error?) -> Void in
            if error != nil {
                print("FALIED TO ENABLE [CMBSymbologyCodaBar], \(error!.localizedDescription)")
            }
        })
        self.readerDevice.setSymbology(CMBSymbologyC93, enabled:false, completion: {(_ error: Error?) -> Void in
            if error != nil {
                print("FALIED TO ENABLE [CMBSymbologyC93], \(error!.localizedDescription)")
            }
        })
        
        //---------------------------------------------------------------------------
        // Below are examples of sending DMCC commands and getting the response
        //---------------------------------------------------------------------------
        self.readerDevice.dataManSystem().sendCommand("GET DEVICE.TYPE", withCallback: { response in
            if response?.status == DMCC_STATUS_NO_ERROR {
                print("Device type: \(response?.payload ?? "")")
            }
        })
        
        self.readerDevice.dataManSystem().sendCommand("GET DEVICE.FIRMWARE-VER", withCallback: { response in
            if response?.status == DMCC_STATUS_NO_ERROR {
                print("Firmware version: \(response?.payload ?? "")")
            }
        })
        
        //---------------------------------------------------------------------------
        // We are going to explicitly turn off image results (although this is the
        // default). The reason is that enabling image results with an MX-1xxx
        // scanner is not recommended unless your application needs the scanned
        // image--otherwise scanning performance can be impacted.
        //---------------------------------------------------------------------------
        self.readerDevice.imageResultEnabled = false
        self.readerDevice.svgResultEnabled = false
        
        //---------------------------------------------------------------------------
        // Device specific configuration examples
        //---------------------------------------------------------------------------
        
        //---------------------------------------------------------------------------
        // Phone/tablet/MX-100
        //---------------------------------------------------------------------------
        if self.readerDevice.deviceClass == DataManDeviceClass_PhoneCamera {
            // Set the SDK's decoding effort to level 3
            self.readerDevice.dataManSystem().sendCommand("SET DECODER.EFFORT 3")
            
            //---------------------------------------------------------------------------
            // MX-1xxx
            //---------------------------------------------------------------------------
        } else if self.readerDevice.deviceClass == DataManDeviceClass_MX {
            //---------------------------------------------------------------------------
            // Save our configuration to non-volatile memory (on an MX-1xxx; for the
            // MX-100/phone, this has no effect). However, if the MX hibernates or is
            // rebooted, our settings will be retained.
            //---------------------------------------------------------------------------
            self.readerDevice.dataManSystem().sendCommand("CONFIG.SAVE")
        }
    }
    
    // MARK: MX Delegate methods
    
    // This is called when a MX-1xxx device has became available (USB cable was plugged, or MX device was turned on),
    // or when a MX-1xxx that was previously available has become unavailable (USB cable was unplugged, turned off due to inactivity or battery drained)
    public func availabilityDidChange(ofReader reader: CMBReaderDevice) {
        print("DeviceSelectorVC availabilityDidChangeOfReader")
        print("readerAvailable: \(reader.availability == CMBReaderAvailibilityAvailable)")
        
        
        if (reader.availability != CMBReaderAvailibilityAvailable) {
            print("Device became unavailable")
        } else if (reader.availability == CMBReaderAvailibilityAvailable) {
            self.connectToReaderDevice()
        }
    }
    
    // This is called when a connection with the self.readerDevice has been changed.
    // The self.readerDevice is usable only in the "CMBConnectionStateConnected" state
    public func connectionStateDidChange(ofReader reader: CMBReaderDevice) {
        isScanning = false
        
        if self.readerDevice.connectionState == CMBConnectionStateConnected {
            // We just connected, so now configure the device how we want it
            self.configureReaderDevice()
            
        } else if self.readerDevice.connectionState == CMBConnectionStateDisconnected {
        }
        
        self.updateUIByConnectionState()
    }
    
    // This is called after scanning has completed, either by detecting a barcode, canceling the scan by using the on-screen button or a hardware trigger button, or if the scanning timed-out
    public func didReceiveReadResult(fromReader reader: CMBReaderDevice, results readResults: CMBReadResults!) {
        isScanning = false
        
        if (readResults.subReadResults != nil) && readResults.subReadResults.count > 0 {
            if let result = readResults.subReadResults as? [CMBReadResult] {
                // print("Scan Count == \(result.count)")
                let aryScan = self.createCustomArray(readResult: result)
                self.delegate?.didReceiveScanData(arryScanData: aryScan)
            }
        } else if readResults.readResults.count > 0 {
            if let result = readResults.readResults.first as? CMBReadResult {
                // print("Scan Count == \([result].count)")
                let aryScan = self.createCustomArray(readResult: [result])
                self.delegate?.didReceiveScanData(arryScanData: aryScan)
            }
        }
    }
    
    
    func createCustomArray(readResult : [CMBReadResult]) -> [[String : Any]] {
        var aryCustom = [[String : Any]]()
        for resultData in readResult{
            var dictCustom = [String : Any]()
            if resultData.goodRead {
                dictCustom["goodRead"] = resultData.goodRead
                dictCustom["readString"] = resultData.readString ?? ""
                dictCustom["image"] = resultData.image
                dictCustom["imageGraphics"] = resultData.imageGraphics
                dictCustom["xml"] = resultData.xml
                dictCustom["symbology"] = self.displayStringForSymbology(resultData.symbology)
                dictCustom["parsedText"] = resultData.parsedText
                dictCustom["parsedJSON"] = resultData.parsedJSON
                dictCustom["isGS1"] = resultData.isGS1
                aryCustom.append(dictCustom)
            }
        }
        return aryCustom
    }
    // MARK: UTILITY
    
    // Get a readable string from a CMBSymbology value
    func displayStringForSymbology(_ symbology_in: CMBSymbology?) -> String?
    {
        let symbology = (symbology_in != nil) ? symbology_in! : CMBSymbologyUnknown
        
        switch symbology {
        case CMBSymbologyDataMatrix: return "DATAMATRIX";
        case CMBSymbologyQR: return "QR";
        case CMBSymbologyC128: return "C128";
        case CMBSymbologyUpcEan: return "UPC-EAN";
        case CMBSymbologyC39: return "C39";
        case CMBSymbologyC93: return "C93";
        case CMBSymbologyC11: return "C11";
        case CMBSymbologyI2o5: return "I2O5";
        case CMBSymbologyCodaBar: return "CODABAR";
        case CMBSymbologyEanUcc: return "EAN-UCC";
        case CMBSymbologyPharmaCode: return "PHARMACODE";
        case CMBSymbologyMaxicode: return "MAXICODE";
        case CMBSymbologyPdf417: return "PDF417";
        case CMBSymbologyMicropdf417: return "MICROPDF417";
        case CMBSymbologyDatabar: return "DATABAR";
        case CMBSymbologyPostnet: return "POSTNET";
        case CMBSymbologyPlanet: return "PLANET";
        case CMBSymbologyFourStateJap: return "4STATE-JAP";
        case CMBSymbologyFourStateAus: return "4STATE-AUS";
        case CMBSymbologyFourStateUpu: return "4STATE-UPU";
        case CMBSymbologyFourStateImb: return "4STATE-IMB";
        case CMBSymbologyVericode:return "VERICODE";
        case CMBSymbologyRpc: return "RPC";
        case CMBSymbologyMsi: return "MSI";
        case CMBSymbologyAzteccode: return "AZTECCODE";
        case CMBSymbologyDotcode: return "DOTCODE";
        case CMBSymbologyC25: return "C25";
        case CMBSymbologyC39ConvertToC32: return "C39-CONVERT-TO-C32";
        case CMBSymbologyOcr: return "OCR";
        case CMBSymbologyFourStateRmc: return "4STATE-RMC";
        case CMBSymbologyTelepen: return "TELEPEN";
        default: return "UNKNOWN";
        }
    }
    
    
    // MARK: Camera class
    func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied:
            print("Denied, request permission from settings")
            showAlert(title: "Unable to access the Camera", message: "To enable access, go to Settings > Privacy > Camera and turn on Camera access for this app.")
        case .restricted:
            print("Restricted, device owner must approve")
        case .authorized:
            print("Authorized, proceed")
            if(UIImagePickerController .isSourceTypeAvailable(.camera)){
                self.connectDevice()
            }else{
                print("Camera not availiable")
            }
        case .notDetermined:
            print("Not Determined")
            AVCaptureDevice.requestAccess(for: .video) { success in
                if success {
                    print("Permission granted, proceed")
                    if(UIImagePickerController .isSourceTypeAvailable(.camera)){
                        self.connectDevice()
                    }else{
                        print("Camera not availiable")
                    }
                } else {
                    print("Permission denied")
                }
            }
        }
    }
    
    func showAlert(title:String, message:String) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: UIAlertController.Style.alert)
        
        let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alert.addAction(okAction)
        
        let settingsAction = UIAlertAction(title: "Settings", style: .default, handler: { _ in
            // Take the user to Settings app to possibly change permission.
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
            if UIApplication.shared.canOpenURL(settingsUrl) {
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        // Finished opening URL
                    })
                } else {
                    // Fallback on earlier versions
                    UIApplication.shared.openURL(settingsUrl)
                }
            }
        })
        alert.addAction(settingsAction)
        if let controller = self.controller {
            controller.present(alert, animated: true, completion: nil)
        }
    }
}
