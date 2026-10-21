--[[
    DMS - Medikamente.

    Autoinjektoren gehen an Rumpf, Arme und Beine (nicht an den Kopf),
    Infusionen ("IV") nur an einen Koerperteil mit gelegtem Zugang.
    Waehrend der Wirkdauer ("duration", Sekunden) wirken sie auf:
      puls, bp   Faktor (+0.2 = 20 % hoeher)
      spo2       Punkte auf die Sauerstoffsaettigung
      relief     Schmerzlinderung (Stufen)
      antibiotic bekaempft Infektionen
    Dazu einmalige Wirkungen: wake (Betaeubung aufheben), sedate (Koma),
    revive (Bewusstlose wecken), fluids (Liter Fluessigkeit), depress
    (Gefahr einer Atemdepression ohne Schmerzen).
]]

DMS = DMS or {}

local function route(kind)
    if kind == "injector" then
        return function(actor, tbl, part) return part > 1 end
    end
    return function(actor, tbl, part)
        local bp = tbl.body_part and tbl.body_part[part]
        return bp ~= nil and bp.has_iv == true
    end
end

-- Medikament in den Kreislauf des Patienten
function DMS.AddMedication(actor, tbl, med)
    tbl.medication = tbl.medication or {}
    table.insert(tbl.medication, {
        id = med.id, name = med.name, administered = os.time(), duration = med.duration or 0,
        puls = med.puls or 0, spo2 = med.spo2 or 0, bp = med.bp or 0, relief = med.relief or 0,
        antibiotic = med.antibiotic or nil,
    })
end

local function M(id, name, kind, t)
    t.id, t.name, t.kind, t.medic = id, name, kind, true
    t.time = t.time or (kind == "injector" and 5 or 15)
    t.condition = route(kind)
    t.effect = function(actor, tbl, part, patient)
        if t.wake then tbl.stunning_level = 0 tbl.breathing_depressed_until = nil end
        if t.sedate then tbl.stunning_level = 1 end
        if t.fluids then tbl.blood_to_add = (tbl.blood_to_add or 0) + t.fluids end
        if t.depress and (tbl.pain_level or 0) <= 0.5 and math.random() < t.depress then
            tbl.breathing_depressed_until = os.time() + 90
        end
        if t.revive and IsValid(patient) and not patient:Alive() and DMS.Revive then
            -- Aufwachen nur, wenn die Werte es zulassen; sonst bleibt der Wachmacher im Blut
            tbl.stunning_level = 0
            tbl.revive_boost = os.time() + 30
        end
        if (t.duration or 0) > 0 then DMS.AddMedication(actor, tbl, t) end
    end
    return t
end

DMS.Medication = {
    M("quick_wake_ai", "Quick Wake (Autoinjektor)", "injector", {wake = true}),
    M("quick_wake_iv", "Quick Wake (IV)", "iv", {wake = true, revive = true, duration = 60, puls = 0.3, spo2 = 2, bp = 0.3}),
    M("nullicaine_ai", "Nullicaine (Autoinjektor)", "injector", {duration = 180, relief = 1, puls = 0.05, bp = 0.1}),
    M("nullicaine_iv", "Nullicaine (IV)", "iv", {duration = 300, relief = 2, puls = 0.1, bp = 0.15}),
    M("kouhunin_ai", "Kouhunin (Autoinjektor)", "injector", {duration = 300, relief = 3, puls = -0.15, bp = 0.1, depress = 0.1}),
    M("kouhunin_iv", "Kouhunin (IV)", "iv", {duration = 600, relief = 5, puls = -0.3, bp = 0.15, depress = 0.33}),
    M("adrenalin_ai", "Adrenalin (Autoinjektor)", "injector", {duration = 60, puls = 0.5, spo2 = 1, bp = 0.3}),
    M("adrenalin_iv", "Adrenalin (IV)", "iv", {duration = 180, puls = 0.8, spo2 = 2, bp = 0.5}),
    M("kryotin_iv", "Kryotin (IV, künstliches Koma)", "iv", {sedate = true}),
    M("anticeptin_ai", "Anticeptin-D (Autoinjektor, Antibiotikum)", "injector", {duration = 300, antibiotic = true}),
    M("anticeptin_iv", "Anticeptin-D (IV, Antibiotikum)", "iv", {duration = 900, antibiotic = true}),
    M("saline_250", "Kochsalzlösung 250 ml (IV)", "iv", {fluids = 0.25}),
    M("saline_500", "Kochsalzlösung 500 ml (IV)", "iv", {fluids = 0.5}),
    M("saline_1000", "Kochsalzlösung 1000 ml (IV)", "iv", {fluids = 1}),
}
