//
//  Request.swift
//  CovidWatch
//
//  Created by Christopher McGraw on 6/3/20.
//

protocol Request {
    var scheme: String { get }
    var host: String { get }
    var path: String { get }
    var headers: [String: String] { get }
    var parameters: [URLQueryItem] { get }
    var method: String { get }
    var body: RequestBody? { get }
}

extension Request {
    var scheme: String { "https" }
    var host: String { Bundle.main.infoDictionary?["API_BASE_URL"] as! String }

    var headers: [String: String] {
        var ct_key = ""
        if let key = Bundle.main.infoDictionary?["CT_KEY"] as? String {
            ct_key = key
        }
        
        return [
            "CT_KEY": ct_key,
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
    }

    var parameters: [URLQueryItem] { [] }
    var body: Codable? { nil }
}

protocol RequestBody: Codable {
    func toJSONData() -> Data?
}

extension RequestBody {
    func toJSONData() -> Data? { try? JSONEncoder().encode(self) }
}
