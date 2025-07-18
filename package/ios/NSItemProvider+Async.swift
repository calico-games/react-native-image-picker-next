import Foundation
import Photos

internal extension NSItemProvider {
    func loadObject(ofClass objectClass: any NSItemProviderReading.Type) async throws -> NSItemProviderReading? {
        return try await withCheckedThrowingContinuation { continuation in
            self.loadObject(ofClass: objectClass) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    func loadImageDataRepresentation() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let preferredTypeIdentifier = self.registeredTypeIdentifiers()
                .compactMap { UTType($0) }
                .first { $0.conforms(to: .image) }?
                .identifier ?? UTType.image.identifier
            loadDataRepresentation(forTypeIdentifier: preferredTypeIdentifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? PHPhotosError(.internalError))
                }
            }
        }
    }
}
