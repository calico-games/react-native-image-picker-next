import UIKit
import AVFoundation
import React
import SDWebImage
import SDWebImageWebPCoder

@objc(ImagePickerModule)
class ImagePickerModule: NSObject, RCTBridgeModule, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    enum Constants {
        static let defaultSize: CGFloat = 200
        static let defaultCompressionQuality: Float = 0.5
        static let defaultOptions: [String: Any] = [
            "isCropping": true,
            "width": Constants.defaultSize,
            "height": Constants.defaultSize,
            "compressionQuality": Constants.defaultCompressionQuality,
            "useWebP": true,
            "shouldResize": true,
            "useFrontCamera": false,
            "isTemp": false
        ]
    }

    static func moduleName() -> String! {
        return "ImagePickerModule"
    }

    static func requiresMainQueueSetup() -> Bool {
        return true
    }

    private var options: [String: Any] = [:]
    private var imagePickerResolve: RCTPromiseResolveBlock?
    private var imagePickerReject: RCTPromiseRejectBlock?

    @objc
    func openImagePicker(_ sourceType: UIImagePickerController.SourceType, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async {
            let isCropping = self.options["isCropping"] as? Bool == true
            let useFrontCamera = self.options["useFrontCamera"] as? Bool == true

            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = sourceType
            imagePicker.delegate = self
            imagePicker.allowsEditing = isCropping
            imagePicker.sourceType = sourceType
            imagePicker.mediaTypes = ["public.image"]
            imagePicker.modalPresentationStyle = .overFullScreen

            if sourceType == .camera {
                imagePicker.cameraCaptureMode = .photo
                imagePicker.cameraDevice = useFrontCamera ? .front : .rear
            }

            if let viewController = RCTPresentedViewController() {
                self.imagePickerResolve = resolve
                self.imagePickerReject = reject

                viewController.present(imagePicker, animated: true, completion: nil)
            } else {
                reject("PRESENT_VIEW_CONTROLLER_ERROR", "Could not find present UIImagePickerController", nil)
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)

        let isCropping = options["isCropping"] as? Bool == true
        let key: UIImagePickerController.InfoKey = isCropping ? .editedImage : .originalImage

        guard var image = info[key] as? UIImage else {
            self.imagePickerReject?("IMAGE_NOT_FOUND", "Image could not be found!", nil)
            return
        }

        let width = options["width"] as? CGFloat ?? Constants.defaultSize
        let height = options["width"] as? CGFloat ?? Constants.defaultSize
        let compressionQuality = options["compressionQuality"] as? Float ?? Constants.defaultCompressionQuality
        let useWebP = options["useWebP"] as? Bool == true
        let shouldResize = options["shouldResize"] as? Bool == true
        let isTemp = options["isTemp"] as? Bool == true

        if shouldResize {
            image = image.resizedImageToSize(dstSize: .init(width: width, height: height)) ?? image
        }

        let imageData: Data
        if useWebP {
            let options: [SDImageCoderOption: Any] = [.encodeCompressionQuality: compressionQuality, .encodeWebPMethod: 0, .encodeWebPAlphaCompression: 1]
            imageData = SDImageWebPCoder.shared.encodedData(with: image, format: .webP, options: options)!
        } else {
            imageData = image.jpegData(compressionQuality: CGFloat(compressionQuality))!
        }

        let directory = isTemp ? FileManager.default.temporaryDirectory : FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let randomID = UUID().uuidString
        let imageFileName = "image-" + randomID
        let imageExtension = useWebP ? ".webp" : ".jpg"
        let fileURL = temporaryDirectory.appendingPathComponent(imageFileName + imageExtension)

        do {
            try imageData.write(to: fileURL)
            let imagePath = fileURL.absoluteString as NSString
            self.imagePickerResolve?(imagePath)
        } catch {
            self.imagePickerReject?("IMAGE_SAVE_ERROR", "Image could not be saved!", nil)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        self.imagePickerReject?("PICKER_CANCELLED_ERROR", "Image Picker cancelled!", nil)
    }

    typealias CompletionHandler = (Bool) -> Void

    private func checkForCameraPermission(completion: (CompletionHandler)? = nil) {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            completion?(true)
            return
        }

        AVCaptureDevice.requestAccess(for: .video, completionHandler: { access in
            DispatchQueue.main.async {
                completion?(access)
            }
        })
    }

    @objc(openCamera:withResolver:withRejecter:)
    public func openCamera(_ options: [String: Any], resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        self.options = Constants.defaultOptions.merging(options) { (_, new) in new }

        checkForCameraPermission(completion: { granted in
            if granted {
                self.openImagePicker(.camera, resolve: resolve, reject: reject)
            } else {
                reject("CAMERA_PERMISSION_ERROR", "Camera permission not granted", nil)
            }
        })
    }

    @objc(openGallery:withResolver:withRejecter:)
    public func openGallery(_ options: [String: Any], resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
        self.options = Constants.defaultOptions.merging(options) { (_, new) in new }

        openImagePicker(.photoLibrary, resolve: resolve, reject: reject)
    }
}
