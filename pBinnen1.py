path = "Shared/Bento/VeyraBentoHome.swift"
s = open(path).read()

# 1. Update body: wrap volgende + binnenkort + grid in the same TimelineView, pulling
#    "Verder kijken" and "Binnenkort" out as fixed sections above the reorderable grid.
old_body = '''                TimelineView(.periodic(from: .now, by: 30)) { context in
                    bento(now: context.date)
                }'''
assert s.count(old_body) == 1
new_body = '''                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: 32) {
                        if showContinueWatching, !model.home.continueItems.isEmpty {
                            volgendeSection(items: model.home.continueItems)
                        }

                        if showUpcoming, let today = model.today(at: context.date) {
                            binnenkortSection(today, now: context.date)
                        }

                        bento(now: context.date)
                    }
                }'''
assert s.count(old_body) == 1
s = s.replace(old_body, new_body)

open(path, "w").write(s)
print("ok")
