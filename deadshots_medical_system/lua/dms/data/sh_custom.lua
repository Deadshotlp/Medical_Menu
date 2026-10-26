--[[
    DMS - Eigene Inhalte aus dem Konfigurationsmenue: Verletzungen,
    Diagnosen, Medikamente und Behandlungen.

    Gespeichert als "custom" in dms_settings (sv_db.lua), verteilt mit den
    Einstellungen (net "DMS.Config"). Beschreibung der Felder:
    DMS.CustomSchema (dient Server-Pruefung und Formular gleichermassen).
    DMS.RebuildCustom baut daraus Eintraege wie die im Code und haengt sie in
    dieselben Listen (DMS.Injuries, DMS.Diagnostics, DMS.Medication,
    DMS.Treatments); danach greifen Anpassungen (sh_overrides.lua) wie
    gewohnt. IDs der mitgelieferten Inhalte sind nicht verwendbar.
]]

DMS = DMS or {}
DMS.Config = DMS.Config or {}
DMS.Config.Custom = DMS.Config.Custom or {}

local L = DMS.L

--------------------------------------------------------------------------------
-- Auswahllisten
--------------------------------------------------------------------------------

DMS.DamageTypeChoices = {
    {"bullet", "Projektil / Blaster", DMG_BULLET}, {"plasma", "Plasma", DMG_PLASMA}, {"slash", "Schnitt", DMG_SLASH},
    {"club", "Stumpfe Gewalt", DMG_CLUB}, {"blast", "Explosion", DMG_BLAST}, {"burn", "Feuer", DMG_BURN},
    {"shock", "Elektrizität", DMG_SHOCK}, {"energybeam", "Energiestrahl", DMG_ENERGYBEAM}, {"dissolve", "Auflösung", DMG_DISSOLVE},
    {"crush", "Quetschung", DMG_CRUSH}, {"fall", "Sturz", DMG_FALL}, {"vehicle", "Fahrzeug", DMG_VEHICLE},
    {"poison", "Gift", DMG_POISON}, {"acid", "Säure", DMG_ACID}, {"nervegas", "Nervengas", DMG_NERVEGAS},
    {"radiation", "Strahlung", DMG_RADIATION},
}
local DMG_BY_KEY = {}
for _, c in ipairs(DMS.DamageTypeChoices) do DMG_BY_KEY[c[1]] = c[3] end

DMS.ZoneChoices = {
    {"head", "Kopf", {HITGROUP_HEAD}}, {"torso", "Rumpf", {HITGROUP_CHEST, HITGROUP_STOMACH}},
    {"arms", "Arme", {HITGROUP_LEFTARM, HITGROUP_RIGHTARM}}, {"legs", "Beine", {HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG}},
}

-- Wo eine Diagnose geht
DMS.WhereChoices = {
    {"any", "Jeder Körperteil"}, {"head", "Nur Kopf"}, {"torso", "Nur Rumpf"}, {"limbs", "Nur Arme und Beine"},
    {"not_head", "Alles außer Kopf"},
}
local WHERE = {
    any = function(part) return part > 0 end,
    head = function(part) return part == 1 end,
    torso = function(part) return part == 2 or part == 3 end,
    limbs = function(part) return part >= 4 end,
    not_head = function(part) return part > 1 end,
}

-- Was eine Diagnose meldet (Text in der Schnellinfo)
DMS.ReportChoices = {
    {"pulse", "Puls"}, {"bp", "Blutdruck"}, {"spo2", "Sauerstoffsättigung"}, {"breathing", "Atmung"},
    {"blood", "Blutverlust"}, {"pain", "Schmerz"}, {"fracture", "Brüche am Körperteil"},
    {"wounds", "Wunden und Entzündungen am Körperteil"}, {"injuries", "Verletzungen am Körperteil"},
    {"infections", "Infektionen (ganzer Körper)"}, {"medication", "Medikamente im Blut"},
}

local function partName(part) return L(DMS.BodyParts[part].name) end

local REPORTS = {
    pulse = function(tbl)
        local p = math.Round(tbl.puls or 0)
        return p <= 0 and L("Kein Puls tastbar") or string.format(L("Puls %d bpm"), p)
    end,
    bp = function(tbl) return string.format(L("Blutdruck %d/%d mmHg"), tbl.bp[1], tbl.bp[2]) end,
    spo2 = function(tbl) return string.format(L("Sauerstoffsättigung %d %%"), math.Round(tbl.spo2 or 0)) end,
    breathing = function(tbl)
        local r = tbl.respiratory_system
        if not r.airway_clear then return L("Atemwege verlegt - keine Atmung") end
        if (r.breathing_rate or 0) < 8 then return string.format(L("Flache Atmung (%d/min)"), math.Round(r.breathing_rate or 0)) end
        return string.format(L("Atmung normal (%d/min)"), math.Round(r.breathing_rate or 0))
    end,
    blood = function(tbl)
        local b = tbl.blood_amount or 5.5
        if b >= 5.4 then return L("Kein Blutverlust") end
        if b > 4.0 then return L("Geringer Blutverlust") end
        if b > 3.0 then return L("Starker Blutverlust") end
        return L("Tödlicher Blutverlust")
    end,
    pain = function(tbl)
        local p = tbl.pain_level or 0
        if p <= 0.05 then return L("Kein Schmerz") end
        if p < 1.5 then return L("Leichter Schmerz") end
        if p < 3 then return L("Mäßiger Schmerz") end
        return L("Starker Schmerz")
    end,
    fracture = function(tbl, part)
        for _, inj in ipairs(tbl.injuries or {}) do
            if DMS.PartMatches(part, inj.wo) and inj.fracture then return partName(part) .. ": " .. L("Bruch ertastet") end
        end
        return partName(part) .. ": " .. L("kein Bruch ertastet")
    end,
    wounds = function(tbl, part)
        local infected, open = 0, 0
        for _, inf in ipairs(tbl.infections or {}) do
            if DMS.PartMatches(part, inf.wo) then infected = infected + 1 end
        end
        for _, inj in ipairs(tbl.injuries or {}) do
            if DMS.PartMatches(part, inj.wo) and inj.disinfect and not inj.disinfected then open = open + 1 end
        end
        local out = {infected > 0 and string.format(L("%d entzündete Wunde(n)"), infected) or L("keine Entzündung")}
        if open > 0 then out[#out + 1] = string.format(L("%d Wunde(n) nicht desinfiziert"), open) end
        return partName(part) .. ": " .. table.concat(out, ", ")
    end,
    injuries = function(tbl, part)
        local names = {}
        for _, inj in ipairs(tbl.injuries or {}) do
            if DMS.PartMatches(part, inj.wo) then names[#names + 1] = L(inj.name) end
        end
        return partName(part) .. ": " .. (#names > 0 and table.concat(names, ", ") or L("Keine Verletzungen"))
    end,
    infections = function(tbl)
        local n = #(tbl.infections or {})
        return n > 0 and string.format(L("%d Infektion(en)"), n) or L("keine Entzündung")
    end,
    medication = function(tbl)
        local names = {}
        for _, m in ipairs(tbl.medication or {}) do names[#names + 1] = L(m.name) end
        return L("Medikamente: ") .. (#names > 0 and table.concat(names, ", ") or "-")
    end,
}

--------------------------------------------------------------------------------
-- Felder je Art: {schluessel, art, beschriftung, standard, auswahl}
--   art: string, number, bool, choice, multi (mehrere aus auswahl),
--        list (IDs, z. B. Behandlungen), map (behandlung = ziel)
--------------------------------------------------------------------------------

DMS.CustomKinds = {
    {key = "injuries", name = "Verletzungen"},
    {key = "diagnostics", name = "Diagnosen"},
    {key = "medication", name = "Medikamente"},
    {key = "treatments", name = "Behandlungen"},
}

DMS.CustomSchema = {
    injuries = {
        {"name", "string", "Name", "Neue Verletzung"},
        {"dmg", "multi", "Schadensarten", {"bullet"}, DMS.DamageTypeChoices},
        {"zones", "multi", "Trefferzonen (keine = alle)", {}, DMS.ZoneChoices},
        {"weight", "number", "Häufigkeit (Gewicht)", 10},
        {"armor", "bool", "Rüstung schützt", true},
        {"heal", "number", "Heilzeit (s)", 300},
        {"pain", "number", "Schmerz", 0.3},
        {"bleeding", "number", "Blutung je Berechnung (Liter)", 0},
        {"puls", "number", "Puls-Faktor", 0},
        {"bp", "number", "Blutdruck-Faktor", 0},
        {"spo2", "number", "Sauerstoff (Punkte)", 0},
        {"breathing", "number", "Atemzüge weniger je Minute", 0},
        {"disinfect", "bool", "Offene Wunde (kann sich entzünden)", false},
        {"fracture", "bool", "Knochenbruch", false},
        {"treatment", "list", "Behandlungen (IDs)", {}},
        {"transform", "map", "Umwandlung (Behandlung = Ziel)", {}},
    },
    diagnostics = {
        {"name", "string", "Name", "Neue Diagnose"},
        {"time", "number", "Dauer der Anwendung (s)", 5},
        {"medic", "bool", "Nur Medics", false},
        {"where", "choice", "Wo", "any", DMS.WhereChoices},
        {"report", "choice", "Ergebnis", "pulse", DMS.ReportChoices},
    },
    medication = {
        {"name", "string", "Name", "Neues Medikament"},
        {"kind", "choice", "Gabe", "injector", {{"injector", "Autoinjektor (nicht am Kopf)"}, {"iv", "Infusion (braucht Zugang)"}}},
        {"time", "number", "Dauer der Anwendung (s)", 5},
        {"medic", "bool", "Nur Medics", true},
        {"duration", "number", "Wirkdauer (s)", 180},
        {"puls", "number", "Puls-Faktor", 0},
        {"bp", "number", "Blutdruck-Faktor", 0},
        {"spo2", "number", "Sauerstoff (Punkte)", 0},
        {"relief", "number", "Schmerzlinderung (Stufen)", 0},
        {"antibiotic", "bool", "Antibiotikum", false},
        {"fluids", "number", "Flüssigkeit (Liter)", 0},
        {"wake", "bool", "Hebt Betäubung auf", false},
        {"revive", "bool", "Weckt Bewusstlose", false},
        {"sedate", "bool", "Künstliches Koma", false},
        {"depress", "number", "Gefahr einer Atemdepression (0 - 1)", 0},
    },
    treatments = {
        {"name", "string", "Name", "Neue Behandlung"},
        {"time", "number", "Dauer der Anwendung (s)", 10},
        {"medic", "bool", "Nur Medics", true},
        {"stop_bleeding", "bool", "Stillt die Blutung", false},
        {"disinfect", "bool", "Desinfiziert die Wunde", false},
        {"pain", "number", "Schmerz-Faktor (1 = unverändert)", 1},
        {"heal_factor", "number", "Heilzeit-Faktor (1 = unverändert)", 1},
        {"splint", "bool", "Schient", false},
        {"fix_fracture", "bool", "Richtet den Bruch", false},
        {"neutralize", "bool", "Hebt Puls-, Blutdruck-, Atem- und Sauerstoffwirkung auf", false},
    },
}

local BUILTIN = {}
local function builtinIds()
    if next(BUILTIN) then return BUILTIN end
    for _, inj in ipairs(DMS.Injuries) do if not inj.custom then BUILTIN[inj.id] = true end end
    for id, a in pairs(DMS.ActionsById) do if not a.custom then BUILTIN[id] = true end end
    return BUILTIN
end
function DMS.IsBuiltinId(id) return builtinIds()[id] == true end

--------------------------------------------------------------------------------
-- Aus Felddaten Eintraege bauen
--------------------------------------------------------------------------------

local function field(d, key, schema)
    if d[key] ~= nil then return d[key] end
    for _, f in ipairs(schema) do if f[1] == key then return f[4] end end
end

local function buildInjury(id, d)
    local S = DMS.CustomSchema.injuries
    local function v(k) return field(d, k, S) end
    local dmg = {}
    for _, k in ipairs(v("dmg") or {}) do if DMG_BY_KEY[k] then dmg[#dmg + 1] = DMG_BY_KEY[k] end end
    if #dmg == 0 then dmg = {DMG_BULLET} end
    local zones
    for _, k in ipairs(v("zones") or {}) do
        for _, z in ipairs(DMS.ZoneChoices) do
            if z[1] == k then
                zones = zones or {}
                for _, hg in ipairs(z[3]) do zones[hg] = true end
            end
        end
    end
    return {
        id = id, name = v("name"), dmg = dmg, zones = zones, custom = true,
        weight = v("weight"), armor = v("armor"), heal = v("heal"), pain = v("pain"), bleeding = v("bleeding"),
        puls = v("puls"), bp = v("bp"), spo2 = v("spo2"), breathing = v("breathing"),
        disinfect = v("disinfect") or nil, fracture = v("fracture") or nil,
        treatment = table.Copy(v("treatment") or {}), transform = table.Copy(v("transform") or {}),
    }
end

local function buildTreatment(id, d)
    local S = DMS.CustomSchema.treatments
    local function v(k) return field(d, k, S) end
    DMS.TreatmentEffects[id] = function(inj)
        if v("stop_bleeding") then inj.bleeding = 0 end
        if v("disinfect") then inj.disinfected = true end
        inj.pain = (inj.pain or 0) * (tonumber(v("pain")) or 1)
        inj.heal = (inj.heal or 0) * (tonumber(v("heal_factor")) or 1)
        if v("splint") then inj.splinted = true end
        if v("fix_fracture") then inj.fracture = false end
        if v("neutralize") then inj.puls, inj.bp, inj.breathing, inj.spo2 = 0, 0, 0, 0 end
    end
    return {
        id = id, name = v("name"), time = v("time"), medic = v("medic"), custom = true,
        condition = function(actor, tbl, part) return part > 0 and #DMS.InjuriesNeeding(tbl, part, id) > 0 end,
        effect = function(actor, tbl, part) DMS.ApplyTreatment(actor, tbl, part, id) end,
    }
end

local function buildMedication(id, d)
    local S = DMS.CustomSchema.medication
    local t = {}
    for _, f in ipairs(S) do t[f[1]] = field(d, f[1], S) end
    if (tonumber(t.depress) or 0) <= 0 then t.depress = nil end
    if (tonumber(t.fluids) or 0) <= 0 then t.fluids = nil end
    local m = DMS.MakeMedication(id, t.name, t.kind == "iv" and "iv" or "injector", t)
    m.medic = t.medic
    m.custom = true
    return m
end

local function buildDiagnostic(id, d)
    local S = DMS.CustomSchema.diagnostics
    local function v(k) return field(d, k, S) end
    local where = WHERE[v("where")] or WHERE.any
    local report = REPORTS[v("report")] or REPORTS.pulse
    return {
        id = id, name = v("name"), time = v("time"), medic = v("medic"), custom = true,
        condition = function(actor, tbl, part) return where(part) end,
        effect = function(actor, tbl, part) DMS.Note(tbl, actor, report(tbl, part)) end,
    }
end

local BUILDERS = {injuries = buildInjury, treatments = buildTreatment, medication = buildMedication, diagnostics = buildDiagnostic}
local LISTS = {
    injuries = function() return DMS.Injuries end, treatments = function() return DMS.Treatments end,
    medication = function() return DMS.Medication end, diagnostics = function() return DMS.Diagnostics end,
}

-- Einen eigenen Eintrag bauen und in Listen und Verzeichnisse haengen
local function AddCustom(kind, id, d)
    local ok, item = pcall(BUILDERS[kind], id, d)
    if not ok or not item then
        ErrorNoHalt("[DMS] Eigener Eintrag " .. tostring(id) .. ": " .. tostring(item) .. "\n")
        return
    end
    table.insert(LISTS[kind](), item)
    if kind == "injuries" then
        DMS.InjuriesById[id] = item
        DMS.RememberDefaults(item, DMS.InjuryFields)
        return
    end
    item.category = kind
    DMS.ActionsById[id] = item
    DMS.RememberDefaults(item, DMS.ActionFields)
    if kind == "medication" then DMS.RememberDefaults(item, DMS.MedicationFields) end
end

-- Eigene Inhalte (neu) einsetzen; alte eigene Eintraege vorher entfernen
function DMS.RebuildCustom()
    builtinIds()
    for _, get in pairs(LISTS) do
        local list = get()
        for i = #list, 1, -1 do if list[i].custom then table.remove(list, i) end end
    end
    for id, inj in pairs(DMS.InjuriesById) do if inj.custom then DMS.InjuriesById[id] = nil end end
    for id, a in pairs(DMS.ActionsById) do if a.custom then DMS.ActionsById[id] = nil end end
    for id in pairs(DMS.TreatmentEffects) do if not BUILTIN[id] then DMS.TreatmentEffects[id] = nil end end

    local custom = DMS.Config.Custom or {}
    -- Behandlungen zuerst (Verletzungen verweisen darauf)
    for _, kind in ipairs({"treatments", "diagnostics", "medication", "injuries"}) do
        for id, d in SortedPairs(custom[kind] or {}) do
            if istable(d) and not BUILTIN[id] then AddCustom(kind, id, d) end
        end
    end
end

-- Felddaten pruefen (Server): nur bekannte Felder in passender Art
function DMS.CleanCustom(kind, d)
    local schema = DMS.CustomSchema[kind]
    if not schema or not istable(d) then return nil end
    local out = {}
    for _, f in ipairs(schema) do
        local key, art, choices = f[1], f[2], f[5]
        local v = d[key]
        if art == "string" then
            v = string.Trim(string.sub(tostring(v or ""), 1, 80))
            out[key] = v ~= "" and v or f[4]
        elseif art == "number" then
            out[key] = tonumber(v) or f[4]
        elseif art == "bool" then
            out[key] = v == true
        elseif art == "choice" then
            local ok = false
            for _, c in ipairs(choices) do if c[1] == v then ok = true end end
            out[key] = ok and v or f[4]
        elseif art == "multi" then
            local set = {}
            for _, k in ipairs(istable(v) and v or {}) do
                for _, c in ipairs(choices) do if c[1] == k then set[#set + 1] = k end end
            end
            out[key] = set
        elseif art == "list" then
            local list = {}
            for _, k in ipairs(istable(v) and v or {}) do
                local a = DMS.ActionsById[k]
                if a and a.category == "treatments" then list[#list + 1] = k end
            end
            out[key] = list
        elseif art == "map" then
            local map = {}
            for k, target in pairs(istable(v) and v or {}) do
                local a = DMS.ActionsById[k]
                if a and a.category == "treatments" and (target == "remove" or DMS.InjuriesById[target]) then map[k] = target end
            end
            out[key] = map
        end
    end
    return out
end

-- ID aus einem Namen (Kleinbuchstaben, Ziffern, Unterstrich)
function DMS.CustomId(text)
    local id = string.lower(tostring(text or ""))
    id = string.gsub(id, "ä", "ae") id = string.gsub(id, "ö", "oe") id = string.gsub(id, "ü", "ue") id = string.gsub(id, "ß", "ss")
    id = string.gsub(id, "[^%w_]+", "_")
    id = string.gsub(id, "^_+", "") id = string.gsub(id, "_+$", "")
    return string.sub(id, 1, 40)
end

-- Beim Laden (Server: Einstellungen schon aus der Datenbank)
DMS.RebuildCustom()
DMS.ApplyOverrides()
