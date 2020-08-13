//
//  GetPhoneModelsRequest.swift
//  CovidWatch
//
//  Created by Joseph Licari on 7/6/20.
//

import Foundation

struct GetPhoneModelsRequest: Request {
    
    var path: String { "/api/v1/phone_models" }
    var method: String { "GET" }

    var body: RequestBody? {
        return nil
    }
    
}
