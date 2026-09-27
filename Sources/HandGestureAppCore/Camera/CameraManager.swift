import Foundation
import AVFoundation
import CoreImage
import CoreGraphics
import AppKit
import os.log

public protocol CameraManagerDelegate: AnyObject, Sendable {
    func cameraManager(_ manager: CameraManager, didOutput pixelBuffer: CVPixelBuffer, timestamp: TimeInterval)
}

/// High-efficiency AVFoundation capture pipeline with adaptive framerates and zero-lag buffer processing.
public final class CameraManager: NSObject, @unchecked Sendable {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.airmac.camera.session", qos: .userInitiated)
    private let videoQueue = DispatchQueue(label: "com.airmac.camera.videoOutput", qos: .userInteractive)
    private let logger = Logger(subsystem: "com.airmac.gestures", category: "CameraManager")

    public weak var delegate: CameraManagerDelegate?
    public private(set) var isRunning: Bool = false
    public private(set) var targetFPS: Int = 30

    // Frame drop guard to ensure Vision never creates backpressure
    private var isProcessingFrame: Bool = false
    private let processingLock = NSLock()

    public override init() {
        super.init()
    }

    /// Configures capture session with chosen device, preset, and frame rate.
    public func setupCamera(targetFPS: Int = 30, preset: AVCaptureSession.Preset = .vga640x480) {
        self.targetFPS = targetFPS
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            
            if self.captureSession.canSetSessionPreset(preset) {
                self.captureSession.sessionPreset = preset
            }

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
                               AVCaptureDevice.default(for: .video) else {
                self.logger.error("No compatible video camera device found.")
                self.captureSession.commitConfiguration()
                return
            }

            // Remove existing inputs
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }

                // Configure frame rate
                try camera.lockForConfiguration()
                let targetDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
                camera.activeVideoMinFrameDuration = targetDuration
                camera.activeVideoMaxFrameDuration = targetDuration
                camera.unlockForConfiguration()
            } catch {
                self.logger.error("Failed to configure camera input: \(error.localizedDescription)")
            }

            // Configure video output
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                self.captureSession.addOutput(self.videoOutput)
            }

            self.captureSession.commitConfiguration()
        }
    }

    /// Starts camera capture
    public func start() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            self.isRunning = self.captureSession.isRunning
            self.logger.info("Camera capture session started.")
        }
    }

    /// Stops camera capture
    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            self.isRunning = false
            self.logger.info("Camera capture session stopped.")
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Fast lock check to discard frame if processing thread is busy
        guard processingLock.try() else { return }
        defer { processingLock.unlock() }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

        delegate?.cameraManager(self, didOutput: pixelBuffer, timestamp: timestamp)
    }
}
