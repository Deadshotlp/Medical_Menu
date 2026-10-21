--[[
    DMS - Sprachen.

    Alle sichtbaren Texte stehen im Code auf Deutsch und laufen durch
    DMS.L(text). Fuer andere Sprachen liegt in lua/dms/lang/<code>.lua ein
    Woerterbuch {["deutscher Text"] = "Uebersetzung"}; fehlt ein Eintrag,
    bleibt der deutsche Text.

    Sprache: Konsolenvariable dms_language (de, en, fr; Standard en), vom
    Server an alle verteilt und im Konfigurationsmenue einstellbar.
]]

DMS = DMS or {}
DMS.Strings = DMS.Strings or {}

DMS.Languages = {
    {id = "de", name = "Deutsch"},
    {id = "en", name = "English"},
    {id = "fr", name = "Français"},
}

local cvar = CreateConVar("dms_language", "en", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Medical System: language (de, en, fr)")

function DMS.Lang()
    local lang = cvar:GetString()
    if lang == "de" or DMS.Strings[lang] then return lang end
    return "de"
end

function DMS.L(text)
    local lang = DMS.Lang()
    if lang == "de" or not isstring(text) then return text end
    local dict = DMS.Strings[lang]
    return dict and dict[text] or text
end

for _, f in ipairs(file.Find("dms/lang/*.lua", "LUA")) do
    local path = "dms/lang/" .. f
    if SERVER then AddCSLuaFile(path) end
    local ok, dict = pcall(include, path)
    if ok and istable(dict) then DMS.Strings[string.StripExtension(f)] = dict end
end
