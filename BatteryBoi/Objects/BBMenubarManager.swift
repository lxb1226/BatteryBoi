//
//  BBMenuManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 12/6/23.
//

import Foundation
import Combine
import Cocoa
import SwiftUI
import DynamicColor

enum MenubarScheme:String,CaseIterable {
    case monochrome
    case polychrome
    
    var warning:Color {
        switch self {
            case .monochrome : return Color("BatteryDefault").opacity(0.7)
            case .polychrome : return Color(hexString: "#ed7671")

        }
        
    }
    
    var efficient:Color {
        switch self {
            case .monochrome : return Color("BatteryDefault")
            case .polychrome : return Color("BatteryEfficient")

        }
        
    }
    
}

enum MenubarStyle:String,CaseIterable {
    case original
    case transparent
    case text
    
    var size:CGSize {
        return .init(width: 32, height: 15)
        
    }
    
    var font:CGFloat {
        switch self {
            case .original : return 11
            case .transparent : return 11
            case .text : return 14

        }
        
    }
    
    var kerning:CGFloat {
        switch self {
            case .original : return -0.4
            case .transparent : return -0.4
            case .text : return 1.0

        }
        
    }
    
    var spacing:CGFloat {
        switch self {
            case .original : return 0.5
            case .transparent : return 0.5
            case .text : return 1.0

        }
        
    }
    
    var icon:CGSize {
        switch self {
            case .original : return .init(width: 5, height: 8)
            case .transparent : return .init(width: 5, height: 8)
            case .text : return .init(width: 7, height: 10)

        }
        
    }
    
    var padding:CGFloat {
        switch self {
            case .original : return 1.6
            case .transparent : return 1.6
            case .text : return 0.0

        }
        
    }
    
    var stub:CGFloat {
        switch self {
            case .original : return 0.6
            case .transparent : return 0.4
            case .text : return 0.0

        }
        
    }
    
    var background:CGFloat {
        switch self {
            case .original : return 1.0
            case .transparent : return 0.4
            case .text : return 0.0
            
        }
        
    }
    
    var foreground:CGFloat {
        switch self {
            case .original : return 1.0
            case .transparent : return 1.0
            case .text : return 0.0
            
        }
        
    }
    
    var text:Color {
        switch self {
            case .original : return Color.black
            case .transparent : return Color.black
            case .text : return Color("BatteryDefault")
            
        }
        
    }
    
}

enum MenubarDisplayType:String,CaseIterable {
    case countdown
    case empty
    case percent
    case voltage
    case cycle
    case hidden
    
    var type:String {
        switch self {
            case .countdown : return "SettingsDisplayEstimateLabel".localise()
            case .percent : return "SettingsDisplayPercentLabel".localise()
            case .empty : return "SettingsDisplayNoneLabel".localise()
            case .cycle : return "SettingsDisplayCycleLabel".localise()
            case .voltage : return "SettingsDisplayVoltageLabel".localise()
            case .hidden : return "SettingsDisplayHiddenLabel".localise()

        }
        
    }
    
    var icon:String {
        switch self {
            case .countdown : return "TimeIcon"
            case .percent : return "PercentIcon"
            case .cycle : return "CycleIcon"
            case .voltage : return "CycleIcon"
            case .empty : return "EmptyIcon"
            case .hidden : return "EmptyIcon"

        }
        
    }
    
}

enum MenubarProgressType:String,CaseIterable {
    case progress
    case full
    case empty
    
    var description:String {
        switch self {
            case .progress : return "SettingsProgressDynamicLabel".localise()
            case .full : return "SettingsProgressFullLabel".localise()
            case .empty : return "SettingsProgressEmptyLabel".localise()
            
        }
        
    }
    
}

enum MenubarAppendType {
    case add
    case remove
    
    var device:String {
        switch self {
            case .add : return "ADDED"
            case .remove : return "REMOVED"
            
        }
        
    }
    
}

class MenubarManager:ObservableObject {
    static var shared = MenubarManager()

    @Published var primary:String? = nil
    @Published var seconary:String? = nil
    @Published var progress:MenubarProgressType = .progress
    @Published var animation:Bool = true
    @Published var radius:CGFloat = 6
    @Published var style:MenubarStyle = .transparent
    @Published var scheme:MenubarScheme = .monochrome

    private var updates = Set<AnyCancellable>()

    init() {
        UserDefaults.changed.receive(on: DispatchQueue.main).sink { key in
            #if os(macOS)
                if key.rawValue.contains("mbar") == true {
                    self.menubarUpdateValues()

                }
            
            #endif
                           
        }.store(in: &updates)
        
        BatteryManager.shared.$percentage.removeDuplicates().receive(on: DispatchQueue.main).sink() { newValue in
            self.menubarUpdateValues()

        }.store(in: &updates)
        
        BatteryManager.shared.$charging.removeDuplicates().receive(on: DispatchQueue.main).sink() { newValue in
            self.menubarUpdateValues()

        }.store(in: &updates)

        BatteryManager.shared.$temperature.receive(on: DispatchQueue.main).sink() { newValue in
            self.menubarUpdateValues()

        }.store(in: &updates)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.menubarUpdateValues()

        }
        
    }
    
    deinit {
        self.updates.forEach { $0.cancel() }
        
    }
    
    private func menubarUpdateValues() {
        let percentage = BatteryManager.shared.percentage
        let primary = self.menubarPrimaryDisplay
        let seconary = self.menubarSecondaryDisplay
        
        switch primary {
            case .percent : self.primary = "\(Int(percentage))"
            case .voltage : self.primary = "v"
            case .cycle : self.primary = "c"
            case .countdown : self.primary = "TBA"
            case .hidden : self.primary = nil
            default : self.primary = ""
            
        }
        
        switch seconary {
            case .percent : self.seconary = "\(Int(percentage))"
            case .voltage : self.seconary = "v"
            case .cycle : self.seconary = "c"
            case .countdown : self.seconary = "TBA"
            case .hidden : self.seconary = nil
            default : self.seconary = ""
            
        }
        
        self.progress = self.menubarProgressBar
        self.animation = self.menubarPulsingAnimation
        self.style = self.menubarStyle
        self.radius = CGFloat(self.menubarRadius)
        self.scheme = self.menubarSchemeType
        
    }
    
    private func menubarDevices() -> [SystemDeviceObject] {
        return []
        
    }
    
    public var menubarStyle:MenubarStyle {
        get {
            if let value = UserDefaults.main.object(forKey: SystemDefaultsKeys.menubarStyle.rawValue) as? String {
                return MenubarStyle(rawValue: value) ?? .transparent
                
            }
           
            return .transparent
        
        }
        
        set {
            UserDefaults.save(.menubarRadius, value: nil)
            UserDefaults.save(.menubarStyle, value: newValue.rawValue)

        }
        
    }
    
    public var menubarRadius:Float {
        get {
            if UserDefaults.main.object(forKey: SystemDefaultsKeys.menubarRadius.rawValue) == nil {
                return 5.0
                
            }
            else {
                return UserDefaults.main.float(forKey: SystemDefaultsKeys.menubarRadius.rawValue)
                
            }
        
        }
        
        set {
            switch newValue {
                case let x where x < 2:  UserDefaults.save(.menubarRadius, value: 2)
                case let x where x > 8: UserDefaults.save(.menubarRadius, value: 8)
                default : UserDefaults.save(.menubarRadius, value: newValue)
                
            }
        
        }
        
    }
    
    public var menubarPulsingAnimation:Bool {
        get {
            if UserDefaults.main.object(forKey: SystemDefaultsKeys.menubarAnimation.rawValue) == nil {
                return true
                
            }
            else {
                return UserDefaults.main.bool(forKey: SystemDefaultsKeys.menubarAnimation.rawValue)
                
            }
        
        }
        
        set {
            UserDefaults.save(.menubarAnimation, value: newValue)
            
        }
        
    }
    
    public var menubarProgressBar:MenubarProgressType {
        get {
            if let type = UserDefaults.main.string(forKey: SystemDefaultsKeys.menubarProgress.rawValue) {
                return MenubarProgressType(rawValue: type) ?? .progress
                
            }
            
            return .progress
        
        }
        
        set {
            UserDefaults.save(.menubarProgress, value: newValue.rawValue)
            
        }
        
    }
    
    public var menubarSchemeType:MenubarScheme {
        get {
            if let type = UserDefaults.main.string(forKey: SystemDefaultsKeys.menubarScheme.rawValue) {
                return MenubarScheme(rawValue: type) ?? .monochrome
                
            }
            
            return .monochrome
        
        }
        
        set {
            UserDefaults.save(.menubarScheme, value: newValue.rawValue)
            
        }
        
    }
    
    public var menubarPrimaryDisplay:MenubarDisplayType {
        set {
            UserDefaults.save(.menubarPrimary, value: newValue.rawValue)

        }
        
        get {
            var output:MenubarDisplayType = .percent
            
            if let type = UserDefaults.main.string(forKey: SystemDefaultsKeys.menubarPrimary.rawValue) {
                output = MenubarDisplayType(rawValue: type) ?? .percent
                
            }
            
            if BatteryManager.shared.charging == .charging {
                if output != .hidden && output != .empty {
                    output = .percent
                    
                }
                
            }
            
            if AppManager.shared.appDeviceType.battery == false {
                output = .voltage

            }
                
            #if MAINTARGET
                switch output {
                    case .hidden : NSApp.setActivationPolicy(.regular)
                    default : NSApp.setActivationPolicy(.accessory)
                    
                }
            
            #endif
            
            return output
            
        }
        
    }
    
    public var menubarSecondaryDisplay:MenubarDisplayType {
        set {
            UserDefaults.save(.menubarSecondary, value: newValue.rawValue)

        }
        
        get {
            var output:MenubarDisplayType = .countdown
            
            if let type = UserDefaults.main.string(forKey: SystemDefaultsKeys.menubarPrimary.rawValue) {
                output = MenubarDisplayType(rawValue: type) ?? .countdown
                
            }
            
            if AppManager.shared.appDeviceType.battery == false {
                output = .hidden

            }
            
            if self.menubarPrimaryDisplay == .empty {
                output = .percent

            }
            else if self.menubarPrimaryDisplay == output {
                output = .hidden

            }
            
            return output

        }
        
    }
    
    public func menubarAppendDevices(_ device:SystemDeviceObject, state:MenubarAppendType) -> String {
        if let _ = AppManager.shared.appStorageContext() {
            
        }
        
        return "\n\u{001B}[1m\u{001B}[32m\("ADDED DEVICE")\u{001B}[0m\n"

    }
    
    public func menubarReset() {
        UserDefaults.save(.menubarPrimary, value: nil)
        UserDefaults.save(.menubarSecondary, value: nil)
        UserDefaults.save(.menubarRadius, value: nil)
        UserDefaults.save(.menubarProgress, value: nil)
        UserDefaults.save(.menubarAnimation, value: nil)
        UserDefaults.save(.menubarScheme, value: nil)
        UserDefaults.save(.menubarStyle, value: nil)

    }
    
}

