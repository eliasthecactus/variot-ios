//
//  Item.swift
//  variot
//
//  Created by Elias Frehner on 04.09.2024.
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
