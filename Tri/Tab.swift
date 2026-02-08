//
//  Tab.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import Foundation

enum Tab: String, CaseIterable {
    case home = "Home"
    case calendar = "Calendar"
    case statistics = "Statistics"
    case profile = "Profile"

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .calendar:
            return "calendar"
        case .statistics:
            return "chart.bar.fill"
        case .profile:
            return "person.fill"
        }
    }
}
