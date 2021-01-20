//
//  Sign.swift
//  SLFaceRecognition
//
//  Created by 孙梁 on 2021/1/19.
//

import UIKit
import CryptoSwift
import SwiftyJSON
import SLSupportLibrary
import CommonCrypto.CommonHMAC
import HandyJSON

class Sign: NSObject {
    
    static func makeSign(_ dict: [String: Any]) -> [String: Any] {
        let secretId  = "AKIDsYy7HPhqCpN2jJqlbDagU9i127h0blWR"
        let secretKey = "sBGNGHqCH5dx1Od0MSIhHrBwRijStCHE"
        let action = "CompareFace"
        let service = "iai"
        let host = "iai.tencentcloudapi.com"
        let region = "ap-beijing"
        let version = "2020-03-03"
        let algorithm = "TC3-HMAC-SHA256"
        let timestampInterval: TimeInterval = Date().timeIntervalSince1970
        
        let timestamp = "\(Int(timestampInterval))"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        //注意时区，否则容易出错
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let date = dateFormatter.string(from: Date(timeIntervalSince1970: timestampInterval))

        // ************* 步骤 1：拼接规范请求串 *************

        let httpRequestMethod = "POST"
        let canonicalUri = "/"
        let canonicalQueryString = ""
        let canonicalHeaders = "content-type:application/json; charset=utf-8\n" + "host:" + host + "\n"
        let signedHeaders = "content-type;host"
        let data = try? JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed)
        let payload = String(data: data ?? Data(), encoding: .utf8) ?? ""
        let hashedRequestPayload = payload.hashHex(by: .SHA256)
        let canonicalRequest = httpRequestMethod + "\n" + canonicalUri + "\n" + canonicalQueryString + "\n"
            + canonicalHeaders + "\n" + signedHeaders + "\n" + hashedRequestPayload;
        print("第一步结果：", canonicalRequest)
        
        // ************* 步骤 2：拼接待签名字符串 *************
        let credentialScope = date + "/" + service + "/" + "tc3_request"
        let hashedCanonicalRequest = canonicalRequest.hashHex(by: .SHA256)
        let stringToSign = algorithm + "\n" + timestamp + "\n" + credentialScope + "\n" +
        hashedCanonicalRequest
        print("第二步结果：", stringToSign)

        // ************* 步骤 3：计算签名 *************
        let secretDate = date.hmac(by: .SHA256, key: ("TC3" + secretKey).bytes)
        let secretService = service.hmac(by: .SHA256, key: secretDate)
        let secretSigning = "tc3_request".hmac(by: .SHA256, key: secretService)
        let signature = stringToSign.hmac(by: .SHA256, key: secretSigning).hexString.lowercased()
        print("第三步结果：", signature)

        // ************* 步骤 4：拼接 Authorization *************
        let authorization = "TC3-HMAC-SHA256 " + "Credential=" + secretId + "/" + credentialScope + ", "
        + "SignedHeaders=" + signedHeaders + ", " + "Signature=" + signature
        print("第四步结果：", authorization)
//        textView.text += "第四步结果：" + authorization + "\n"
        var headerParams = [String: Any]()
        headerParams["Host"]           = host
        headerParams["Authorization"]  = authorization
        headerParams["Content-Type"]   = "application/json; charset=utf-8"
        headerParams["X-TC-Action"]    = action
        headerParams["X-TC-Timestamp"] = timestamp
        headerParams["X-TC-Version"]   = version
        headerParams["X-TC-Region"]    = region
        headerParams["Action"]    = action
        headerParams["Version"]   = version
        headerParams["Region"]    = region
        return headerParams
    }
}

extension UIImage {
    func sl2Base64() -> String? {
        let dataTmp = self.pngData()
        if let data = dataTmp {
            let imageStrTT = data.base64EncodedString()
            return imageStrTT
        }
        return nil
    }
}

extension String {
    func hmac(by algorithm: Algorithm, key: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: algorithm.digestLength())
        CCHmac(algorithm.algorithm(), key, key.count, self.bytes, self.bytes.count, &result)
        return result
    }
    
    func hashHex(by algorithm: Algorithm) -> String {
        return algorithm.hash(string: self).hexString
    }
    
     func hash(by algorithm: Algorithm) -> [UInt8] {
        return algorithm.hash(string: self)
     }
}
enum Algorithm {
    case MD5, SHA1, SHA224, SHA256, SHA384, SHA512
    
    func algorithm() -> CCHmacAlgorithm {
        var result: Int = 0
        switch self {
        case .MD5:    result = kCCHmacAlgMD5
        case .SHA1:   result = kCCHmacAlgSHA1
        case .SHA224: result = kCCHmacAlgSHA224
        case .SHA256: result = kCCHmacAlgSHA256
        case .SHA384: result = kCCHmacAlgSHA384
        case .SHA512: result = kCCHmacAlgSHA512
        }
        return CCHmacAlgorithm(result)
    }
    
    func digestLength() -> Int {
        var result: CInt = 0
        switch self {
        case .MD5:    result = CC_MD5_DIGEST_LENGTH
        case .SHA1:   result = CC_SHA1_DIGEST_LENGTH
        case .SHA224: result = CC_SHA224_DIGEST_LENGTH
        case .SHA256: result = CC_SHA256_DIGEST_LENGTH
        case .SHA384: result = CC_SHA384_DIGEST_LENGTH
        case .SHA512: result = CC_SHA512_DIGEST_LENGTH
        }
        return Int(result)
    }
    
    func hash(string: String) -> [UInt8] {
        var hash = [UInt8](repeating: 0, count: self.digestLength())
        switch self {
        case .MD5:    CC_MD5(   string.bytes, CC_LONG(string.bytes.count), &hash)
        case .SHA1:   CC_SHA1(  string.bytes, CC_LONG(string.bytes.count), &hash)
        case .SHA224: CC_SHA224(string.bytes, CC_LONG(string.bytes.count), &hash)
        case .SHA256: CC_SHA256(string.bytes, CC_LONG(string.bytes.count), &hash)
        case .SHA384: CC_SHA384(string.bytes, CC_LONG(string.bytes.count), &hash)
        case .SHA512: CC_SHA512(string.bytes, CC_LONG(string.bytes.count), &hash)
        }
        return hash
    }
}

extension Array where Element == UInt8 {
    var hexString: String {
        return self.reduce(""){$0 + String(format: "%02x", $1)}
    }
    
    var base64String: String {
        return self.data.base64EncodedString(options: Data.Base64EncodingOptions.lineLength76Characters)
    }
    
    var data: Data {
        return Data(self)
    }
}

extension String {
    var bytes: [UInt8] {
        return [UInt8](self.utf8)
    }
}

extension Data {
    var bytes: [UInt8] {
        return [UInt8](self)
    }
}
