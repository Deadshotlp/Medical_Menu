--[[
    DMS - Anpassungen aus dem Konfigurationsmenue.

    DMS.Config.Overrides = {
        injuries = {[id] = {disabled, weight, pain, bleeding, puls, bp, spo2, heal,
                            treatment = {ids}, transform = {[behandlung] = ziel}}},
        actions  = {[id] = {disabled, time, medic, duration}},
    }
    Die Werte aus dem Code bleiben als Standard gemerkt; ApplyOverrides setzt
    jeweils Anpassung oder Standard ein (auf Server und Clients).
]]

DMS = DMS or {}

DMS.ActionCategories = {
    {key = "diagnostics", name = "Diagnose", list = DMS.Diagnostics},
    {key = "medication", name = "Medikation", list = DMS.Medication},
    {key = "treatments", name = "Behandlung", list = DMS.Treatments},
    {key = "other", name = "Sonstiges", list = DMS.Other},
}

DMS.ActionsById = {}
for _, cat in ipairs(DMS.ActionCategories) do
    for _, a in ipairs(cat.list) do
        a.category = cat.key
        DMS.ActionsById[a.id] = a
    end
end

-- Welche Felder sind einstellbar (Feld, Art, Beschriftung)
DMS.InjuryFields = {
    {"weight", "number", "Häufigkeit (Gewicht)"},
    {"pain", "number", "Schmerz"},
    {"bleeding", "number", "Blutung je Berechnung (Liter)"},
    {"puls", "number", "Puls-Faktor"},
    {"bp", "number", "Blutdruck-Faktor"},
    {"spo2", "number", "Sauerstoff (Punkte)"},
    {"heal", "number", "Heilzeit (s)"},
    {"treatment", "list", "Behandlungen (IDs)"},
    {"transform", "map", "Umwandlung (Behandlung = Ziel)"},
}
DMS.ActionFields = {
    {"time", "number", "Dauer der Anwendung (s)"},
    {"medic", "bool", "Nur Medics"},
}
DMS.MedicationFields = {
    {"duration", "number", "Wirkdauer (s)"},
}

local function remember(item, fields)
    item.defaults = item.defaults or {}
    for _, f in ipairs(fields) do
        if item.defaults[f[1]] == nil then
            local v = item[f[1]]
            if f[2] == "list" or f[2] == "map" then v = table.Copy(v or {}) end
            item.defaults[f[1]] = v
        end
    end
    if item.defaults.disabled == nil then item.defaults.disabled = item.disabled or false end
end
DMS.RememberDefaults = remember

for _, inj in ipairs(DMS.Injuries) do remember(inj, DMS.InjuryFields) end
for _, a in pairs(DMS.ActionsById) do
    remember(a, DMS.ActionFields)
    if a.category == "medication" then remember(a, DMS.MedicationFields) end
end

local function apply(item, over)
    for k, v in pairs(item.defaults) do
        local o = over and over[k]
        if o ~= nil then item[k] = o else item[k] = v end
    end
end

function DMS.ApplyOverrides()
    local o = DMS.Config.Overrides or {}
    for _, inj in ipairs(DMS.Injuries) do
        apply(inj, (o.injuries or {})[inj.id])
        -- Tabellen nie teilen: Verletzungen am Patienten kopieren ihre Liste
        inj.treatment = table.Copy(inj.treatment or {})
        inj.transform = table.Copy(inj.transform or {})
    end
    for id, a in pairs(DMS.ActionsById) do apply(a, (o.actions or {})[id]) end
end

DMS.ApplyOverrides()

-- Darf actor diese Aktion gerade am Patienten ausfuehren?
function DMS.CanDoAction(actor, action, tbl, part, patient)
    if not action or action.disabled then return false end
    if action.medic and not DMS.IsMedic(actor) then return false end
    local ok, res = pcall(action.condition, actor, tbl, part or 0, patient)
    return ok and res == true
end
