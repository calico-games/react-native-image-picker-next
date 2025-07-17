import UIKit

extension UIImage {

    func resizedImageToSize(dstSize: CGSize) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }

        let srcWidth = CGFloat(cgImage.width)
        let srcHeight = CGFloat(cgImage.height)

        // If already square and same size, return original
        if srcWidth == srcHeight && srcWidth == dstSize.width {
            return self
        }

        let targetSize = dstSize
        let srcAspect = srcWidth / srcHeight
        let targetAspect = targetSize.width / targetSize.height

        var scaledSize = CGSize.zero
        if srcAspect > targetAspect {
            // Image is wider → scale height to fit, crop width
            scaledSize.height = targetSize.height
            scaledSize.width = targetSize.height * srcAspect
        } else if srcAspect < targetAspect {
            // Image is taller → scale width to fit, crop height
            scaledSize.width = targetSize.width
            scaledSize.height = targetSize.width / srcAspect
        } else {
            // Same aspect ratio — just scale to target
            scaledSize = targetSize
        }

        // Resize image
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: scaledSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let resized = resizedImage else { return nil }

        // Now center-crop if needed
        let cropX = max(0, (resized.size.width - targetSize.width) / 2)
        let cropY = max(0, (resized.size.height - targetSize.height) / 2)
        let cropRect = CGRect(x: cropX, y: cropY, width: targetSize.width, height: targetSize.height)

        guard let cgResized = resized.cgImage?.cropping(to: cropRect) else {
            return resized // fallback: return resized even if cropping fails
        }

        return UIImage(cgImage: cgResized, scale: self.scale, orientation: self.imageOrientation)
    }
}
