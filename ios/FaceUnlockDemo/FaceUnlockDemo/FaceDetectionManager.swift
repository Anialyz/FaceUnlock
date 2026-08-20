//
//  FaceDetectionManager.swift
//  FaceUnlockDemo
//
//  Minimal on-device face detection using AVFoundation for camera capture
//  and Vision for face detection. No network calls, no data leaves the
//  device — this is a local-only demo, not a full authentication system.
//

import AVFoundation
import Vision
import UIKit
import Combine

final class FaceDetectionManager: NSObject, ObservableObject {

    /// Whether a face is currently detected in the camera feed.
    @Published var isFaceDetected: Bool = false

    /// Human readable status text shown in the UI.
    @Published var statusText: String = "Camera not started"

    /// Set to a non-nil value if camera access or setup fails.
    @Published var errorMessage: String?

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.vitania.faceunlockdemo.session")
    private let visionQueue = DispatchQueue(label: "com.vitania.faceunlockdemo.vision")

    private var lastDetectionRequest: VNDetectFaceRectanglesRequest?

    override init() {
        super.init()
    }

    /// Returns the live preview layer wired up to the capture session.
    /// Call `start()` before / after adding this layer to a view.
    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    func requestAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.errorMessage = "Camera access denied."
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera access denied. Enable it in Settings to try the demo."
        @unknown default:
            errorMessage = "Unknown camera authorization state."
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .medium

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let input = try? AVCaptureDeviceInput(device: device),
                self.captureSession.canAddInput(input)
            else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to access the front camera."
                }
                self.captureSession.commitConfiguration()
                return
            }
            self.captureSession.addInput(input)

            self.videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }

            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()

            DispatchQueue.main.async {
                self.statusText = "Looking for a face…"
            }
        }
    }
}

extension FaceDetectionManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self else { return }
            let hasFace = (request.results as? [VNFaceObservation])?.isEmpty == false

            DispatchQueue.main.async {
                self.isFaceDetected = hasFace
                self.statusText = hasFace ? "Face detected" : "Looking for a face…"
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])
        do {
            try handler.perform([request])
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Vision request failed: \(error.localizedDescription)"
            }
        }
    }
}
