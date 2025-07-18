import UIKit
import PhotosUI
import React
import SDWebImage
import SDWebImageWebPCoder
import TOCropViewController

@objc(ImagePickerModule)
class ImagePickerModule: NSObject, RCTBridgeModule, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
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
            "useNativeCropper": false,
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
            let useNativeCropper = self.options["useNativeCropper"] as? Bool == true
            let useFrontCamera = self.options["useFrontCamera"] as? Bool == true
            let imagePicker: UIViewController

            if #available(iOS 14.0, *), !useNativeCropper, sourceType != .camera {
                var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
                configuration.selectionLimit = 1
                configuration.filter = .images
                configuration.preferredAssetRepresentationMode = .current
                configuration.selection = .default

                let vc = PHPickerViewController(configuration: configuration)
                vc.delegate = self
                imagePicker = vc
            } else {
                let vc = UIImagePickerController()
                vc.delegate = self
                vc.sourceType = sourceType
                vc.allowsEditing = isCropping && useNativeCropper
                vc.sourceType = sourceType
                vc.mediaTypes = ["public.image"]

                if sourceType == .camera {
                    vc.cameraCaptureMode = .photo
                    vc.cameraDevice = useFrontCamera ? .front : .rear
                }

                imagePicker = vc
            }

            if let viewController = RCTPresentedViewController() {
                self.imagePickerResolve = resolve
                self.imagePickerReject = reject

                self.presentPickerUI(viewController, imagePicker: imagePicker)
            } else {
                reject("PRESENT_VIEW_CONTROLLER_ERROR", "Could not find present UIImagePickerController", nil)
            }
        }
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let isCropping = options["isCropping"] as? Bool == true
        let useNativeCropper = options["useNativeCropper"] as? Bool == true
        let key: UIImagePickerController.InfoKey = isCropping && useNativeCropper ? .editedImage : .originalImage

        guard let image = info[key] as? UIImage else {
            picker.dismiss(animated: true, completion: nil)
            self.imagePickerReject?("IMAGE_NOT_FOUND", "Image could not be found!", nil)
            return
        }

        if isCropping && !useNativeCropper {
            let size = CGSize(
                width: options["width"] as? CGFloat ?? Constants.defaultSize,
                height: options["height"] as? CGFloat ?? Constants.defaultSize
            )

            self.cropImage(picker, image: image, to: size)
        } else {
            picker.dismiss(animated: true, completion: nil)
            self.finalizeImage(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        self.imagePickerReject?("PICKER_CANCELLED_ERROR", "Image Picker cancelled!", nil)
    }

    // MARK: - PHPickerViewControllerDelegate

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        if results.isEmpty {
            picker.dismiss(animated: true, completion: nil)
            self.imagePickerReject?("PICKER_CANCELLED_ERROR", "Image Picker cancelled!", nil)
        } else {
            Task {
                guard let selectedItem = results.first else {
                    picker.dismiss(animated: true, completion: nil)
                    self.imagePickerReject?("PICKER_CANCELLED_ERROR", "Image Picker cancelled!", nil)
                    return
                }

                let itemProvider = selectedItem.itemProvider

                let image: UIImage

                do {
                    if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        image = try await handleImage(from: selectedItem)
                    }
                    // Fallback to capability-based detection when the provider reports no identifiers (iOS bug?).
                    // This can happen when files have been synced via AirDrop or iTunes and the file extension is not recognized.
                    else if itemProvider.canLoadObject(ofClass: UIImage.self) {
                        image = try await handleImage(from: selectedItem)
                    }
                    else {
                        throw PHPhotosError(.invalidResource)
                    }
                } catch {
                    picker.dismiss(animated: true, completion: nil)
                    self.imagePickerReject?("IMAGE_LOAD_ERROR", "Failed to load image from picker", error)
                    return
                }

                let isCropping = options["isCropping"] as? Bool == true

                if isCropping {
                    let size = CGSize(
                        width: options["width"] as? CGFloat ?? Constants.defaultSize,
                        height: options["height"] as? CGFloat ?? Constants.defaultSize
                    )
                    self.cropImage(picker, image: image, to: size)
                } else {
                    self.finalizeImage(image)
                }
            }
        }
    }

    private func handleImage(from selectedImage: PHPickerResult) async throws -> UIImage {
        let itemProvider = selectedImage.itemProvider

        // Fast-path: copy original file when no processing is required and current representation is requested.
        if true {
          // Attempt to obtain original file URL
          if let targetUrl = try? await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<URL, Error>)
            in itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
              guard let srcUrl = url else {
                  return continuation.resume(throwing: error ?? PHPhotosError(.internalError))
              }
              do {
                  let destUrl = Self.generateURL(withFileExtension: "." + srcUrl.pathExtension, isTemp: true)
                  try FileManager.default.copyItem(at: srcUrl, to: destUrl)
                  continuation.resume(returning: destUrl)
              } catch {
                  continuation.resume(throwing: error)
              }
            }
          }) {
            guard let image = UIImage(contentsOfFile: targetUrl.path) else {
                throw PHPhotosError(.internalError)
            }

            return image
          }
        }

        // If fast copy path failed or was not available because of the props
        // use slow path (existing implementation)
        let rawData = try await itemProvider.loadImageDataRepresentation()

        guard let image = UIImage(data: rawData) else {
            throw PHPhotosError(.internalError)
        }

        return image
    }

    private func presentPickerUI(_ viewController: UIViewController, imagePicker: UIViewController) {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let viewFrame = viewController.view.frame
            imagePicker.popoverPresentationController?.sourceRect = CGRect(
                x: viewFrame.midX,
                y: viewFrame.maxY,
                width: 0,
                height: 0
            )
            imagePicker.popoverPresentationController?.sourceView = viewController.view
        }

        imagePicker.modalPresentationStyle = .overFullScreen
        viewController.present(imagePicker, animated: true, completion: nil)
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

    private func cropImage(_ viewController: UIViewController, image: UIImage, to size: CGSize) {
        let cropController = TOCropViewController(croppingStyle: .circular, image: image)
        cropController.aspectRatioPreset = .presetCustom
        cropController.aspectRatioLockEnabled = true
        cropController.aspectRatioPickerButtonHidden = true
        cropController.cropView.cropBoxResizeEnabled = false
        cropController.customAspectRatio = size
        cropController.resetAspectRatioEnabled = true
        cropController.rotateButtonsHidden = true
        cropController.resetButtonHidden = true

        cropController.delegate = self
        cropController.modalPresentationStyle = .fullScreen
        if #available(iOS 15.0, *) {
            cropController.modalTransitionStyle = .coverVertical
        }

        viewController.present(cropController, animated: true)
    }

    private func finalizeImage(_ image: UIImage, cropViewController: TOCropViewController? = nil) {
        // Ensure the image is oriented correctly
        var image = image.fixOrientation() ?? image

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

        let imageExtension = useWebP ? ".webp" : ".jpg"
        let fileURL = Self.generateURL(withFileExtension: imageExtension, isTemp: isTemp)

        do {
            try imageData.write(to: fileURL)
            let imagePath = fileURL.absoluteString as NSString

            self.imagePickerResolve?(imagePath)

            if let cropViewController = cropViewController {
                self.dismissCropper(cropViewController, selectionDone: true)
            }
        } catch {
            self.imagePickerReject?("IMAGE_SAVE_ERROR", "Image could not be saved!", nil)

            if let cropViewController = cropViewController {
                self.dismissCropper(cropViewController, selectionDone: true)
            }
        }
    }

    private static func generateURL(withFileExtension: String, isTemp: Bool) -> URL {
        let directory = isTemp ? FileManager.default.temporaryDirectory : FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let randomID = UUID().uuidString
        let imageFileName = "image-" + randomID
        return directory.appendingPathComponent(imageFileName + withFileExtension)
    }
}


extension ImagePickerModule: TOCropViewControllerDelegate {
    
    func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
        self.finalizeImage(image, cropViewController: cropViewController)
    }

    func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
        self.dismissCropper(cropViewController, selectionDone: false)
    }

    func cropViewController(_ cropViewController: TOCropViewController, didFailToCropImage image: UIImage, withError error: Error) {
        self.dismissCropper(cropViewController, selectionDone: false) { [weak self] in
            guard let self = self else { return }

            self.imagePickerReject?("IMAGE_CROP_ERROR", "Image cropping failed!", error)
        }
    }

    private func dismissCropper(_ cropViewController: TOCropViewController, selectionDone: Bool, completion: (() -> Void)? = nil) {
        if selectionDone {
            // If selection is done, dismiss the entire stack
            cropViewController.presentingViewController?.presentingViewController?.dismiss(animated: true, completion: completion)
        } else {
            // If cancelled, dismiss the crop controller properly
            cropViewController.presentingViewController?.dismiss(animated: true, completion: completion)
        }
    }
}
