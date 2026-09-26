path = "Shared/Bento/VeyraBentoHome.swift"
s = open(path).read()
old = '''        add(.volgende, !items.isEmpty)
        add(.live, !live.isEmpty)
        add(.vandaag, hasToday)
        add(.iptvFilms, !model.iptvFilms.isEmpty)'''
assert s.count(old) == 1
new = '''        add(.live, !live.isEmpty)
        add(.iptvFilms, !model.iptvFilms.isEmpty)'''
assert s.count(old) == 1
s = s.replace(old, new)
open(path, "w").write(s)
print("ok")
