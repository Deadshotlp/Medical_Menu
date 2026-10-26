--[[
    DMS - Einstellungen.

    DMS.SettingDefs beschreibt jede Einstellung (Schluessel, Standard, Art,
    Gruppe, Beschriftung, Einheit). Arten: number, bool, string, choice, key
    (Taste, KEY_*-Wert; 0 = keine). Werte speichert der Server in SQLite
    (sv_db.lua) und schickt sie an alle Clients (net "DMS.Config"); geaendert
    werden sie im Konfigurationsmenue (server/sv_config.lua).

    Ausserdem "overrides": Anpassungen einzelner Verletzungen, Behandlungen,
    Medikamente und Massnahmen (siehe data/sh_overrides.lua).
]]

DMS = DMS or {}
DMS.Config = DMS.Config or {}

-- {key, default, kind, group, label, unit, options}
DMS.SettingDefs = {
    -- Allgemein
    {"medic_mode", "all", "choice", "general", "Wer gilt als Medic", "", {
        {"all", "Alle Spieler"}, {"teams", "Bestimmte Teams"}, {"groups", "Bestimmte Benutzergruppen"},
        {"teams_groups", "Teams oder Benutzergruppen"}}},
    {"medic_teams", "", "string", "general", "Medic-Teams", "Teamnamen, mit Komma getrennt"},
    {"medic_groups", "", "string", "general", "Medic-Benutzergruppen", "z. B. medic, admin"},
    {"darkrp_medic", false, "bool", "general", "DarkRP Medic verwenden", "Medic = Job mit medic = true (ersetzt die Auswahl oben)"},
    {"interaction_range", 100, "number", "general", "Reichweite für Behandlungen", "Einheiten"},
    {"auto_datapad", "medics", "choice", "general", "Medizinisches Datapad beim Spawn", "", {
        {"none", "Niemand"}, {"medics", "Nur Medics"}, {"all", "Alle Spieler"}}},
    {"update_interval", 1, "number", "general", "Berechnung der Vitalwerte alle", "s"},

    -- Schaden
    {"death_mode", "injuries", "choice", "damage", "Wer entscheidet über Bewusstlosigkeit", "", {
        {"injuries", "Nur Verletzungen (Vitalwerte)"}, {"both", "Lebenspunkte und Verletzungen (was zuerst eintritt)"},
        {"hp", "Nur Lebenspunkte"}}},
    {"damage_per_injury", 20, "number", "damage", "Schaden je zusätzlicher Verletzung", "Schadenspunkte"},
    {"armor_value", 65, "number", "damage", "Schutz durch Rüstung", "0 - 100, 0 = keine Rüstung"},
    {"blood_regen", 0.0005, "number", "damage", "Natürliche Blutbildung", "Liter je Berechnung"},

    -- Bewusstlosigkeit und Tod
    {"persist", true, "bool", "unconscious", "Zustand über Reconnects speichern", ""},
    {"reset_on_respawn", true, "bool", "unconscious", "Nach Respawn gesund", ""},
    {"respawn_delay", 180, "number", "unconscious", "Bewusstlose dürfen respawnen nach", "s, 0 = nur Wiederbelebung"},
    {"airway_block_chance", 2, "number", "unconscious", "Atemwege verlegen sich (ohne Seitenlage)", "% je Berechnung"},
    {"unc_puls_min", 30, "number", "unconscious", "Bewusstlos: Puls unter", "bpm"},
    {"unc_sys_min", 40, "number", "unconscious", "Bewusstlos: systolisch unter", "mmHg"},
    {"unc_sys_max", 200, "number", "unconscious", "Bewusstlos: systolisch über", "mmHg"},
    {"unc_dia_min", 20, "number", "unconscious", "Bewusstlos: diastolisch unter", "mmHg"},
    {"unc_dia_max", 150, "number", "unconscious", "Bewusstlos: diastolisch über", "mmHg"},
    {"unc_spo2_min", 50, "number", "unconscious", "Bewusstlos: Sauerstoffsättigung unter", "%"},
    {"unc_pain_max", 4, "number", "unconscious", "Bewusstlos: Schmerz ab", "Stufe"},
    {"wake_puls_min", 50, "number", "unconscious", "Aufwachen: Puls ab", "bpm"},
    {"wake_puls_max", 120, "number", "unconscious", "Aufwachen: Puls bis", "bpm"},
    {"wake_sys_min", 60, "number", "unconscious", "Aufwachen: systolisch ab", "mmHg"},
    {"wake_dia_min", 40, "number", "unconscious", "Aufwachen: diastolisch ab", "mmHg"},
    {"wake_spo2_min", 85, "number", "unconscious", "Aufwachen: Sauerstoffsättigung ab", "%"},

    -- Module (aus = Teil der Simulation laeuft nicht)
    {"mod_infections", true, "bool", "modules", "Infektionen", "offene Wunden entzünden sich"},
    {"mod_bleeding", true, "bool", "modules", "Blutungen", "Blutverlust durch Verletzungen"},
    {"mod_pain", true, "bool", "modules", "Schmerz", "Schmerz wirkt auf Puls, Blutdruck und Bewusstsein"},
    {"mod_airway", true, "bool", "modules", "Atemwege", "verlegte Atemwege bei Bewusstlosen, Atemdepression"},
    {"stun_attachments", true, "bool", "modules", "ArcCW-Betäubungsmunition erkennen", ""},
    {"hud_enabled", true, "bool", "modules", "Vitalwerte-Anzeige bei kritischen Werten", ""},

    -- Steuerung und Datapad
    {"key_examine", 0, "key", "controls", "Taste: Patient untersuchen", "Spieler oder Körper unter dem Fadenkreuz"},
    {"key_self", 0, "key", "controls", "Taste: eigenen Zustand ansehen", ""},
    {"key_self_down", KEY_F3, "key", "controls", "Taste: eigener Zustand (bewusstlos)", ""},
    {"datapad_viewmodel", "models/weapons/c_medkit.mdl", "string", "controls", "Datapad: Modell in der Hand", "View-Modell (.mdl)"},
    {"datapad_worldmodel", "models/weapons/w_medkit.mdl", "string", "controls", "Datapad: Modell für andere", "World-Modell (.mdl)"},
    {"datapad_usehands", true, "bool", "controls", "Datapad: Spielerhände anzeigen", "nur bei c_-Modellen"},

    -- Infektionen
    {"infection_chance", 0.2, "number", "infection", "Infektionsrisiko offener Wunden", "% je Berechnung"},
    {"infection_growth", 0.002, "number", "infection", "Fortschreiten einer Infektion", "je Berechnung (1 = voll)"},
}

DMS.SettingGroups = {
    {"general", "Allgemein"},
    {"modules", "Module"},
    {"controls", "Steuerung und Datapad"},
    {"damage", "Schaden"},
    {"unconscious", "Bewusstlosigkeit und Tod"},
    {"infection", "Infektionen"},
}

local defsByKey = {}
for _, d in ipairs(DMS.SettingDefs) do defsByKey[d[1]] = d end
DMS.SettingDefsByKey = defsByKey

DMS.Config.Values = DMS.Config.Values or {}
DMS.Config.Overrides = DMS.Config.Overrides or {}

function DMS.Get(key)
    local v = DMS.Config.Values[key]
    if v ~= nil then return v end
    local d = defsByKey[key]
    return d and d[2]
end

-- Wert passend zur Art umwandeln (aus dem Menue kommt Text)
function DMS.CoerceSetting(key, value)
    local d = defsByKey[key]
    if not d then return nil end
    local kind = d[3]
    if kind == "number" or kind == "key" then
        local n = tonumber(value)
        if kind == "key" and n then n = math.Clamp(math.floor(n), 0, 255) end
        return n
    elseif kind == "bool" then
        return value == true or value == 1 or value == "1" or value == "true"
    elseif kind == "choice" then
        for _, o in ipairs(d[7] or {}) do if o[1] == value then return value end end
        return nil
    end
    return string.sub(tostring(value or ""), 1, 400)
end

-- Kommagetrennte Liste aus einer Einstellung
function DMS.GetList(key)
    local out = {}
    for _, part in ipairs(string.Explode(",", tostring(DMS.Get(key) or ""))) do
        part = string.Trim(part)
        if part ~= "" then out[#out + 1] = string.lower(part) end
    end
    return out
end

if CLIENT then
    net.Receive("DMS.Config", function()
        local size = net.ReadUInt(32)
        local data = util.JSONToTable(util.Decompress(net.ReadData(size)) or "") or {}
        DMS.Config.Values = data.values or {}
        DMS.Config.Overrides = data.overrides or {}
        DMS.Config.Custom = data.custom or {}
        if DMS.RebuildCustom then DMS.RebuildCustom() end
        if DMS.ApplyOverrides then DMS.ApplyOverrides() end
        hook.Run("DMS.ConfigChanged")
    end)
end
