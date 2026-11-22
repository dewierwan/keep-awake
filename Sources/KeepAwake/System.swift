import CoreGraphics
import Foundation
import IOKit
import IOKit.ps
import IOKit.pwr_mgt
import os

let log = Logger(subsystem: "com.dewierwan.keep-awake", category: "app")

/// The kernel's "don't sleep when the lid is closed" switch.
///
/// This is the same undocumented call other keep-awake apps use
/// (`kPMSetClamshellSleepState` on the power management root domain). It is a
/// plain on/off switch shared with macOS itself, which is why `LidPolicy`
/// decides when it is safe to turn off.
enum LidSwitch {
    @discardableResult
    static func set(on: Bool) -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else {
            log.error("Lid switch: power management service not found")
            return false
        }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else {
            log.error("Lid switch: could not open the power management service")
            return false
        }
        defer { IOServiceClose(connection) }

        let input: [UInt64] = [on ? 1 : 0]
        var outputCount: UInt32 = 0
        let result = IOConnectCallScalarMethod(
            connection, UInt32(kPMSetClamshellSleepState), input, 1, nil, &outputCount
        )
        if result == KERN_SUCCESS {
            log.notice("Lid switch turned \(on ? "on" : "off", privacy: .public)")
        } else {
            log.error("Lid switch: call failed with \(result)")
        }
        return result == KERN_SUCCESS
    }
}

/// Holds the ordinary "don't sleep while idle" requests for a session.
final class SleepBlocker {
    private var ids: [IOPMAssertionID] = []

    var isHolding: Bool { !ids.isEmpty }

    func hold() {
        guard ids.isEmpty else { return }
        for type in [kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionTypePreventUserIdleDisplaySleep] {
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Keep Awake session" as CFString, &id
            )
            if result == kIOReturnSuccess { ids.append(id) }
        }
    }

    func release() {
        ids.forEach { IOPMAssertionRelease($0) }
        ids.removeAll()
    }
}

/// Facts about the Mac that the session rules depend on.
enum Machine {
    /// True when the Mac is set up as a desktop: on mains power, with a display
    /// other than the built-in one. This is when macOS itself keeps a closed
    /// Mac awake, so it is when the lid switch belongs to macOS.
    ///
    /// Mains power is part of the test for a safety reason. With the lid closed
    /// and nothing plugged in, macOS creates a stand-in display that is not
    /// built in, so a display check alone would call a Mac in a bag "at a desk"
    /// and leave it awake after a session ends. A Mac in a bag is on battery.
    static var atDesk: Bool { onMainsPower && !otherDisplays.isEmpty }

    static var onMainsPower: Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        else { return false }
        return providing == kIOPSACPowerValue
    }

    /// Displays that are connected, awake or asleep, and are not the built-in one.
    static var otherDisplays: [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).filter { CGDisplayIsBuiltin($0) == 0 }
    }

    /// One line describing every connected display, for the log and `--status`.
    static var displaySummary: String {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return "none" }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return "none" }
        return displays.prefix(Int(count)).map { id in
            let kind = CGDisplayIsBuiltin(id) != 0 ? "built-in" : "other"
            let size = CGDisplayScreenSize(id)
            return "\(kind) id=\(id) vendor=\(CGDisplayVendorNumber(id)) model=\(CGDisplayModelNumber(id)) "
                + "\(CGDisplayPixelsWide(id))x\(CGDisplayPixelsHigh(id)) \(Int(size.width))x\(Int(size.height))mm"
        }.joined(separator: "; ")
    }

    /// Battery charge in percent while running on battery; nil on mains power
    /// or on a Mac with no battery.
    static var batteryPercentWhileOnBattery: Int? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?,
              providing == kIOPSBatteryPowerValue,
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return current * 100 / max
        }
        return nil
    }

    /// True when the lid is closed. Only used for the status readout.
    static var lidClosed: Bool? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Bool
    }
}
