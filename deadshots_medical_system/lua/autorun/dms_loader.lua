--[[
    Deadshot's Medical System - Loader.

    Laedt die Dateien in fester Reihenfolge: Kern (Sprache, Einstellungen,
    Hilfen, Datenbank), Daten (Koerperteile, Verletzungen, Behandlungen ...),
    Simulation, Oberflaeche, Konfiguration. Praefix sh_/sv_/cl_ bestimmt, wo
    eine Datei laeuft.

    Laeuft der Gamemode starwarsrp mit eigenem Medizin- und Todesmodul, bleibt
    das Addon aus - beide wuerden dieselben Spieler verwalten.
]]

if engine.ActiveGamemode() == "starwarsrp" and file.Exists("starwarsrp/gamemode/modules/medizin", "LUA") then
    MsgC(Color(255, 170, 60), "[DMS] starwarsrp has its own medical system - addon not loaded\n")
    return
end

DMS = DMS or {}

local FILES = {
    "core/sh_lang.lua",
    "core/sh_util.lua",
    "core/sh_config.lua",
    "core/sv_db.lua",
    "core/cl_ui.lua",

    "data/sh_bodyparts.lua",
    "data/sh_injuries.lua",
    "data/sh_treatments.lua",
    "data/sh_medication.lua",
    "data/sh_other.lua",
    "data/sh_diagnostics.lua",
    "data/sh_overrides.lua",
    "data/sh_custom.lua",

    "sim/sv_patients.lua",
    "sim/sv_vitals.lua",
    "sim/sv_damage.lua",
    "sim/sv_net.lua",

    "client/cl_interface.lua",
    "client/cl_hud.lua",
    "client/cl_interact.lua",

    "server/sv_config.lua",
    "client/cl_config.lua",
}

for _, rel in ipairs(FILES) do
    local path = "dms/" .. rel
    local name = string.GetFileFromFilename(rel)
    if string.StartWith(name, "sh_") then
        if SERVER then AddCSLuaFile(path) end
        include(path)
    elseif string.StartWith(name, "sv_") then
        if SERVER then include(path) end
    elseif string.StartWith(name, "cl_") then
        if SERVER then AddCSLuaFile(path) else include(path) end
    end
end

MsgC(Color(90, 210, 130), "[DMS] Deadshot's Medical System loaded\n")
