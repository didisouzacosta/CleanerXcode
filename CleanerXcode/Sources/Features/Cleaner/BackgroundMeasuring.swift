//
//  BackgroundMeasuring.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// What the background scheduler needs from the window's state (C40).
protocol BackgroundMeasuring: AnyObject {

    /// When the last complete measurement, from any origin, ended.
    var lastMeasuredAt: Date? { get }

    /// Measures without showing the rows as measuring again; does nothing while another
    /// measurement or a cleanup runs.
    func measureInBackground() async

}

extension CleanerViewModel: BackgroundMeasuring {}
