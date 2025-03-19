//
//  Data+Decoder.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 19/03/25.
//

import Foundation

extension Data {
    
    func decoder<T: Decodable>(decoder: JSONDecoder = .init()) throws -> T {
        try decoder.decode(T.self, from: self)
    }
    
}
