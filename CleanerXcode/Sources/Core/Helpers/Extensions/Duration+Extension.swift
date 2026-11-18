//
//  Duration+Extension.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

nonisolated extension Duration {

    /// The duration in seconds, for the APIs and dates that take a `TimeInterval`.
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components

        return TimeInterval(seconds) + TimeInterval(attoseconds) * 1e-18
    }

}
