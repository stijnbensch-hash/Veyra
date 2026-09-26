path = "Shared/Bento/VeyraBentoHome.swift"
s = open(path).read()

old_grid_open = '''        VeyraBentoGrid(profile: profile) {
            if present.contains(.volgende) {
                VStack(alignment: .leading, spacing: 4) {
                    // Subtiele titel boven de rij, i.p.v. los per tegel.
                    Text("Verder kijken")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundStyle(VeyraHomeStyle.cyan.opacity(0.85))
                        .padding(.horizontal, 12)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(items) { item in
                                continueButton(item, radius: 22) { VeyraBentoContinueMiniContent(item: item) }
                                    .frame(width: 750, height: 258)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                    }
                    .scrollClipDisabled()
                }
                .bentoCell(profile.cell(.volgende))
            }

'''
assert s.count(old_grid_open) == 1
new_grid_open = '''        VeyraBentoGrid(profile: profile) {
'''
s = s.replace(old_grid_open, new_grid_open)

old_vandaag = '''            if present.contains(.vandaag), let today {
                cell(.vandaag, profile, action: { if let first = today.items.first { toggle(first) } }) {
                    VeyraBentoTodayContent(today: today, now: now, reminders: model.home.reminderIDs)
                }
                .contextMenu {
                    ForEach(today.items) { item in
                        let on = model.home.reminderIDs.contains(item.id)
                        Button { toggle(item) } label: {
                            Label(on ? "Herinnering uit · \\(item.title)" : "Herinner mij · \\(item.title)",
                                  systemImage: on ? "bell.slash" : "bell")
                        }
                    }
                }
                .bentoCell(profile.cell(.vandaag))
            }
        }
    }'''
assert s.count(old_vandaag) == 1
new_vandaag = '''        }
    }'''
s = s.replace(old_vandaag, new_vandaag)

open(path, "w").write(s)
print("ok")
