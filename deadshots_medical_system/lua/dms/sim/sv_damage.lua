--[[
    DMS - Schaden wird zu Verletzungen (Server).

    Jeder Treffer auf einen Spieler (oder den Koerper eines Bewusstlosen,
    dann nur von Spielern/NPCs) erzeugt Verletzungen passend zu Schadensart
    und Trefferzone: eine je angefangene "damage_per_injury" Schadenspunkte.
    Ruestung ("armor_value") verhindert Verletzungen, die nicht durchschlagen.
    "death_mode": "injuries" = keine Lebenspunkte, nur die Vitalwerte
    entscheiden; "hp" = nur Lebenspunkte; "both" = was zuerst eintritt.
    Bei 0 Lebenspunkten wird der Spieler bewusstlos statt zu sterben.

    ArcCW-Betaeubungsmunition (ammo_low/mid/high_btm) betaeubt statt zu
    verletzen.
]]

DMS = DMS or {}

local L = DMS.L

-- Chance (%), dass eine Verletzung trotz Ruestung entsteht, je Ruestungswert
local ARMOR_CURVE = {{x = 100, y = 3}, {x = 75, y = 17}, {x = 50, y = 37}, {x = 25, y = 69}, {x = 0, y = 99}}

local STUN_ATTACHMENTS = {ammo_low_btm = 1, ammo_mid_btm = 2, ammo_high_btm = 3}

local function pickInjury(hitgroup, dmgType)
    local pool, total = {}, 0
    for _, inj in ipairs(DMS.Injuries) do
        if DMS.InjuryMatches(inj, hitgroup, dmgType) and (inj.weight or 0) > 0 then
            pool[#pool + 1] = inj
            total = total + inj.weight
        end
    end
    if total <= 0 then return nil end
    local r = math.random() * total
    for _, inj in ipairs(pool) do
        r = r - inj.weight
        if r <= 0 then return inj end
    end
    return pool[#pool]
end

function DMS.AddInjury(ply, def, hitgroup)
    local tbl = DMS.GetPatient(ply)
    table.insert(tbl.injuries, DMS.MakeInjury(def, hitgroup))
    DMS.Log(tbl, string.format(L("Verletzung: %s (%s)"), L(def.name), L(DMS.BodyParts[hitgroup].name)))
end

local function stunWeapon(attacker)
    if not DMS.Get("stun_attachments") or not IsValid(attacker) or not attacker:IsPlayer() then return nil end
    local wep = attacker:GetActiveWeapon()
    if not IsValid(wep) or not wep.ArcCW or not istable(wep.Attachments) then return nil end
    for _, slot in pairs(wep.Attachments) do
        local level = istable(slot) and STUN_ATTACHMENTS[slot.Installed]
        if level then return level end
    end
end

-- Lebenspunkte: bei toedlichem Schaden bewusstlos statt tot
local function applyHP(ply, target, tbl, dmg)
    if DMS.Get("death_mode") == "injuries" then
        dmg:SetDamage(0)
        return
    end
    if target ~= ply or not ply:Alive() or dmg:GetDamage() < ply:Health() then return end
    dmg:SetDamage(0)
    ply:SetHealth(1)
    tbl.hp_down = true
    timer.Simple(0, function() if IsValid(ply) and ply:Alive() then DMS.KnockOut(ply, true) end end)
end

hook.Add("EntityTakeDamage", "DMS.Damage", function(target, dmg)
    local attacker = dmg:GetAttacker()
    local ply = target

    if target:GetClass() == "prop_ragdoll" then
        ply = target:GetNW2Entity("DMS.RagdollOwner")
        if not IsValid(ply) then return end
        -- Physik (Kisten, Stuerze des Koerpers) verletzt den Koerper nicht
        if not IsValid(attacker) or not (attacker:IsPlayer() or attacker:IsNPC() or attacker:IsNextBot()) then return end
    end

    if not IsValid(ply) or not ply:IsPlayer() or ply:HasGodMode() then return end
    local tbl = DMS.GetPatient(ply)

    local hitgroup = ply:Alive() and ply:LastHitGroup() or 0
    if hitgroup < 1 or hitgroup > 7 then hitgroup = math.random(1, 7) end

    local stun = stunWeapon(attacker)
    if stun then
        tbl.stunning_level = math.Clamp(tbl.stunning_level + DMS.StunLevels[stun], 0, 1)
        dmg:SetDamage(0)
        return
    end

    -- Ertrinken: Sauerstoff statt Verletzung
    if bit.band(dmg:GetDamageType(), DMG_DROWN) ~= 0 then
        tbl.spo2 = math.max(0, tbl.spo2 - 8)
        applyHP(ply, target, tbl, dmg)
        return
    end

    local count = math.floor(dmg:GetDamage() / math.max(tonumber(DMS.Get("damage_per_injury")) or 20, 1)) + 1
    local armor = tonumber(DMS.Get("armor_value")) or 0
    for _ = 1, math.min(count, 10) do
        local def = pickInjury(hitgroup, dmg:GetDamageType())
        if def then
            local blocked = def.armor and armor > 0 and math.random(0, 100) >= DMS.Interpolate(armor, ARMOR_CURVE)
            if not blocked then DMS.AddInjury(ply, def, hitgroup) end
        end
    end

    applyHP(ply, target, tbl, dmg)
end)
