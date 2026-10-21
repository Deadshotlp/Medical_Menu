--[[
    DMS - Weitere Massnahmen (Lagerung, Atemwege, Ueberwachung, Tourniquet,
    Zugang, Wiederbelebung).
]]

DMS = DMS or {}

local function down(patient) return IsValid(patient) and not patient:Alive() end

DMS.Other = {
    {
        id = "recovery_position", name = "In die stabile Seitenlage bringen", time = 10, medic = false,
        condition = function(actor, tbl, part, patient)
            return part == 2 and not tbl.recovery_position and down(patient)
        end,
        effect = function(actor, tbl) tbl.recovery_position = true end,
    },
    {
        id = "clear_airway", name = "Atemwege freimachen", time = 5, medic = false,
        condition = function(actor, tbl, part)
            return part == 1 and not tbl.respiratory_system.airway_clear
        end,
        effect = function(actor, tbl) tbl.respiratory_system.airway_clear = true end,
    },
    {
        id = "monitor_on", name = "Vitalüberwachung anschließen", time = 10, medic = true,
        condition = function(actor, tbl) return not tbl.vital_monitoring end,
        effect = function(actor, tbl) tbl.vital_monitoring = true end,
    },
    {
        id = "monitor_off", name = "Vitalüberwachung entfernen", time = 5, medic = true,
        condition = function(actor, tbl) return tbl.vital_monitoring == true end,
        effect = function(actor, tbl) tbl.vital_monitoring = false end,
    },
    {
        id = "tourniquet_on", name = "Tourniquet anlegen", time = 5, medic = false,
        condition = function(actor, tbl, part)
            local bp = tbl.body_part[part]
            return bp ~= nil and DMS.BodyParts[part].limb and not bp.tourniquet
        end,
        effect = function(actor, tbl, part) tbl.body_part[part].tourniquet = true tbl.body_part[part].tourniquet_since = os.time() end,
    },
    {
        id = "tourniquet_off", name = "Tourniquet entfernen", time = 5, medic = false,
        condition = function(actor, tbl, part)
            local bp = tbl.body_part[part]
            return bp ~= nil and bp.tourniquet == true
        end,
        effect = function(actor, tbl, part) tbl.body_part[part].tourniquet = false tbl.body_part[part].tourniquet_since = nil end,
    },
    {
        id = "iv_on", name = "Zugang legen", time = 15, medic = true,
        condition = function(actor, tbl, part)
            local bp = tbl.body_part[part]
            return bp ~= nil and part ~= 1 and not bp.has_iv
        end,
        effect = function(actor, tbl, part) tbl.body_part[part].has_iv = true end,
    },
    {
        id = "iv_off", name = "Zugang entfernen", time = 10, medic = true,
        condition = function(actor, tbl, part)
            local bp = tbl.body_part[part]
            return bp ~= nil and bp.has_iv == true
        end,
        effect = function(actor, tbl, part) tbl.body_part[part].has_iv = false end,
    },
    {
        id = "cpr", name = "Herz-Lungen-Wiederbelebung", time = 30, medic = false,
        condition = function(actor, tbl, part, patient) return part == 2 and down(patient) end,
        effect = function(actor, tbl)
            tbl.recovery_position = false
            tbl.revive_boost = os.time() + 30
            tbl.respiratory_system.airway_clear = true
            if (tbl.puls or 0) < 30 then tbl.puls = 30 end
            tbl.spo2 = math.min(100, (tbl.spo2 or 0) + 10)
        end,
    },
}
