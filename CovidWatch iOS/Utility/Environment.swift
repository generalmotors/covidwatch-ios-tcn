//
//  Environment.swift
//  CovidWatch iOS
//
//  Created by Madhava Jay on 16/4/20.
//  
//

import Foundation

enum AppScheme {
    case production
    case development
    case test
}

func getLocalIP() -> String {
    // sometimes the xcode ip sniff fails, in that case you can just
    // hard code it during development
    //return "192.168.176.132"
    if let localIP = Bundle.main.infoDictionary?["LocalIP"] as? String {
        return localIP
    }
    return "localhost"
}

func getLocalFirebaseHost() -> String {
    let firebasePort = 8080
    return "\(getLocalIP()):\(firebasePort)"
}

func getAPIUrl(_ scheme: AppScheme) -> String {
    return "https://us-central1-covid2020-c4386.cloudfunctions.net"
}

func getAppScheme() -> AppScheme {
    if let schemeName = Bundle.main.infoDictionary?["SchemeName"] as? String {
        print("Scheme Name: \(schemeName)")
        switch schemeName {
        case "covidwatch-ios-prod":
            return .production
        case "covidwatch-ios-test":
            return .test
        default:
            return .development
        }
    }
    return .development
}
