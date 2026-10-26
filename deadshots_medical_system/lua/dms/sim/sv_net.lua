--[[
    DMS - Netz (Server).

      DMS.Open    Client -> Server: Patient (Spieler oder Koerper) oeffnen
      DMS.Close   Client -> Server: Fenster zu
      DMS.Action  Client -> Server: Aktion beginnen ("start") / abschliessen
                  ("finish") / abbrechen ("cancel"). Die Dauer prueft der Server.
      DMS.Triage  Client -> Server: Triage-Karte setzen (Medics)
      DMS.Data    Server -> Client: Zustand des Patienten (jede Berechnung an
                  alle, die ihn gerade offen haben)
      DMS.ActionStarted  Server -> Client: Aktion laeuft, Dauer
]]

DMS = DMS or {}
DMS.Viewers = DMS.Viewers or {} -- [patient] = {[viewer] = true}

local L = DMS.L

util.AddNetworkString("DMS.Open")
util.AddNetworkString("DMS.Close")
util.AddNetworkString("DMS.Action")
util.AddNetworkString("DMS.Triage")
util.AddNetworkString("DMS.Data")
util.AddNetworkString("DMS.ActionStarted")

local function notify(ply, text)
    if IsValid(ply) then ply:ChatPrint("[" .. L("Medizin") .. "] " .. text) end
end

-- Zustand an einen Betrachter
function DMS.SendPatient(viewer, patient)
    local tbl = DMS.GetPatient(patient)
    if not tbl then return end
    local data = DMS.DeepCopy(tbl)
    data.alive = patient:Alive()
    data.name = patient:Nick()
    data.down_left = nil
    if tbl.down_since then
        local delay = tonumber(DMS.Get("respawn_delay")) or 0
        data.down_left = delay > 0 and math.max(0, delay - (os.time() - tbl.down_since)) or -1
    end
    local packed = util.Compress(util.TableToJSON(data) or "{}") or ""
    net.Start("DMS.Data")
    net.WriteEntity(patient)
    net.WriteUInt(#packed, 32)
    net.WriteData(packed, #packed)
    net.Send(viewer)
end

function DMS.SendToViewers(patient)
    local viewers = DMS.Viewers[patient]
    if not viewers then return end
    for viewer in pairs(viewers) do
        if IsValid(viewer) and (viewer == patient or (viewer:Alive() and DMS.InRange(viewer, patient, 150))) then
            DMS.SendPatient(viewer, patient)
        else
            viewers[viewer] = nil
        end
    end
end

local function readPatient(ply)
    local patient = DMS.PatientOf(net.ReadEntity())
    if not IsValid(patient) or not patient:IsPlayer() then return nil end
    if patient == ply then return patient end -- eigener Zustand, auch bewusstlos
    if not ply:Alive() or not DMS.InRange(ply, patient, 50) then return nil end
    return patient
end

net.Receive("DMS.Open", function(_, ply)
    local patient = readPatient(ply)
    if not patient then return end
    DMS.Viewers[patient] = DMS.Viewers[patient] or {}
    DMS.Viewers[patient][ply] = true
    DMS.SendPatient(ply, patient)
end)

net.Receive("DMS.Close", function(_, ply)
    local patient = net.ReadEntity()
    if IsValid(patient) and DMS.Viewers[patient] then DMS.Viewers[patient][ply] = nil end
    ply.DMS_Pending = nil
end)

-- Ein Eintrag ins Aktivitaetsprotokoll
local function logAction(tbl, actor, action, part)
    local where = part > 0 and (" (" .. L(DMS.BodyParts[part].name) .. ")") or ""
    DMS.Log(tbl, actor:Nick() .. ": " .. L(action.name) .. where)
end

-- Fuehrt gerade jemand an diesem Patienten eine HLW durch (Aktion laeuft,
-- Helfer in Reichweite)?
function DMS.CPRActive(patient)
    for _, ply in player.Iterator() do
        local p = ply.DMS_Pending
        if p and p.id == "cpr" and p.patient == patient and ply:Alive() and DMS.InRange(ply, patient, 50) then return true end
    end
    return false
end

net.Receive("DMS.Action", function(_, ply)
    local phase = net.ReadString()
    if phase == "cancel" then
        ply.DMS_Pending = nil
        return
    end

    local patient = readPatient(ply)
    local id = net.ReadString()
    local part = net.ReadUInt(4)
    if not patient or not ply:Alive() then return end
    local action = DMS.ActionsById[id]
    local tbl = DMS.GetPatient(patient)
    if not action or (part > 7) then return end

    if phase == "start" then
        if ply.DMS_Pending then return end
        if not DMS.CanDoAction(ply, action, tbl, part, patient) then
            notify(ply, L("Das geht gerade nicht."))
            return
        end
        ply.DMS_Pending = {patient = patient, id = id, part = part, start = CurTime()}
        net.Start("DMS.ActionStarted")
        net.WriteString(id)
        net.WriteFloat(action.time or 0)
        net.Send(ply)
    elseif phase == "finish" then
        local p = ply.DMS_Pending
        ply.DMS_Pending = nil
        if not p or p.patient ~= patient or p.id ~= id or p.part ~= part then return end
        if CurTime() - p.start < (action.time or 0) - 0.5 then return end
        if not DMS.CanDoAction(ply, action, tbl, part, patient) then
            notify(ply, L("Das geht gerade nicht."))
            return
        end
        local ok, err = pcall(action.effect, ply, tbl, part, patient)
        if not ok then
            ErrorNoHalt("[DMS] Aktion " .. id .. ": " .. tostring(err) .. "\n")
            return
        end
        logAction(tbl, ply, action, part)
        patient:EmitSound("items/medshot4.wav", 55, 100)
        DMS.SendToViewers(patient)
    end
end)

net.Receive("DMS.Triage", function(_, ply)
    local patient = readPatient(ply)
    local card = net.ReadUInt(3)
    if not patient or not ply:Alive() or not DMS.IsMedic(ply) or card > 4 then return end
    local tbl = DMS.GetPatient(patient)
    tbl.triage_card = card
    DMS.SendToViewers(patient)
end)

hook.Add("PlayerDisconnected", "DMS.Viewers", function(ply)
    DMS.Viewers[ply] = nil
    for _, viewers in pairs(DMS.Viewers) do viewers[ply] = nil end
end)
