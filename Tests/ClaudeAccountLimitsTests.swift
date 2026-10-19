// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum ClaudeAccountLimitsTests {
    static func run(_ suite: TestSuite) {
        let manager = FileManager.default
        let home = manager.temporaryDirectory.appendingPathComponent("claude-accounts-" + UUID().uuidString)
        defer { try? manager.removeItem(at: home) }
        do {
            try manager.createDirectory(at: home, withIntermediateDirectories: true)
            suite.expect(ClaudeAccountProfile.discover(home: home, defaultName: "Default").isEmpty,
                         "No Claude account cards without a profile")
            try Data("{}".utf8).write(to: home.appending(path: ".claude.json"))
            suite.expect(ClaudeAccountProfile.discover(home: home, defaultName: "Default").isEmpty,
                         "The usual ~/.claude alone keeps the provider's own card")
            for name in [".claude-work", ".claude-nik"] {
                let folder = home.appending(path: name)
                try manager.createDirectory(at: folder.appending(path: "projects"), withIntermediateDirectories: true)
                try Data("{}".utf8).write(to: folder.appending(path: ".claude.json"))
            }
            // A plugin's data folder is no profile.
            try manager.createDirectory(at: home.appending(path: ".claude-mem/projects"), withIntermediateDirectories: true)

            let profiles = ClaudeAccountProfile.discover(home: home, defaultName: "Default")
            suite.expect(profiles.map(\.name) == ["Default", "Nik", "Work"], "Each Claude profile gets a named card")
            suite.expect(profiles.allSatisfy { $0.provider == .claude }, "Claude profiles are marked as Claude")
            suite.expect(ClaudeAccountProfile.configHome(profiles[0], home: home) == home
                && ClaudeAccountProfile.configHome(profiles[2], home: home).lastPathComponent == ".claude-work",
                         "The usual profile reads ~/.claude.json, others their own folder's")
            suite.expect(CodexAccountProfile.decode(CodexAccountProfile.encode(profiles)).isEmpty,
                         "Claude profiles are never restored from saved Codex homes")

            let roots = AgentLogRoot.all(home: home).filter { $0.provider == .claude }.map(\.url.lastPathComponent)
            let parents = AgentLogRoot.all(home: home).filter { $0.provider == .claude }
                .map { $0.url.deletingLastPathComponent().lastPathComponent }
            suite.expect(roots.allSatisfy { $0 == "projects" } && parents.contains(".claude-work")
                && parents.contains(".claude-nik") && !parents.contains(".claude-mem"),
                         "Spend reads every Claude profile's logs")

            let tiles = NotchAgentSupport.tiles(cards: [.limits], providers: [.claude], claudeAccounts: profiles.map(\.id))
            suite.expect(tiles.map(\.accountID) == profiles.map(\.id), "Each Claude profile has a limits card")
        } catch { suite.expect(false, "Claude account contract: \(error)") }
    }
}
