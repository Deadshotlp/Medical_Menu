--[[
    DMS - Vitalwerte (Server). Laeuft alle "update_interval" Sekunden fuer
    jeden Spieler:

      1. Verletzungen: Heilzeit, Schmerz, Blutung je Koerperteil, Brueche,
         Infektionsrisiko offener Wunden
      2. Infektionen: wachsen ohne Antibiotikum, heilen mit
      3. Medikamente: Wirkung waehrend der Wirkdauer
      4. Atmung, Blut (Verlust, Infusion, Neubildung)
      5. Puls, Blutdruck, Sauerstoffsaettigung (laufen sanft auf Zielwerte zu)
      6. Bewusstlosigkeit bzw. Aufwachen nach den Grenzwerten
]]

DMS = DMS or {}

local L = DMS.L
local NORMAL_BLOOD = 5.5
local CPR_PULSE = 30 -- bpm waehrend einer laufenden HLW
local CPR_SPO2, CPR_SPO2_RATE = 80, 3 -- Beatmung: bis 80 % SpO2, 3 Punkte je Sekunde

local function num(v, d) return isnumber(v) and v or d end

--------------------------------------------------------------------------------
-- 1. Verletzungen
--------------------------------------------------------------------------------

local function stepInjuries(tbl, dt)
    local mod = {puls = 0, spo2 = 0, bp = 0, breathing = 0, pain = 0}
    local bleed, fractured = {}, {}
    local chance = num(DMS.Get("infection_chance"), 0.2) / 100 * dt
    local infections = DMS.Get("mod_infections") ~= false

    for i = #tbl.injuries, 1, -1 do
        local inj = tbl.injuries[i]
        inj.heal = num(inj.heal, 0) - dt
        if inj.heal <= 0 then
            table.remove(tbl.injuries, i)
            DMS.Log(tbl, string.format(L("%s verheilt"), L(inj.name)))
            continue
        end

        mod.puls = mod.puls + num(inj.puls, 0)
        mod.spo2 = mod.spo2 + num(inj.spo2, 0)
        mod.bp = mod.bp + num(inj.bp, 0)
        mod.breathing = mod.breathing + num(inj.breathing, 0)
        mod.pain = mod.pain + num(inj.pain, 0)
        if num(inj.bleeding, 0) > 0 then bleed[inj.wo] = (bleed[inj.wo] or 0) + inj.bleeding end
        if inj.fracture then fractured[inj.wo == 3 and 2 or inj.wo] = true end

        -- Offene, nicht desinfizierte Wunde kann sich entzuenden (Modul Infektionen)
        if infections and inj.disinfect and not inj.disinfected and not inj.infected and math.random() < chance then
            inj.infected = true
            table.insert(tbl.infections, {wo = inj.wo, severity = 0.05, source = inj.name})
        end
    end

    for i, part in ipairs(tbl.body_part) do
        part.bleeding = bleed[i] or 0
        part.fractured = fractured[i] or false
    end
    return mod
end

--------------------------------------------------------------------------------
-- 2. Infektionen
--------------------------------------------------------------------------------

local function stepInfections(tbl, dt, antibiotic, mod)
    -- Modul aus: bestehende Infektionen verschwinden
    if DMS.Get("mod_infections") == false then
        tbl.infections = {}
        return
    end
    local growth = num(DMS.Get("infection_growth"), 0.002) * dt
    for i = #tbl.infections, 1, -1 do
        local inf = tbl.infections[i]
        if antibiotic then
            inf.severity = inf.severity - growth * 4
        else
            inf.severity = math.min(1, inf.severity + growth)
        end
        if inf.severity <= 0 then
            table.remove(tbl.infections, i)
            DMS.Log(tbl, L("Infektion abgeklungen"))
            continue
        end
        -- Fieber (Puls hoch), bei schwerer Infektion (Sepsis) faellt der Blutdruck
        local s = inf.severity
        mod.puls = mod.puls + s * 0.4
        mod.bp = mod.bp - s * (s > 0.7 and 0.5 or 0.2)
        mod.pain = mod.pain + s * 1.0
        mod.spo2 = mod.spo2 - s * 5
    end
end

--------------------------------------------------------------------------------
-- 3. Medikamente
--------------------------------------------------------------------------------

local function stepMedication(tbl, mod)
    local now, keep, antibiotic, relief = os.time(), {}, false, 0
    for _, med in ipairs(tbl.medication or {}) do
        if now < num(med.administered, 0) + num(med.duration, 0) then
            mod.puls = mod.puls + num(med.puls, 0)
            mod.spo2 = mod.spo2 + num(med.spo2, 0)
            mod.bp = mod.bp + num(med.bp, 0)
            relief = relief + num(med.relief, 0)
            if med.antibiotic then antibiotic = true end
            keep[#keep + 1] = med
        end
    end
    tbl.medication = keep
    return antibiotic, relief
end

--------------------------------------------------------------------------------
-- 5. Puls, Blutdruck, Sauerstoff
--------------------------------------------------------------------------------

-- protected: HLW laeuft oder Wiederbelebung frisch (revive_boost) - dann
-- stoppt Sauerstoffmangel das Herz nicht sofort wieder; der Sauerstoff muss
-- erst Zeit haben, wieder zu steigen
local function stepPulse(tbl, mod, protected)
    if tbl.puls <= 0 then tbl.puls = 0 return end -- Herzstillstand: nur Wiederbelebung hilft
    local blood_loss = math.max(0, NORMAL_BLOOD - tbl.blood_amount)
    local target = 75 * (1 + mod.puls) + tbl.pain_level * 1.75 + blood_loss * 10.5 + math.random(-6, 6)
    tbl.puls = tbl.puls + (target - tbl.puls) * 0.1
    if tbl.puls > 250 or (tbl.spo2 <= 20 and not protected) then tbl.puls = 0 end -- Kammerflimmern / Sauerstoffmangel
    tbl.puls = math.Round(math.Clamp(tbl.puls, 0, 250))
end

local function stepBP(tbl, mod)
    if tbl.puls <= 0 then tbl.bp = {0, 0} return end
    local blood_loss = math.max(0, NORMAL_BLOOD - tbl.blood_amount)
    local sys = (120 - blood_loss * 10 + tbl.pain_level * 0.25) * (1 + mod.bp) + math.random(-8, 8)
    local dia = (80 - blood_loss * 5 + tbl.pain_level * 0.5) * (1 + mod.bp) + math.random(-6, 6)
    local s = tbl.bp[1] + (sys - tbl.bp[1]) * 0.08
    local d = tbl.bp[2] + (dia - tbl.bp[2]) * 0.08
    s, d = math.Clamp(s, 0, 300), math.Clamp(d, 0, 200)
    if s < d then s = d + 1 end
    tbl.bp = {math.Round(s), math.Round(d)}
end

local function stepSpO2(tbl, mod)
    local resp = tbl.respiratory_system
    local target = 97
    if tbl.puls <= 0 or not resp.airway_clear or not resp.lungs_functional or resp.breathing_rate < 4 then
        tbl.spo2 = math.max(0, tbl.spo2 * 0.95 - 0.5) -- kein Sauerstoff
        tbl.spo2 = math.Round(tbl.spo2)
        return
    end
    if resp.breathing_rate < 10 then target = target - (10 - resp.breathing_rate) * 4 end
    target = target - math.max(0, NORMAL_BLOOD - tbl.blood_amount) * 12.5 + mod.spo2
    target = math.Clamp(target + math.random(-1, 1), 0, 100)
    tbl.spo2 = math.Round(math.Clamp(tbl.spo2 + (target - tbl.spo2) * 0.1, 0, 100))
end

--------------------------------------------------------------------------------
-- Ablauf je Spieler
--------------------------------------------------------------------------------

local function unconsciousCause(tbl)
    if tbl.stunning_level >= 1 then return true end
    if DMS.Get("death_mode") == "hp" then return false end
    if tbl.puls < DMS.Get("unc_puls_min") then return true end
    if tbl.bp[1] < DMS.Get("unc_sys_min") or tbl.bp[1] > DMS.Get("unc_sys_max") then return true end
    if tbl.bp[2] < DMS.Get("unc_dia_min") or tbl.bp[2] > DMS.Get("unc_dia_max") then return true end
    if tbl.spo2 < DMS.Get("unc_spo2_min") then return true end
    if tbl.pain_level >= DMS.Get("unc_pain_max") then return true end
    return false
end

local function canWake(tbl)
    if tbl.stunning_level > 0 then return false end
    -- Durch Lebenspunkte bewusstlos: nur Wiederbelebung (HLW, Wachmacher) weckt
    if tbl.hp_down and (tbl.revive_boost or 0) <= os.time() then return false end
    if DMS.Get("death_mode") == "hp" then return true end
    if tbl.puls <= 0 then return false end
    -- Wachmacher (Quick Wake IV): es reicht, nicht mehr bewusstlos zu sein
    if (tbl.revive_boost or 0) > os.time() then return not unconsciousCause(tbl) end
    return DMS.IsBetween(tbl.puls, DMS.Get("wake_puls_min"), DMS.Get("wake_puls_max"))
        and tbl.bp[1] >= DMS.Get("wake_sys_min") and tbl.bp[2] >= DMS.Get("wake_dia_min")
        and tbl.spo2 >= DMS.Get("wake_spo2_min") and tbl.pain_level < DMS.Get("unc_pain_max")
end

function DMS.UpdatePatient(ply, tbl, dt)
    local cpr = DMS.CPRActive and DMS.CPRActive(ply) or false
    local protected = cpr or (tbl.revive_boost or 0) > os.time()
    local mod = stepInjuries(tbl, dt)
    local antibiotic, relief = stepMedication(tbl, mod)
    stepInfections(tbl, dt, antibiotic, mod)

    tbl.pain_level = DMS.Get("mod_pain") == false and 0 or math.max(0, mod.pain - relief)

    -- Atmung
    local resp = tbl.respiratory_system
    local rate = 15 - mod.breathing
    local airway = DMS.Get("mod_airway") ~= false
    if not airway then
        resp.airway_clear = true
        tbl.breathing_depressed_until = nil
    end
    if (tbl.breathing_depressed_until or 0) > os.time() then rate = rate - 9 end
    if not resp.airway_clear then rate = 0 end
    resp.breathing_rate = math.max(0, rate)

    -- Blut: Verlust je Koerperteil (Tourniquet stoppt Blutung an Armen/Beinen)
    local loss = 0
    local bleeding = DMS.Get("mod_bleeding") ~= false
    for _, part in ipairs(tbl.body_part) do
        if not bleeding then part.bleeding = 0 end
        if part.bleeding > 0 and not part.tourniquet then
            loss = loss + part.bleeding * (tbl.puls / 10 + 1) * dt
        end
    end
    tbl.blood_amount = math.max(0, tbl.blood_amount - loss)
    if (tbl.blood_to_add or 0) > 0 then
        local add = math.min(tbl.blood_to_add, 0.05 * dt)
        tbl.blood_amount = tbl.blood_amount + add
        tbl.blood_to_add = tbl.blood_to_add - add
    end
    if tbl.blood_amount < NORMAL_BLOOD then
        tbl.blood_amount = tbl.blood_amount + num(DMS.Get("blood_regen"), 0) * dt
    end
    tbl.blood_amount = math.min(tbl.blood_amount, NORMAL_BLOOD)

    stepPulse(tbl, mod, protected)
    stepBP(tbl, mod)
    stepSpO2(tbl, mod)

    -- Laufende Herz-Lungen-Wiederbelebung: Puls mindestens CPR_PULSE, auch bei
    -- Herzstillstand (Herzdruckmassage haelt den Kreislauf in Gang); die
    -- Beatmung hebt die Sauerstoffsaettigung, solange die Atemwege frei sind
    if cpr then
        if tbl.puls < CPR_PULSE then tbl.puls = CPR_PULSE end
        if resp.airway_clear and tbl.spo2 < CPR_SPO2 then tbl.spo2 = math.min(CPR_SPO2, tbl.spo2 + CPR_SPO2_RATE * dt) end
    end

    if tbl.stunning_level > 0 then tbl.stunning_level = math.Clamp(tbl.stunning_level - 0.0033 * dt, 0, 1) end

    -- Bewusstlos werden bzw. aufwachen
    if ply:Alive() then
        if unconsciousCause(tbl) then DMS.KnockOut(ply) end
    elseif IsValid(ply:GetNW2Entity("DMS.Ragdoll")) then
        if canWake(tbl) then
            DMS.Revive(ply)
        elseif airway and not protected and not tbl.recovery_position and resp.airway_clear
            and math.random() * 100 < num(DMS.Get("airway_block_chance"), 2) * dt then
            resp.airway_clear = false
        end
    end

    ply:SetNW2Int("DMS.Puls", tbl.puls)
    ply:SetNW2Int("DMS.SPO2", tbl.spo2)
end

local nextRun = 0
hook.Add("Think", "DMS.Vitals", function()
    local now = CurTime()
    if now < nextRun then return end
    local dt = math.Clamp(num(DMS.Get("update_interval"), 1), 0.2, 10)
    nextRun = now + dt

    for _, ply in player.Iterator() do
        if ply:HasGodMode() then continue end
        local tbl = DMS.GetPatient(ply)
        local ok, err = pcall(DMS.UpdatePatient, ply, tbl, dt)
        if not ok then ErrorNoHalt("[DMS] Update " .. ply:Nick() .. ": " .. tostring(err) .. "\n") end
        if DMS.SendToViewers then DMS.SendToViewers(ply) end
    end
end)
