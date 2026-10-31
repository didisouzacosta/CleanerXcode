//
//  Bundle+Extension.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 04/04/25.
//

import Foundation

private final class TestBundleToken {}

extension Bundle {

    static let test = Bundle(for: TestBundleToken.self)

}
