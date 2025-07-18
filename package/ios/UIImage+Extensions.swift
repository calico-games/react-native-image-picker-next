import UIKit

extension UIImage {

    func resizedImageToSize(dstSize: CGSize) -> UIImage? {
        guard let cgImage = self.cgImage else {
            return nil
        }

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

    // This makes sure the image is oriented up and not mirrored.
    // Guarantees that the original pixel data matches the displayed orientation.
    func fixOrientation() -> UIImage? {
        // No-op if orientation is already correct
        if self.imageOrientation == UIImage.Orientation.up {
            return self
        }

        guard let cgImage = self.cgImage else {
            return nil
        }

        guard var colorSpace = cgImage.colorSpace else {
            // That should never happen as `colorSpace` is empty only when the image is a mask.
            return nil
        }

        // Ensure color space supports output
        if !colorSpace.supportsOutput {
            colorSpace = CGColorSpaceCreateDeviceRGB()
        }

        var transform = CGAffineTransform.identity

        // rotation
        switch self.imageOrientation {
        case .down, .downMirrored:
        transform = transform
            .translatedBy(x: self.size.width, y: self.size.height)
            .rotated(by: .pi)
        case .left, .leftMirrored:
        transform = transform
            .translatedBy(x: self.size.width, y: 0)
            .rotated(by: .pi / 2)
        case .right, .rightMirrored:
        transform = transform
            .translatedBy(x: 0, y: self.size.height)
            .rotated(by: -.pi / 2)
        default:
        break
        }

        // Mirroring
        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
        transform = transform
            .translatedBy(x: self.size.width, y: 0)
            .scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
        transform = transform
            .translatedBy(x: self.size.height, y: 0)
            .scaledBy(x: -1, y: 1)
        default:
        break
        }

        guard let context = CGContext(data: nil,
            width: Int(self.size.width),
            height: Int(self.size.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.concatenate(transform)

        switch self.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: self.size.height, height: self.size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        }

        guard let result = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: result)
    }
}
