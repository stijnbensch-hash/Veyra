// VeyraSportsLiveStage.swift — gedeeld (tvOS 17+ / iOS 17+ / macOS 14+)
// "Live Voor Jou" -- belangrijkste dynamische sectie van de Sport-redesign (spec §15-20, fase 5).
// Eén grote stage (hergebruikt de bestaande `VeyraSportsStage`, geen tweede visuele implementatie
// -- spec §42) + bij meerdere live wedstrijden een rij kleine chips eronder. Focus op een chip
// promoveert die wedstrijd naar de grote stage (spec §20), met rustige reflow i.p.v. een harde
// carrousel-wissel. Volgorde van `events` (team > league > overig) komt van
// `VeyraSportViewModel.liveForYou(...)`, hier enkel weergegeven.

import SwiftUI

struct VeyraSportsLiveStage: View {
    let events: [SportEvent]
    let now: Date
    let onPlay: (SportEvent) -> Void

    #if os(tvOS)
    @FocusState private var focusedID: String?
    #endif
    @State private var tappedID: String?

    private var bigID: String? {
        #if os(tvOS)
        focusedID ?? events.first?.id
        #else
        tappedID ?? events.first?.id
        #endif
    }

    private var bigEvent: SportEvent? {
        events.first(where: { $0.id == bigID }) ?? events.first
    }

    private var otherEvents: [SportEvent] {
        events.filter { $0.id != bigEvent?.id }
    }

    var body: some View {
        if let bigEvent {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Circle().fill(VeyraColors.red).frame(width: 7, height: 7)
                    Text("Live voor jou")
                        .font(.system(size: headerSize, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .textCase(.uppercase)
                }
                .foregroundStyle(VeyraColors.red.opacity(0.85))

                VeyraSportsStage(event: bigEvent, now: now) { onPlay(bigEvent) }
                    .id(bigEvent.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .animation(.easeOut(duration: 0.3), value: bigEvent.id)

                if !otherEvents.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: chipGap) {
                            ForEach(otherEvents) { event in
                                chip(event)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                    }
                    .scrollClipDisabled()
                }
            }
        }
    }

    @ViewBuilder
    private func chip(_ event: SportEvent) -> some View {
        #if os(tvOS)
        Button { } label: { chipContent(event) }
            .buttonStyle(VeyraStreamingTileStyle())
            .focused($focusedID, equals: event.id)
        #else
        Button { tappedID = event.id } label: { chipContent(event) }
            .buttonStyle(.plain)
        #endif
    }

    private func chipContent(_ event: SportEvent) -> some View {
        HStack(spacing: 10) {
            Circle().fill(VeyraColors.red).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: chipTitleSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let score = event.score {
                    Text(score.text)
                        .font(.system(size: chipMetaSize, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: chipMinWidth, alignment: .leading)
        .background(VeyraColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(VeyraColors.red.opacity(0.3), lineWidth: 1)
        )
    }

    #if os(tvOS)
    private let headerSize: CGFloat = 19
    private let chipGap: CGFloat = 16
    private let chipTitleSize: CGFloat = 16
    private let chipMetaSize: CGFloat = 14
    private let chipMinWidth: CGFloat = 200
    #else
    private let headerSize: CGFloat = 13
    private let chipGap: CGFloat = 10
    private let chipTitleSize: CGFloat = 13
    private let chipMetaSize: CGFloat = 12
    private let chipMinWidth: CGFloat = 140
    #endif
}
