//
//  SubmitCalibrationDataRequest.swift
//  CovidWatch iOS
//
//  Created by Zane Schepke on 7/19/20.
//

struct SubmitCalibrationDataRequest: Request {
    let deviceModel: Int
    let contactDeviceModel: Int
    let distanceDetected: Double

    var path: String { "/api/v1/interaction_calibration" }
    var method: String { "POST" }

    var body: RequestBody? {
        return SubmitCalibrationDataRequestBody(deviceModel: deviceModel,
                                                contactDeviceModel: contactDeviceModel,
                                            distanceDetected: distanceDetected)
    }
}

struct SubmitCalibrationDataRequestBody: RequestBody {

    let deviceModel: Int
    let contactDeviceModel: Int
    let distanceDetected: Double

    enum CodingKeys: String, CodingKey {
        case deviceModel = "device_model"
        case contactDeviceModel = "contact_device_model"
        case distanceDetected = "distance_detected"
    }

    func toJSONData() -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(self)
    }
}

