--[[
    DMS - Behandlungen.

    Eine Behandlung wirkt auf die erste passende Verletzung am gewaehlten
    Koerperteil, die sie in ihrer Liste "treatment" hat: der Eintrag faellt
    weg, die Heilzeit sinkt anteilig, dazu die Wirkung der Behandlung
    (Blutung stillen, Schmerz senken, desinfizieren, Bruch richten ...).
    Nach der letzten Behandlung ist die Verletzung versorgt.

    Aktionen (auch Medikamente, Massnahmen, Diagnosen) haben:
      id, name, time (s), medic (nur Medics), condition, effect
]]

DMS = DMS or {}

local function scale(field, f) return function(inj) inj[field] = (inj[field] or 0) * f end end

-- Wirkung je Behandlung auf die Verletzung
local EFFECTS = {
    bacta_verband = function(inj) inj.bleeding = 0 inj.disinfected = true end,
    synth_fleisch = function(inj) inj.bleeding = 0 end,
    operativer_eingriff = function(inj) inj.bleeding = 0 inj.pain = inj.pain * 0.5 end,
    bacta_tank = function(inj) inj.heal = inj.heal / 3 inj.pain = inj.pain * 0.5 end,
    oberflaechige_splitter_entfernen = scale("pain", 0.7),
    schienung = function(inj) inj.pain = inj.pain * 0.5 inj.splinted = true end,
    gasbinder = function(inj) inj.puls, inj.bp, inj.breathing, inj.spo2 = 0, 0, 0, 0 end,
    enkephalin = scale("pain", 0.5),
    dermasel = function(inj) inj.disinfected = true inj.pain = inj.pain * 0.8 end,
    bonemer = function(inj) inj.fracture = false end,
    prothese_anbauen = function(inj) inj.bleeding = 0 inj.pain = inj.pain * 0.3 end,
    radioprotektivum = function(inj) inj.puls, inj.bp = 0, 0 end,
}

-- Verletzungen am Koerperteil, die diese Behandlung brauchen
function DMS.InjuriesNeeding(tbl, part, key)
    local out = {}
    for _, inj in ipairs(tbl.injuries or {}) do
        if DMS.PartMatches(part, inj.wo) and table.HasValue(inj.treatment or {}, key) then out[#out + 1] = inj end
    end
    return out
end

local function treatable(key)
    return function(actor, tbl, part)
        return part > 0 and #DMS.InjuriesNeeding(tbl, part, key) > 0
    end
end

function DMS.ApplyTreatment(actor, tbl, part, key)
    local inj = DMS.InjuriesNeeding(tbl, part, key)[1]
    if not inj then return end

    local count = #inj.treatment
    inj.heal = inj.heal - inj.heal / math.max(count, 1)
    table.RemoveByValue(inj.treatment, key)
    if EFFECTS[key] then EFFECTS[key](inj) end
    if #inj.treatment == 0 then inj.heal = 0 end -- versorgt
end

local function treatment(id, name, time, medic)
    return {
        id = id, name = name, time = time, medic = medic,
        condition = treatable(id),
        effect = function(actor, tbl, part) DMS.ApplyTreatment(actor, tbl, part, id) end,
    }
end

DMS.Treatments = {
    treatment("bacta_verband", "Bacta-Verband anlegen", 5, false),
    treatment("synth_fleisch", "Synthfleisch einbringen", 10, true),
    treatment("oberflaechige_splitter_entfernen", "Oberflächliche Splitter entfernen", 15, true),
    treatment("operativer_eingriff", "Operativer Eingriff", 15, true),
    treatment("bacta_tank", "Bacta-Tank-Behandlung", 15, true),
    treatment("schienung", "Schiene anlegen", 10, false),
    treatment("bonemer", "Bonemer verabreichen", 15, true),
    treatment("gasbinder", "Gasbinder verabreichen", 5, true),
    treatment("radioprotektivum", "Radioprotektivum verabreichen", 5, true),
    treatment("enkephalin", "Enkephalin verabreichen", 5, true),
    treatment("dermasel", "Dermasel auftragen", 5, false),
    treatment("prothese_anbauen", "Prothese anbauen", 30, true),
    -- Desinfektion: fuer jede noch nicht desinfizierte offene Wunde
    {
        id = "desinfektion", name = "Wunde desinfizieren", time = 5, medic = false,
        condition = function(actor, tbl, part)
            if part <= 0 then return false end
            for _, inj in ipairs(tbl.injuries or {}) do
                if DMS.PartMatches(part, inj.wo) and inj.disinfect and not inj.disinfected then return true end
            end
            return false
        end,
        effect = function(actor, tbl, part)
            for _, inj in ipairs(tbl.injuries or {}) do
                if DMS.PartMatches(part, inj.wo) and inj.disinfect and not inj.disinfected then
                    inj.disinfected = true
                    return
                end
            end
        end,
    },
}
