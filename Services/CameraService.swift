import AVFoundation
import Vision
import UIKit
import SwiftUI
import Combine

class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var detectedBarcode: String?
    @Published var detectedText: [String] = []
    @Published var capturedImage: UIImage?
    @Published var isFlashOn = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.inventaria.camera", qos: .userInitiated)

    private var lastBarcodeDetectionTime = Date.distantPast
    private let barcodeThrottleInterval: TimeInterval = 1.5
    private var photoCaptureContinuation: CheckedContinuation<UIImage?, Never>?

    override init() {
        super.init()
        checkAuthorization()
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.isAuthorized = true }
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            DispatchQueue.main.async { self.isAuthorized = false }
        }
    }

    private func setupSession() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                self.session.commitConfiguration()
                return
            }

            if self.session.canAddInput(input) {
                self.session.addInput(input)
            }

            self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
        }
    }

    func startSession() {
        processingQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        processingQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isFlashOn.toggle()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            #if DEBUG
            print("[CameraService] Flash toggle error: \(error)")
            #endif
        }
    }

    ///legacy
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    /// devuelve la imagen cuando esta lista
    func capturePhotoAsync() async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.photoCaptureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            processingQueue.async { [weak self] in
                self?.photoOutput.capturePhoto(with: settings, delegate: self!)
            }
        }
    }

    private func detectBarcodes(in image: CGImage) {
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let results = request.results as? [VNBarcodeObservation],
                  let barcode = results.first,
                  let payload = barcode.payloadStringValue else { return }

            //validacion
            guard payload.count <= 32,
                  !payload.isEmpty,
                  payload.allSatisfy({ $0.isNumber }) else { return }

            let now = Date()
            guard let self = self,
                  now.timeIntervalSince(self.lastBarcodeDetectionTime) > self.barcodeThrottleInterval else { return }

            self.lastBarcodeDetectionTime = now
            DispatchQueue.main.async {
                self.detectedBarcode = payload
                HapticManager.notification(.success)
            }
        }

        //sin qr ni datamatrix
        request.symbologies = [
            .ean13, .ean8, .upce,
            .code128, .code39, .code93,
            .itf14, .codabar
        ]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }

    func recognizeText(in image: CGImage, completion: @escaping ([String]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard let results = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            let texts = results.compactMap { $0.topCandidates(1).first?.string }
            DispatchQueue.main.async { completion(texts) }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es", "en"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try? handler.perform([request])
    }

    func reset() {
        DispatchQueue.main.async { [weak self] in
            self?.detectedBarcode = nil
            self?.detectedText = []
            self?.capturedImage = nil
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        detectBarcodes(in: cgImage)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            // Resolver la continuation con nil si la captura falla
            if let continuation = photoCaptureContinuation {
                photoCaptureContinuation = nil
                continuation.resume(returning: nil)
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
        }

        //resolver la continuation async si alguien está esperando
        if let continuation = photoCaptureContinuation {
            photoCaptureContinuation = nil
            continuation.resume(returning: image)
        }

        //OCR Legacy
        if let cgImage = image.cgImage {
            recognizeText(in: cgImage) { [weak self] texts in
                self?.detectedText = texts
            }
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}