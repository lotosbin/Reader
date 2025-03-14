//
//  Item.swift
//  reader
//
//  Created by 刘斌斌 on 3/14/25.
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
