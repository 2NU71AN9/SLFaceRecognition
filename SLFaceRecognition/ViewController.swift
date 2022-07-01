//
//  ViewController.swift
//  SLFaceRecognition
//
//  Created by 孙梁 on 2021/1/18.
//

import UIKit
import AVFoundation
import Vision
import RxSwift
import PKHUD

class ViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    
    enum FaceStatus {
        case normal
        case loading
        case success
        case failure(time: Int)
    }
    
    private lazy var session: AVCaptureSession = {
        let session = AVCaptureSession()
        if let input = input {
            session.addInput(input)
        }
        session.addOutput(output)
        return session
    }()
    
    private lazy var device: AVCaptureDevice? = {
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        return device
    }()
    
    private lazy var input: AVCaptureDeviceInput? = {
        guard let device = device else { return nil }
        let input = try? AVCaptureDeviceInput(device: device)
        return input
    }()
    
    private lazy var output: AVCaptureVideoDataOutput = {
        let output = AVCaptureVideoDataOutput()
        let queue = DispatchQueue(label: "VideoDataOutputQueue")
        output.setSampleBufferDelegate(self, queue: queue)
        return output
    }()
    
    private lazy var preview: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = CGRect(x: 87.5, y: 200, width: 200, height: 200)
        layer.videoGravity = .resizeAspectFill
        layer.cornerRadius = 100
        layer.borderWidth = 3
        layer.borderColor = UIColor.white.cgColor
        return layer
    }()
    
    private var subLayers: [CALayer] = []
    private var position: AVCaptureDevice.Position = .front
    
    private let bag = DisposeBag()
    private var faceStatus: FaceStatus = .normal
    private var failureTime = 0
    private let ori_face = UIImage(named: "myFace")?.sl2Base64()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.addSublayer(preview)
        session.startRunning()
    }
    
    @IBAction func stopAction(_ sender: Any) {
        session.stopRunning()
    }
    
    private func checkFace(image: UIImage) {
        faceStatus = .loading
        if let imageA = image.sl2Base64(),
           let imageB = ori_face {
            NetworkHandler.request(.faceContrast(face1: imageA, face2: imageB))
                .subscribe(onNext: { (value) in
                    if let dict = value.result as? [String: [String: Any]],
                       let score = dict["Response"]?["Score"] as? Int {
                        HUD.showToast("相似度\(score)")
                        self.faceStatus = .success
                    } else {
                        if let dict = value.result as? [String: [String: [String: Any]]],
                                  let message = dict["Response"]?["Error"]?["Message"] as? String {
                            HUD.showToast("\(message)")
                        }
                        self.failureTime += 1
                        self.faceStatus = .failure(time: self.failureTime)
                    }
                })
                .disposed(by: bag)
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait
        connection.isVideoMirrored = true
        var handler: VNImageRequestHandler?
        if #available(iOS 14.0, *) {
            handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])
        } else {
            if let cvpixeBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer) {
                handler = VNImageRequestHandler(cvPixelBuffer: cvpixeBufferRef, orientation: .right, options: [:])
            }
        }
        guard let myHandler = handler else { return }
//        let request = faceReqReq()
        let request = facePointReqReq(sampleBuffer)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try myHandler.perform([request])
            }
            catch {
                print("e")
            }
        }
    }
}

extension ViewController {
    
    private func faceReqReq() -> VNDetectFaceRectanglesRequest {
        let request = VNDetectFaceRectanglesRequest(completionHandler: { [weak self] (request, error) in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                if let result = request.results as? [VNFaceObservation] {
                    self.subLayers.forEach{$0.removeFromSuperlayer()}
                    for item in result {
                        let rectLayer = CALayer()
                        var transFrame = self.convertRect(boundingBox: item.boundingBox, size: self.preview.frame.size)
                        if self.position == .front {
                            transFrame.origin.x = self.preview.frame.size.width - transFrame.origin.x - transFrame.size.width;
                        }
                        rectLayer.frame = transFrame
                        rectLayer.borderColor = UIColor.red.cgColor
                        rectLayer.borderWidth = 2
                        self.preview.addSublayer(rectLayer)
                        self.subLayers.append(rectLayer)
                    }
                }
            }
        })
        return request
    }
    
    private func facePointReqReq(_ sampleBuffer: CMSampleBuffer) -> VNDetectFaceLandmarksRequest {
        let request = VNDetectFaceLandmarksRequest(completionHandler: { [weak self] (request, error) in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                guard let result = request.results as? [VNFaceObservation] else { return }
                for item in result {
                    if self.isFace(item) {
                        self.makeFaceImageAndCheck(sampleBuffer)
//                        self.imageView.image = self.buffer2Image(sampleBuffer)
                        break
                    } else {
                        self.imageView.image = nil
                    }
                }
            }
        })
        return request
    }
    
    private func convertRect(boundingBox: CGRect, size: CGSize) -> CGRect {
        let scale = size.width / (UIScreen.main.bounds.width/UIScreen.main.bounds.height * size.height)
        let o_w = boundingBox.size.width * size.width
        let o_h = boundingBox.size.height * size.height
        let real_h = o_h * scale
        let o_x = boundingBox.origin.x * size.width
        let o_y = size.height * (1 - boundingBox.origin.y - boundingBox.size.height)
        let real_y = o_y - (real_h - o_h)/2
        return CGRect(x: o_x, y: real_y, width: o_w, height: real_h)
    }
    
    private func buffer2Image(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate);
        let convertedImage = CIImage(cvImageBuffer: pixelBuffer, options: attachments as? [CIImageOption : Any])
        let image = UIImage(ciImage: convertedImage)
        return image//.rotate(radians: CGFloat.pi/2).flip()
    }
    
    private func isFace(_ item: VNFaceObservation) -> Bool {
        if item.landmarks?.leftEye == nil
            || item.landmarks?.rightEye == nil
            || item.landmarks?.noseCrest == nil
            || item.landmarks?.outerLips == nil
            || item.landmarks?.innerLips == nil
            || item.landmarks?.leftPupil == nil
            || item.landmarks?.rightPupil == nil {
            return false
        }
        return true
    }
    
    private func makeFaceImageAndCheck(_ sampleBuffer: CMSampleBuffer) {
        switch faceStatus {
        case .failure(let time):
            if time >= 30 { return }
        case .success, .loading:
            return
        default:
            break
        }
        guard let faceImage = buffer2Image(sampleBuffer) else { return }
        imageView.image = faceImage
        checkFace(image: faceImage)
    }
    
    private func shot() {
        let captureConnection = output.connection(with: .video)
        AVCapturePhotoOutput()
    }
}
