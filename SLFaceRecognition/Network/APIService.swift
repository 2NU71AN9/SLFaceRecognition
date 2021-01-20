//
//  APIService.swift
//  SLCommProject
//
//  Created by 孙梁 on 2020/12/11.
//

import UIKit
import Moya
import SLSupportLibrary

public enum APIService {
    /// 登录
    case faceContrast(face1: String, face2: String, isUrl: Bool = false)
}

extension APIService: TargetType {

    static let kDebugBaseURL = kReleaseBaseURL
    static let kReleaseBaseURL = "https://iai.tencentcloudapi.com"

    public var baseURL: URL {
        var urlStr = ""
        switch self {
        default:
            #if DEBUG
            urlStr = APIService.kDebugBaseURL
            #else
            urlStr = APIService.kReleaseBaseURL
            #endif
        }
        return URL(string: urlStr + path)!
    }

    public var path: String { "" }

    public var method: Moya.Method {
        switch self {
        default:
            return .post
        }
    }

    public var sampleData: Data { "".data(using: .utf8) ?? Data() }

    public var task: Task {
//        print("""
//            #############↓请求参数↓#################
//            \(baseURL)
//            \(parameters)
//            ######################################
//            """)
        var para = parameters
//        para["token"] = AccountServicer.service.token
        switch self {
//        case .login:
//            return .requestCompositeData(bodyData: Data(), urlParameters: para)
//        case .uploadImage(let images):
//            return .uploadMultipart(images.compactMap {$0.formData})
        default:
            return .requestParameters(parameters: para, encoding: JSONEncoding.default)
        }
    }

    public var headers: [String: String]? {
        switch self {
        case .faceContrast:
            let headers = Sign.makeSign(parameters)
            print("headers==>\(headers)")
            return headers as? [String: String]
        default:
            return ["Authorization": "",
    //                "Content-Type": "application/x-www-form-urlencoded"
                    "Content-Type": "application/json; charset=utf-8"
            ]
        }
    }

    /// 参数
    public var parameters: [String: Any] {
        switch self {
        case .faceContrast(let face1, let face2, let isUrl):
            if isUrl {
                return ["UrlA": face1, "UrlB": face2]
            }
            return ["ImageA": face1, "ImageB": face2]
        }
    }

    /// 网络请求时是否显示loading...
    public var showProgress: Bool {
        true
    }

    public var responsePath: String? {
        nil
    }
}
