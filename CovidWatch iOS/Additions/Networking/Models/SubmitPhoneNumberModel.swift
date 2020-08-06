//
//  SubmitPhoneNumberModel.swift
//  CovidWatch
//
//  Created by Christopher McGraw on 6/3/20.
//

struct SubmitPhoneNumberModel: Codable {
    let id: String
    let phoneNumber: String
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case phoneNumber = "phonenumber"
        case isPrimary = "is_primary"
    }
}
