--[[
    DMS - Koerperteile. Index = Hitgroup von Garry's Mod (1 Kopf, 2 Brust,
    3 Bauch, 4 linker Arm, 5 rechter Arm, 6 linkes Bein, 7 rechtes Bein).
    Brust und Bauch zeigt die Oberflaeche zusammen als Rumpf.
]]

DMS = DMS or {}

DMS.BodyParts = {
    [1] = {name = "Kopf", image = "head", limb = false},
    [2] = {name = "Rumpf", image = "torso", limb = false},
    [3] = {name = "Bauch", image = "torso", limb = false, mergeInto = 2},
    [4] = {name = "Linker Arm", image = "arm_left", limb = true},
    [5] = {name = "Rechter Arm", image = "arm_right", limb = true},
    [6] = {name = "Linkes Bein", image = "leg_left", limb = true},
    [7] = {name = "Rechtes Bein", image = "leg_right", limb = true},
}

-- Gehoert eine Verletzung an "wo" zum gewaehlten Koerperteil? (Rumpf = Brust + Bauch)
function DMS.PartMatches(selected, wo)
    if selected == wo then return true end
    return selected == 2 and wo == 3
end
