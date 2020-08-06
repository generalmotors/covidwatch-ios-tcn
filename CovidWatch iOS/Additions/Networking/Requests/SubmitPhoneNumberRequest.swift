//
//  SubmitPhoneNumberRequest.swift
//  CovidWatch
//
//  Created by Christopher McGraw on 6/3/20.
//

struct SubmitPhoneNumberRequest: Request {
    let phoneNumber: String
    let isPrimary: Bool

    var path: String { "/api/v1/contact_registration" }
    var method: String { "POST" }

    var body: RequestBody? {
        return SubmitPhoneNumberRequestBody(phoneNumber: phoneNumber,
                                            isPrimary: isPrimary,
                                            registrationTime: Date())
    }
}

struct SubmitPhoneNumberRequestBody: RequestBody {

    let phoneNumber: String
    let isPrimary: Bool
    let registrationTime: Date

    enum CodingKeys: String, CodingKey {
        case phoneNumber = "phone_number"
        case isPrimary = "is_primary"
        case registrationTime = "registration_time"
    }

    func toJSONData() -> Data? {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        encoder.dateEncodingStrategy = .formatted(formatter)

        return try? encoder.encode(self)
    }
}
