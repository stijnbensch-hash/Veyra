//
//  PlayableSource 2.swift
//  Veyra
//
//  Created by Stijn Bensch on 16/09/2026.
//


import Foundation

struct PlayableSource: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    let kind: SourceKind

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        kind: SourceKind
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.kind = kind
    }
}

enum SourceKind: String, Hashable {
    case usenet
    case debrid
    case liveTV
    case direct
}