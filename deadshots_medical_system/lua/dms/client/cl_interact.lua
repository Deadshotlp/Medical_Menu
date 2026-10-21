--[[
    DMS - Zugang zum Behandlungsfenster (Client).

      - Rechtsklick im C-Menue auf Spieler oder Koerper:
        "Medizinisch untersuchen"
      - Datapad (dms_datapad): Linksklick = Ziel, Rechtsklick = selbst
      - Konsole: dms_open (Ziel unter dem Fadenkreuz), dms_self
]]

DMS = DMS or {}

local L = DMS.L

local function canOpen(ent)
    local patient = DMS.PatientOf(ent)
    return IsValid(patient) and patient:IsPlayer() and DMS.InRange(LocalPlayer(), patient, 30)
end

properties.Add("dms_examine", {
    MenuLabel = "Medizinisch untersuchen",
    Order = 900,
    MenuIcon = "icon16/heart.png",
    Filter = function(_, ent, ply)
        return IsValid(ent) and IsValid(ply) and ply:Alive() and canOpen(ent)
    end,
    Action = function(_, ent) DMS.OpenPatient(ent) end,
})

-- Beschriftung in der eingestellten Sprache
local function relabel()
    local p = properties.List and properties.List["dms_examine"]
    if p then p.MenuLabel = L("Medizinisch untersuchen") end
end
relabel()
hook.Add("DMS.ConfigChanged", "DMS.Relabel", relabel)
cvars.AddChangeCallback("dms_language", relabel, "DMS.Relabel")

function DMS.OpenLookedAt()
    local ply = LocalPlayer()
    local ent = ply:GetEyeTrace().Entity
    if canOpen(ent) then
        DMS.OpenPatient(ent)
    else
        notification.AddLegacy(L("Kein Patient in Reichweite."), NOTIFY_ERROR, 3)
    end
end

concommand.Add("dms_open", function() DMS.OpenLookedAt() end)
concommand.Add("dms_self", function() DMS.OpenPatient(LocalPlayer()) end)
