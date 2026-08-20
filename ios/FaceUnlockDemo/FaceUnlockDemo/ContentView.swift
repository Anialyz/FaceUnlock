//
//  ContentView.swift
//  FaceUnlockDemo
//
//  Minimal UI: shows the front camera preview and a status pill that
//  flips when Vision detects a face. Local-only, no unlocking logic —
//  this is a starting point for a real face-unlock flow, not one.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var faceDetection = FaceDetectionManager()

    var body: some View {
        ZStack {
            CameraPreviewView(faceDetection: faceDetection)
                .ignoresSafeArea()

            VStack {
                Spacer()

                statusPill

                if let error = faceDetection.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            faceDetection.requestAccessAndStart()
        }
        .onDisappear {
            faceDetection.stop()
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(faceDetection.isFaceDetected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)
            Text(faceDetection.statusText)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 40)
    }
}

private struct CameraPreviewView: UIViewControllerRepresentable {
    let faceDetection: FaceDetectionManager

    func makeUIViewController(context: Context) -> PreviewViewController {
        let controller = PreviewViewController()
        controller.previewLayer = faceDetection.makePreviewLayer()
        return controller
    }

    func updateUIViewController(_ uiViewController: PreviewViewController, context: Context) {}
}

private final class PreviewViewController: UIViewController {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        if let previewLayer {
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

#Preview {
    ContentView()
}
