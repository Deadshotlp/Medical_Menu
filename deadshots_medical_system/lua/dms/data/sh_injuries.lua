--[[
    DMS - Verletzungen.

    Je Treffer waehlt der Server aus allen passenden Verletzungen (Schadensart
    und Trefferzone) eine nach Gewicht ("weight") aus; je "damage_per_injury"
    Schaden kommt eine weitere dazu. Werte:

      bleeding   Blutverlust je Berechnung (Liter, mal Pulsfaktor)
      pain       Schmerz (Summe aller Verletzungen; ab 1/2/3 leicht/maessig/stark)
      puls, bp   Faktor auf Puls/Blutdruck (+0.2 = 20 % hoeher)
      spo2       Punkte auf die Sauerstoffsaettigung
      breathing  Atemzuege pro Minute weniger (Nervengas)
      heal       Heilzeit in Sekunden; jede Behandlung kuerzt sie anteilig,
                 nach der letzten ist die Verletzung versorgt
      disinfect  offene Wunde: kann sich infizieren, bis sie desinfiziert ist
      fracture   Knochenbruch (Koerperteil zeigt "Fraktur")
      armor      true = Ruestung schuetzt (sonst geht sie durch)
      treatment  noetige Behandlungen (IDs aus sh_treatments.lua)

    Alle Werte (ausser Bedingungen) lassen sich im Konfigurationsmenue
    anpassen; Verletzungen auch abschalten.
]]

DMS = DMS or {}

local function any(dmgTyp, ...)
    for _, flag in ipairs({...}) do
        if bit.band(dmgTyp, flag) ~= 0 then return true end
    end
    return false
end

local TORSO = {[HITGROUP_CHEST] = true, [HITGROUP_STOMACH] = true}
local HEAD = {[HITGROUP_HEAD] = true}
local LIMBS = {[HITGROUP_LEFTARM] = true, [HITGROUP_RIGHTARM] = true, [HITGROUP_LEFTLEG] = true, [HITGROUP_RIGHTLEG] = true}
local ARMS = {[HITGROUP_LEFTARM] = true, [HITGROUP_RIGHTARM] = true}
local LEGS = {[HITGROUP_LEFTLEG] = true, [HITGROUP_RIGHTLEG] = true}
local NOT_HEAD = {[HITGROUP_CHEST] = true, [HITGROUP_STOMACH] = true, [HITGROUP_LEFTARM] = true, [HITGROUP_RIGHTARM] = true,
    [HITGROUP_LEFTLEG] = true, [HITGROUP_RIGHTLEG] = true}
local TORSO_HEAD = {[HITGROUP_CHEST] = true, [HITGROUP_STOMACH] = true, [HITGROUP_HEAD] = true}

local BLASTER = {DMG_BULLET, DMG_PLASMA}
local ENERGY = {DMG_ENERGYBEAM, DMG_DISSOLVE}

-- Kurzform: id, Name, Schadensarten, Trefferzonen (nil = alle), Werte
local list = {}
local function I(id, name, dmg, zones, t)
    t.id, t.name, t.dmg, t.zones = id, name, dmg, zones
    t.weight = t.weight or 10
    t.bleeding, t.pain, t.puls, t.spo2, t.bp = t.bleeding or 0, t.pain or 0, t.puls or 0, t.spo2 or 0, t.bp or 0
    t.breathing = t.breathing or 0
    t.treatment = t.treatment or {}
    list[#list + 1] = t
end

-- Blaster
I("blaster_graze", "Blaster-Streifschuss", BLASTER, nil, {armor = true, disinfect = true, pain = 0.25, puls = 0.1, bp = -0.1, heal = 180,
    treatment = {"bacta_verband", "enkephalin", "dermasel"}})
I("blaster_surface", "Oberflächlicher Blastertreffer", BLASTER, NOT_HEAD, {armor = true, disinfect = true, pain = 0.45, puls = 0.1, bp = -0.1,
    heal = 240, treatment = {"bacta_verband", "enkephalin", "dermasel"}})
I("blaster_torso", "Schwerer Blastertreffer im Rumpf", BLASTER, TORSO, {armor = true, disinfect = true, bleeding = 0.0002, pain = 0.8,
    puls = 0.2, bp = -0.2, heal = 600, treatment = {"bacta_verband", "operativer_eingriff", "enkephalin", "dermasel"}})
I("blaster_head", "Blaster-Kopftreffer", BLASTER, HEAD, {armor = true, disinfect = true, pain = 0.9, puls = 0.2, bp = -0.2, heal = 900,
    treatment = {"bacta_verband", "bacta_tank", "operativer_eingriff", "enkephalin", "dermasel"}})

-- Quetschungen
I("crush_light", "Leichte Quetschung", {DMG_CRUSH}, nil, {armor = true, pain = 0.4, heal = 180, treatment = {"bacta_verband"}})
I("crush_heavy", "Schwere Quetschung", {DMG_CRUSH}, nil, {pain = 0.75, puls = 0.15, bp = -0.2, heal = 360,
    treatment = {"bacta_verband", "operativer_eingriff"}})

-- Explosionen
I("shrapnel_light", "Leichte Splitterverletzung", {DMG_BLAST}, nil, {disinfect = true, bleeding = 0.00008, pain = 0.25, puls = 0.2, bp = -0.2,
    heal = 600, treatment = {"oberflaechige_splitter_entfernen", "synth_fleisch", "bacta_verband"}})
I("shrapnel_heavy", "Schwere Splitterverletzung", {DMG_BLAST}, nil, {disinfect = true, bleeding = 0.0005, pain = 0.75, puls = 0.2, bp = -0.2,
    heal = 900, treatment = {"oberflaechige_splitter_entfernen", "bacta_verband", "synth_fleisch", "operativer_eingriff"}})
I("blast_light", "Leichtes Druckwellentrauma", {DMG_BLAST}, TORSO, {bleeding = 0.00002, pain = 0.4, puls = 0.2, bp = -0.2, spo2 = -3, heal = 300,
    treatment = {"bacta_verband", "enkephalin", "dermasel"}})
I("blast_heavy", "Schweres Druckwellentrauma", {DMG_BLAST}, TORSO, {bleeding = 0.00006, pain = 0.9, puls = 0.2, bp = -0.2, spo2 = -8,
    heal = 720, treatment = {"bacta_verband", "bacta_tank", "operativer_eingriff", "enkephalin", "dermasel"}})

-- Schnitte
I("cut_surface", "Oberflächlicher Schnitt", {DMG_SLASH, DMG_BLAST, DMG_FALL}, nil, {armor = true, disinfect = true, bleeding = 0.00005,
    pain = 0.2, heal = 180, treatment = {"synth_fleisch", "bacta_verband"}})
I("cut_deep", "Tiefe Schnittwunde", {DMG_SLASH, DMG_BLAST}, nil, {armor = true, disinfect = true, bleeding = 0.0005, pain = 0.5, puls = 0.1,
    bp = -0.1, heal = 360, treatment = {"synth_fleisch", "operativer_eingriff", "bacta_verband"}})
I("cut_neck", "Tiefe Schnittwunde am Hals", {DMG_SLASH, DMG_BLAST}, HEAD, {armor = true, disinfect = true, bleeding = 0.0008, pain = 0.65,
    puls = 0.2, bp = -0.2, heal = 420, treatment = {"synth_fleisch", "operativer_eingriff", "bacta_verband", "enkephalin", "dermasel"}})

-- Verbrennungen
I("burn_1", "Verbrennung 1. Grades", {DMG_BURN, DMG_BLAST}, nil, {armor = true, disinfect = true, pain = 0.3, heal = 180,
    treatment = {"bacta_verband", "enkephalin", "dermasel"}})
I("burn_2", "Verbrennung 2. Grades", {DMG_BURN, DMG_BLAST}, nil, {armor = true, disinfect = true, pain = 0.6, puls = 0.1, bp = -0.1, heal = 300,
    treatment = {"bacta_verband", "enkephalin", "dermasel"}})
I("burn_3", "Verbrennung 3. Grades", {DMG_BURN, DMG_BLAST}, nil, {disinfect = true, pain = 0.9, puls = 0.2, bp = -0.2, heal = 600, weight = 6,
    treatment = {"bacta_verband", "bacta_tank", "operativer_eingriff", "enkephalin", "dermasel"}})

-- Stumpfe Gewalt
I("bruise", "Prellung", {DMG_CLUB, DMG_FALL, DMG_BLAST, DMG_VEHICLE}, nil, {armor = true, pain = 0.3, heal = 180, treatment = {"bacta_verband"}})
I("concussion_light", "Leichte Gehirnerschütterung", {DMG_CLUB, DMG_FALL, DMG_BLAST, DMG_VEHICLE}, HEAD, {armor = true, pain = 0.5, heal = 420,
    treatment = {"bacta_verband"}})
I("concussion_heavy", "Schwere Gehirnerschütterung", {DMG_CLUB, DMG_FALL, DMG_BLAST, DMG_VEHICLE}, HEAD, {armor = true, pain = 0.8, puls = 0.2,
    bp = -0.2, heal = 600, treatment = {"bacta_verband", "bacta_tank"}})
I("rib_simple", "Einfacher Rippenbruch", {DMG_FALL, DMG_BLAST, DMG_CLUB, DMG_VEHICLE}, TORSO, {armor = true, fracture = true, pain = 0.8,
    puls = 0.2, bp = -0.2, spo2 = -2, heal = 600, treatment = {"bacta_verband", "bonemer"}})
I("rib_complex", "Komplizierter Rippenbruch", {DMG_FALL, DMG_BLAST, DMG_CLUB, DMG_VEHICLE}, TORSO, {armor = true, fracture = true, pain = 0.75,
    spo2 = -5, heal = 600, treatment = {"bacta_verband", "operativer_eingriff", "bonemer"}})

-- Elektrisch
I("shock_light", "Leichte elektrische Verbrennung", {DMG_SHOCK}, nil, {pain = 0.6, puls = 0.2, bp = -0.2, heal = 180,
    treatment = {"bacta_verband", "enkephalin", "dermasel"}})
I("shock_heavy", "Schwere elektrische Verbrennung", {DMG_SHOCK}, TORSO_HEAD, {pain = 0.85, puls = 0.2, bp = -0.2, heal = 300,
    treatment = {"bacta_verband", "bacta_tank", "enkephalin", "dermasel"}})

-- Energiewaffen (Lichtschwerter u. a.): Streifschuss und tiefer Schnitt
-- haeufig, Amputationen selten
I("saber_graze", "Lichtschwert-Streifverletzung", ENERGY, nil, {disinfect = true, pain = 0.5, puls = 0.1, bp = -0.1, heal = 480,
    treatment = {"bacta_verband", "enkephalin", "dermasel"}})
I("saber_deep", "Tiefer Lichtschwert-Schnitt", ENERGY, TORSO, {disinfect = true, bleeding = 0.0002, pain = 0.9, puls = 0.2, bp = -0.2, heal = 480,
    treatment = {"bacta_verband", "operativer_eingriff", "enkephalin", "dermasel"}})
I("amputation_hand", "Amputation der Hand", {DMG_ENERGYBEAM, DMG_DISSOLVE, DMG_SLASH, DMG_BLAST}, ARMS, {disinfect = true, weight = 1,
    bleeding = 0.01, pain = 0.95, puls = 0.2, bp = -0.2, heal = 900,
    treatment = {"synth_fleisch", "bacta_verband", "operativer_eingriff", "prothese_anbauen", "enkephalin", "dermasel"}})
I("amputation_forearm", "Amputation des Unterarms", {DMG_ENERGYBEAM, DMG_DISSOLVE, DMG_SLASH, DMG_BLAST}, ARMS, {disinfect = true, weight = 1,
    bleeding = 0.05, pain = 1.0, puls = 0.2, bp = -0.2, heal = 1200,
    treatment = {"synth_fleisch", "bacta_verband", "operativer_eingriff", "prothese_anbauen", "enkephalin", "dermasel"}})
I("amputation_foot", "Amputation des Fußes", {DMG_ENERGYBEAM, DMG_DISSOLVE, DMG_SLASH, DMG_BLAST}, LEGS, {disinfect = true, weight = 1,
    bleeding = 0.01, pain = 0.95, puls = 0.2, bp = -0.2, heal = 900,
    treatment = {"synth_fleisch", "bacta_verband", "operativer_eingriff", "prothese_anbauen", "enkephalin", "dermasel"}})
I("amputation_lowerleg", "Amputation des Unterschenkels", {DMG_ENERGYBEAM, DMG_DISSOLVE, DMG_SLASH, DMG_BLAST}, LEGS, {disinfect = true,
    weight = 1, bleeding = 0.05, pain = 1.0, puls = 0.2, bp = -0.2, heal = 1200,
    treatment = {"synth_fleisch", "bacta_verband", "operativer_eingriff", "prothese_anbauen"}})

-- Stuerze und Fahrzeuge
I("fracture_simple", "Einfacher Knochenbruch", {DMG_FALL, DMG_VEHICLE}, LIMBS, {fracture = true, pain = 0.8, heal = 600,
    treatment = {"bacta_verband", "schienung", "bonemer"}})
I("fracture_complex", "Komplizierter Knochenbruch", {DMG_FALL, DMG_VEHICLE}, LIMBS, {fracture = true, pain = 0.8, puls = 0.2, bp = -0.2,
    heal = 600, treatment = {"bacta_verband", "schienung", "operativer_eingriff", "bonemer"}})
I("fracture_open", "Offener Knochenbruch", {DMG_FALL, DMG_VEHICLE}, LIMBS, {fracture = true, disinfect = true, bleeding = 0.001, pain = 0.9,
    puls = 0.2, bp = -0.2, heal = 600, weight = 6, treatment = {"bacta_verband", "schienung", "synth_fleisch", "operativer_eingriff", "bonemer"}})
I("spine", "Wirbelsäulenverletzung", {DMG_FALL, DMG_VEHICLE}, TORSO, {pain = 0.9, puls = 0.2, bp = -0.2, heal = 600, weight = 4,
    treatment = {"bacta_verband", "operativer_eingriff"}})

-- Gift, Saeure, Nervengas, Strahlung
I("poison_light", "Leichte Vergiftung", {DMG_POISON}, TORSO, {pain = 0.4, puls = 0.2, bp = -0.2, heal = 240, treatment = {"gasbinder"}})
I("poison_heavy", "Schwere Vergiftung", {DMG_POISON}, TORSO, {pain = 0.7, puls = 0.4, bp = -0.4, spo2 = -5, heal = 600, weight = 5,
    treatment = {"gasbinder", "bacta_tank"}})
I("acid_light", "Leichte Säureverätzung", {DMG_ACID}, nil, {armor = true, disinfect = true, pain = 0.8, puls = 0.1, bp = -0.1, heal = 360,
    treatment = {"bacta_verband", "enkephalin", "dermasel"}})
I("acid_heavy", "Schwere Säureverätzung", {DMG_ACID}, nil, {armor = true, disinfect = true, pain = 0.9, puls = 0.5, bp = -0.45, heal = 480,
    weight = 5, treatment = {"bacta_verband", "bacta_tank", "operativer_eingriff", "enkephalin", "dermasel"}})
I("nervegas_light", "Leichte Nervengas-Vergiftung", {DMG_NERVEGAS}, nil, {pain = 0.6, puls = 0.4, bp = -0.3, breathing = 4, heal = 540,
    treatment = {"gasbinder"}})
I("nervegas_heavy", "Schwere Nervengas-Vergiftung", {DMG_NERVEGAS}, nil, {pain = 0.7, puls = 0.6, bp = -0.4, breathing = 9, heal = 600,
    weight = 5, treatment = {"gasbinder", "bacta_tank"}})
I("radiation_light", "Leichte Strahlenvergiftung", {DMG_RADIATION}, nil, {pain = 0.5, puls = 0.3, bp = -0.35, heal = 420,
    treatment = {"radioprotektivum"}})
I("radiation_heavy", "Schwere Strahlenvergiftung", {DMG_RADIATION}, nil, {pain = 0.8, puls = 0.7, bp = -0.65, heal = 720, weight = 5,
    treatment = {"radioprotektivum", "bacta_tank"}})
I("radiation_burn", "Strahlenverbrennung", {DMG_RADIATION}, nil, {disinfect = true, pain = 0.6, puls = 0.3, bp = -0.2, heal = 360,
    treatment = {"bacta_verband", "enkephalin", "dermasel"}})

DMS.Injuries = list
DMS.InjuriesById = {}
for _, inj in ipairs(list) do DMS.InjuriesById[inj.id] = inj end

-- Betaeubung (ArcCW-Betaeubungsmunition): keine Verletzung, nur Betaeubung
DMS.StunLevels = {[1] = 0.05, [2] = 0.1, [3] = 0.5}

-- Passt die Verletzung zu Schadensart und Trefferzone?
function DMS.InjuryMatches(inj, hitgroup, dmgTyp)
    if inj.disabled then return false end
    if inj.zones and not inj.zones[hitgroup] then return false end
    return any(dmgTyp, unpack(inj.dmg))
end
