/// What to do with the kernel's "don't sleep when the lid is closed" switch.
public enum LidAction: Equatable {
    /// Turn the switch on.
    case hold
    /// Turn the switch off.
    case release
    /// Don't touch it.
    case leaveAlone
}

/// The one rule this app exists for.
///
/// The kernel has a single on/off switch for "don't sleep when the lid is
/// closed". macOS uses that switch itself while the Mac is at a desk (on mains
/// power with an external display), and it does not notice if someone else
/// turns it off. So when a session ends at a desk we must not turn the switch
/// off: doing so puts the Mac to sleep in the middle of work.
///
/// - Parameters:
///   - sessionActive: a Keep Awake session is running.
///   - atDesk: on mains power with an external display, so macOS owns the switch.
///   - weTurnedItOn: this app turned the switch on and has not yet turned it
///     off. Without this we would have nothing to hand back.
public func lidAction(
    sessionActive: Bool,
    atDesk: Bool,
    weTurnedItOn: Bool
) -> LidAction {
    if sessionActive { return .hold }
    if !weTurnedItOn { return .leaveAlone }
    return atDesk ? .leaveAlone : .release
}
