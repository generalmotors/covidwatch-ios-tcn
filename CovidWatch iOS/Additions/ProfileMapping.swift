//
//  ProfileMapping.swift
//  CovidWatch
//
//  Created by Joseph Licari on 7/1/20.
//

import Foundation

public class ProfileMapping {
    
    public static var shared = ProfileMapping()
    
    private var modelNumberMap = [String: String]()
    private var distanceMap = [String: Int]()
    
    private init() {}
    
    public var deviceModelId: String {

        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        return identifier
        
    }
    
    public var deviceModelNumber: String {
        
        if let number = self.modelNumberMap[self.deviceModelId] {
            return number
        }
        
        return "0"
        
    }
    
    public func deviceModelName(deviceId: UInt32) -> String {
        for (model, id) in modelNumberMap {
            if(id == String(deviceId)){
                return model
            }
        }
        return "Unknown"
    }
    
    public func downloadProfiles() {
        
        let getPhoneModelsRequest = GetPhoneModelsRequest()
        Network.request(router: getPhoneModelsRequest) { (result: Result<Data, Error>) in
            guard case .success(_) = result else {
                if self.modelNumberMap.count == 0 {
                    self.loadDefaultPhoneModels()
                }
                self.downloadDistanceProfile()
                return
            }
            do {
                let jsonData = try result.get()
                if let map = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String] {
                    self.modelNumberMap = map
                }
            }
            catch {
                if self.modelNumberMap.count == 0 {
                    self.loadDefaultPhoneModels()
                }
            }
            
            self.downloadDistanceProfile()
        }
        
    }
    
    public func loadDefaultPhoneModels() {
        
        guard let modelNumberMapURL = Bundle.main.url(forResource: "phone_models", withExtension: "json") else {
            return
        }
        
        do {
            let jsonNumbersData = try Data(contentsOf: modelNumberMapURL)
            if let modelsMap = try JSONSerialization.jsonObject(with: jsonNumbersData, options: []) as? [String: String] {
                self.modelNumberMap = modelsMap
            }
        }
        catch {}
        
    }
    
    private func downloadDistanceProfile() {
        
        let getProfileRequest = GetDistanceProfileRequest(modelId: self.deviceModelNumber)
        Network.request(router: getProfileRequest) { (result: Result<Data, Error>) in
            guard case .success(_) = result else {
                if self.distanceMap.count == 0 {
                    self.loadDefaultProfile()
                }
                return
            }
            do {
                let jsonData = try result.get()
                if let map = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    for key in map.keys {
                        if let value = map[key] as? Int {
                            self.distanceMap[key] = value
                        }
                    }
                }
            }
            catch {
                if self.distanceMap.count == 0 {
                    self.loadDefaultProfile()
                }
            }
        }
        
    }
    
    private func loadDefaultProfile() {
        
        guard let profileMapURL = Bundle.main.url(forResource: "distance_profile", withExtension: "json") else {
            return
        }
        
        do {
            let jsonData = try Data(contentsOf: profileMapURL)
            if let map = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any], let profileMap = map[self.deviceModelNumber] as? [String: Any] {
                for key in profileMap.keys {
                    if let value = profileMap[key] as? Int {
                        self.distanceMap[key] = value
                    }
                }
            }
        }
        catch {}
    }
    
    public func distance(forDeviceModel model: String) -> Int {
        
        if let distance = self.distanceMap[model] {
            return distance
        }
        
        if let distance = self.distanceMap["0"] {
            return distance
        }
        
        return 0
        
    }
    
}
