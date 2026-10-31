//
//  String+ErrorExtension.swift
//  CleanXCode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

extension String: @retroactive Error {}
extension String: @retroactive LocalizedError {

    nonisolated public var errorDescription: String? {
        self
    }

}
