//
//  SubmitCalibrationDataModel.swift
//  CovidWatch iOS
//
//  Created by Zane Schepke on 7/19/20.
//

struct SubmitCalibrationDataModel: Codable {
    let interactionId: CLong
    let deviceModel: Int
    let contactDeviceModel: Int
    let distanceDetected: Double
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case interactionId = "id"
        case deviceModel = "device_model"
        case contactDeviceModel = "contact_device_model"
        case distanceDetected = "distance_detected"
        case createdAt = "created_at"
    }
}

