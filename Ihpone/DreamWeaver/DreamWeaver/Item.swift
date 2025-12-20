//
//  Item.swift
//  DreamWeaver
//
//  Created by Gazsik Jozsef 6035 ED on 20.12.2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
