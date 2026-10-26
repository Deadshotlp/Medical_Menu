--[[
    DMS - Konfiguration (Server). Nur Superadmins.

      DMS.CfgSet       Einstellung setzen (Schluessel, Wert als JSON)
      DMS.CfgOverride  Anpassung einer Verletzung/Aktion (Art, ID, JSON oder leer = Standard)
      DMS.CfgCustom    eigener Inhalt (Art, ID, JSON oder leer = loeschen), data/sh_custom.lua
      DMS.CfgReset     alle Einstellungen und Anpassungen zuruecksetzen
      DMS.CfgLang      Sprache (dms_language)
      DMS.CfgPatients  Liste der Spieler mit Zustand anfordern / senden
      DMS.CfgAdmin     Spieler heilen ("heal") oder wiederbeleben ("revive")
]]

DMS = DMS or {}

local L = DMS.L

for _, n in ipairs({"DMS.CfgSet", "DMS.CfgOverride", "DMS.CfgCustom", "DMS.CfgReset", "DMS.CfgLang", "DMS.CfgPatients", "DMS.CfgAdmin"}) do
    util.AddNetworkString(n)
end

local function allowed(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

local function changed()
    DMS.RebuildCustom()
    DMS.ApplyOverrides()
    DMS.SendConfig()
end

net.Receive("DMS.CfgSet", function(_, ply)
    if not allowed(ply) then return end
    local key = net.ReadString()
    local raw = util.JSONToTable(net.ReadString() or "") or {}
    local value = DMS.CoerceSetting(key, raw.v)
    if value == nil then return end
    DMS.Config.Values[key] = value
    DMS.DB.SaveSetting(key, value)
    changed()
end)

local OVERRIDE_FIELDS = {injuries = {}, actions = {}}
for _, f in ipairs(DMS.InjuryFields) do OVERRIDE_FIELDS.injuries[f[1]] = f[2] end
for _, f in ipairs(DMS.ActionFields) do OVERRIDE_FIELDS.actions[f[1]] = f[2] end
for _, f in ipairs(DMS.MedicationFields) do OVERRIDE_FIELDS.actions[f[1]] = f[2] end

net.Receive("DMS.CfgOverride", function(_, ply)
    if not allowed(ply) then return end
    local kind, id = net.ReadString(), net.ReadString()
    local data = util.JSONToTable(net.ReadString() or "")
    local fields = OVERRIDE_FIELDS[kind]
    if not fields then return end
    if kind == "injuries" and not DMS.InjuriesById[id] then return end
    if kind == "actions" and not DMS.ActionsById[id] then return end

    local o = DMS.Config.Overrides
    o[kind] = o[kind] or {}
    if istable(data) then
        local clean = {}
        for k, v in pairs(data) do
            if k == "disabled" then
                clean.disabled = v == true
            elseif fields[k] == "number" and tonumber(v) then
                clean[k] = tonumber(v)
            elseif fields[k] == "bool" then
                clean[k] = v == true
            elseif fields[k] == "list" and istable(v) then
                -- nur bekannte Behandlungen
                local list = {}
                for _, t in ipairs(v) do
                    local a = DMS.ActionsById[t]
                    if a and a.category == "treatments" then list[#list + 1] = t end
                end
                clean[k] = list
            elseif fields[k] == "map" and istable(v) then
                -- Behandlung -> Verletzung oder "remove"
                local map = {}
                for t, target in pairs(v) do
                    local a = DMS.ActionsById[t]
                    if a and a.category == "treatments" and (target == "remove" or DMS.InjuriesById[target]) then map[t] = target end
                end
                clean[k] = map
            end
        end
        o[kind][id] = next(clean) and clean or nil
    else
        o[kind][id] = nil
    end
    DMS.DB.SaveSetting("overrides", o)
    changed()
end)

net.Receive("DMS.CfgCustom", function(_, ply)
    if not allowed(ply) then return end
    local kind, id = net.ReadString(), DMS.CustomId(net.ReadString())
    local data = util.JSONToTable(net.ReadString() or "")
    if not DMS.CustomSchema[kind] or id == "" then return end
    if DMS.IsBuiltinId(id) then
        ply:ChatPrint("[DMS] " .. string.format(L("Die ID %s gehört zu einem mitgelieferten Eintrag."), id))
        return
    end
    -- Eine ID gilt nur fuer eine Art
    for _, k in ipairs(DMS.CustomKinds) do
        if k.key ~= kind and ((DMS.Config.Custom or {})[k.key] or {})[id] then
            ply:ChatPrint("[DMS] " .. string.format(L("Die ID %s ist schon vergeben."), id))
            return
        end
    end

    local c = DMS.Config.Custom or {}
    DMS.Config.Custom = c
    c[kind] = c[kind] or {}
    c[kind][id] = istable(data) and DMS.CleanCustom(kind, data) or nil
    DMS.DB.SaveSetting("custom", c)
    changed()
    ply:ChatPrint("[DMS] " .. (c[kind][id] and string.format(L("%s gespeichert."), id) or string.format(L("%s gelöscht."), id)))
end)

net.Receive("DMS.CfgReset", function(_, ply)
    if not allowed(ply) then return end
    sql.Query("DELETE FROM dms_settings")
    DMS.Config.Values = {}
    DMS.Config.Overrides = {}
    DMS.Config.Custom = {}
    changed()
    ply:ChatPrint("[DMS] " .. L("Alle Einstellungen zurückgesetzt."))
end)

net.Receive("DMS.CfgLang", function(_, ply)
    if not allowed(ply) then return end
    local lang = net.ReadString()
    for _, l in ipairs(DMS.Languages) do
        if l.id == lang then RunConsoleCommand("dms_language", lang) end
    end
end)

local function sendPatients(ply)
    local list = {}
    for _, p in player.Iterator() do
        local tbl = DMS.GetPatient(p)
        list[#list + 1] = {
            ent = p:EntIndex(), name = p:Nick(), alive = p:Alive(), down = IsValid(p:GetNW2Entity("DMS.Ragdoll")),
            puls = tbl.puls, spo2 = tbl.spo2, blood = math.Round(tbl.blood_amount, 2), injuries = #tbl.injuries,
            medic = DMS.ComputeMedic(p),
        }
    end
    net.Start("DMS.CfgPatients")
    net.WriteString(util.TableToJSON(list) or "[]")
    net.Send(ply)
end

net.Receive("DMS.CfgPatients", function(_, ply)
    if allowed(ply) then sendPatients(ply) end
end)

net.Receive("DMS.CfgAdmin", function(_, ply)
    if not allowed(ply) then return end
    local what, target = net.ReadString(), net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end
    if what == "heal" then
        local old = DMS.GetPatient(target)
        local fresh = DMS.NewPatient()
        fresh.activity_log = old.activity_log
        fresh.triage_card = 0
        DMS.Patients[target:SteamID64()] = fresh
        DMS.Log(fresh, string.format(L("Von %s (Admin) geheilt"), ply:Nick()))
        if not target:Alive() then DMS.Revive(target) end
    elseif what == "revive" then
        local tbl = DMS.GetPatient(target)
        -- Kreislauf wieder in Gang, Verletzungen bleiben
        tbl.stunning_level = 0
        tbl.revive_boost = os.time() + 30
        tbl.puls, tbl.spo2, tbl.bp = 75, 97, {120, 80}
        tbl.respiratory_system.airway_clear = true
        tbl.blood_amount = math.max(tbl.blood_amount, 4.5)
        if not target:Alive() then DMS.Revive(target) end
    end
    DMS.SendToViewers(target)
    timer.Simple(0.2, function() if IsValid(ply) then sendPatients(ply) end end)
end)
