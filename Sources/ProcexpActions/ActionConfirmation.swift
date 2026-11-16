//
//  ActionConfirmation.swift
//  ProcexpActions — W8 (process action command layer)
//
//  Pure-data description of whether a given process action warrants a user
//  confirmation prompt. The UI layer (W3) consumes this to decide when to put
//  up a dialog — this module never touches UI itself.
//

import Foundation

/// The set of control actions the command layer can perform on a process.
public enum ProcessActionKind: String, Sendable, Hashable, CaseIterable, Codable {
    case kill
    case killTree
    case suspend
    case resume
    case setNice
    case restart
    case bringToFront
}

/// Metadata telling the UI whether an action should be confirmed before it runs
/// and how to phrase that confirmation. Pure value type — contains no UI.
public struct ActionConfirmation: Sendable, Hashable, Codable {
    public let kind: ProcessActionKind
    /// Whether the UI should present a confirmation prompt before performing it.
    public let requiresConfirmation: Bool
    /// Whether the action is destructive (irreversible loss of the process).
    public let destructive: Bool
    /// Suggested dialog title.
    public let title: String
    /// Suggested dialog body.
    public let message: String

    public init(
        kind: ProcessActionKind,
        requiresConfirmation: Bool,
        destructive: Bool,
        title: String,
        message: String
    ) {
        self.kind = kind
        self.requiresConfirmation = requiresConfirmation
        self.destructive = destructive
        self.title = title
        self.message = message
    }

    /// Build the confirmation metadata for a given action, optionally including a
    /// human-readable process name so the message can be specific.
    public static func forKind(
        _ kind: ProcessActionKind,
        processName: String? = nil
    ) -> ActionConfirmation {
        let target = processName.map { "“\($0)”" } ?? String(localized: "this process", bundle: .module)
        switch kind {
        case .kill:
            return ActionConfirmation(
                kind: kind,
                requiresConfirmation: true,
                destructive: true,
                title: String(localized: "Force Quit Process?", bundle: .module),
                message: String(localized: "Force quit \(target) using SIGKILL? The process cannot save or clean up. Unsaved data may be lost.", bundle: .module)
            )
        case .killTree:
            return ActionConfirmation(
                kind: kind,
                requiresConfirmation: true,
                destructive: true,
                title: String(localized: "Force Quit Process Tree?", bundle: .module),
                message: String(localized: "Force quit \(target) and its descendant processes using SIGKILL? They cannot save or clean up. Unsaved data may be lost.", bundle: .module)
            )
        case .restart:
            return ActionConfirmation(
                kind: kind,
                requiresConfirmation: true,
                destructive: true,
                title: String(localized: "Restart Process?", bundle: .module),
                message: String(localized: "Restarting \(target) will terminate it and launch it again. Unsaved data may be lost, and command-line arguments may not be preserved.", bundle: .module)
            )
        case .suspend:
            return ActionConfirmation(
                kind: kind,
                requiresConfirmation: false,
                destructive: false,
                title: String(localized: "Suspend Process", bundle: .module),
                message: String(localized: "Suspend \(target).", bundle: .module)
            )
        case .resume:
            return ActionConfirmation(
                kind: kind,
                requiresConfirmation: false,
                destructive: false,
                title: String(localized: "Resume Process", bundle: .module),
                message: String(localized: "Resume \(target).", bundle: .module)
            )
        case .setNice:
            return ActionConfirmation(
                kind: kind,
                requiresConfirmation: false,
                destructive: false,
                title: String(localized: "Set Nice Value", bundle: .module),
                message: String(localized: "Set the POSIX nice value of \(target). Lower values request more CPU scheduling preference and may require elevated privileges. This does not change a QoS class.", bundle: .module)
            )
        case .bringToFront:
            return ActionConfirmation(
                kind: kind,
                requiresConfirmation: false,
                destructive: false,
                title: String(localized: "Bring to Front", bundle: .module),
                message: String(localized: "Bring \(target) to the front.", bundle: .module)
            )
        }
    }
}
