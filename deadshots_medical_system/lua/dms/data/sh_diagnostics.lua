--[[
    DMS - Diagnosen. Ergebnisse landen in der Schnellinfo des Patienten
    (sichtbar fuer alle, die ihn gerade behandeln).
]]

DMS = DMS or {}

local L = DMS.L

local function note(tbl, actor, text)
    tbl.quick_overview_log = tbl.quick_overview_log or {}
    table.insert(tbl.quick_overview_log, {time = os.time(), str = actor:Nick() .. ": " .. text})
    while #tbl.quick_overview_log > 40 do table.remove(tbl.quick_overview_log, 1) end
end
DMS.Note = note

DMS.Diagnostics = {
    {
        id = "check_pulse", name = "Puls fühlen", time = 5, medic = false,
        condition = function(actor, tbl, part)
            local bp = tbl.body_part[part]
            return part > 0 and not (bp and bp.tourniquet)
        end,
        effect = function(actor, tbl)
            local p = math.Round(tbl.puls or 0)
            note(tbl, actor, p <= 0 and L("Kein Puls tastbar") or string.format(L("Puls %d bpm"), p))
        end,
    },
    {
        id = "check_breathing", name = "Atmung prüfen", time = 5, medic = false,
        condition = function(actor, tbl, part) return part == 1 end,
        effect = function(actor, tbl)
            local r = tbl.respiratory_system
            local text
            if not r.airway_clear then
                text = L("Atemwege verlegt - keine Atmung")
            elseif (r.breathing_rate or 0) < 8 then
                text = string.format(L("Flache Atmung (%d/min)"), math.Round(r.breathing_rate or 0))
            else
                text = string.format(L("Atmung normal (%d/min)"), math.Round(r.breathing_rate or 0))
            end
            note(tbl, actor, text)
        end,
    },
    {
        id = "check_bp", name = "Blutdruck messen", time = 10, medic = true,
        condition = function(actor, tbl, part) return part > 1 end,
        effect = function(actor, tbl)
            note(tbl, actor, string.format(L("Blutdruck %d/%d mmHg"), tbl.bp[1], tbl.bp[2]))
        end,
    },
    {
        id = "check_spo2", name = "Sauerstoffsättigung messen", time = 5, medic = true,
        condition = function(actor, tbl, part) return part > 1 end,
        effect = function(actor, tbl)
            note(tbl, actor, string.format(L("Sauerstoffsättigung %d %%"), math.Round(tbl.spo2 or 0)))
        end,
    },
    {
        id = "check_fracture", name = "Auf Brüche abtasten", time = 8, medic = false,
        condition = function(actor, tbl, part) return part > 0 end,
        effect = function(actor, tbl, part)
            local name = L(DMS.BodyParts[part].name)
            local broken = false
            for _, inj in ipairs(tbl.injuries or {}) do
                if DMS.PartMatches(part, inj.wo) and inj.fracture then broken = true end
            end
            note(tbl, actor, name .. ": " .. (broken and L("Bruch ertastet") or L("kein Bruch ertastet")))
        end,
    },
    {
        id = "examine_wounds", name = "Wunden untersuchen", time = 10, medic = true,
        condition = function(actor, tbl, part) return part > 0 end,
        effect = function(actor, tbl, part)
            local name = L(DMS.BodyParts[part].name)
            local infected, open = 0, 0
            for _, inf in ipairs(tbl.infections or {}) do
                if DMS.PartMatches(part, inf.wo) then infected = infected + 1 end
            end
            for _, inj in ipairs(tbl.injuries or {}) do
                if DMS.PartMatches(part, inj.wo) and inj.disinfect and not inj.disinfected then open = open + 1 end
            end
            local parts = {}
            parts[#parts + 1] = infected > 0 and string.format(L("%d entzündete Wunde(n)"), infected) or L("keine Entzündung")
            if open > 0 then parts[#parts + 1] = string.format(L("%d Wunde(n) nicht desinfiziert"), open) end
            note(tbl, actor, name .. ": " .. table.concat(parts, ", "))
        end,
    },
}
