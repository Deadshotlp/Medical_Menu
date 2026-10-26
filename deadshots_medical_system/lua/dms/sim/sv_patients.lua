--[[
    DMS - Patienten (Server): Zustand je Spieler, Speichern, Medic-Erkennung,
    Bewusstlosigkeit (Koerper statt Spieler) und Aufwachen.

    DMS.Patients[steamid64] = Tabelle (siehe NewPatient). Bewusstlose sind
    "tot" (KillSilent) und sehen ihren Koerper (prop_ragdoll mit NW2-Entity
    "DMS.RagdollOwner"); werden die Werte wieder gut oder bringt ein Medic sie
    zurueck, stehen sie an ihrem Koerper wieder auf - mit Ausruestung.
]]

DMS = DMS or {}
DMS.Patients = DMS.Patients or {}

local L = DMS.L

function DMS.NewPatient()
    local parts = {}
    for i, def in ipairs(DMS.BodyParts) do
        parts[i] = {bleeding = 0, has_iv = false, tourniquet = def.limb and false or nil}
    end
    return {
        puls = 75, spo2 = 97, bp = {120, 80},
        triage_card = 0,
        blood_amount = 5.5, blood_to_add = 0,
        pain_level = 0, stunning_level = 0,
        recovery_position = false, vital_monitoring = false,
        respiratory_system = {lungs_functional = true, airway_clear = true, breathing_rate = 15},
        body_part = parts,
        injuries = {}, infections = {}, medication = {},
        activity_log = {}, quick_overview_log = {},
    }
end

function DMS.GetPatient(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return nil end
    local id = ply:SteamID64()
    if not DMS.Patients[id] then DMS.Patients[id] = DMS.NewPatient() end
    return DMS.Patients[id]
end

function DMS.Log(tbl, text)
    tbl.activity_log = tbl.activity_log or {}
    table.insert(tbl.activity_log, {time = os.time(), str = text})
    while #tbl.activity_log > 60 do table.remove(tbl.activity_log, 1) end
end

--------------------------------------------------------------------------------
-- Medic
--------------------------------------------------------------------------------

function DMS.ComputeMedic(ply)
    -- DarkRP: das Feld "medic" im Job (wie beim mitgelieferten Medic-Job)
    if DMS.Get("darkrp_medic") and DMS.HasDarkRP() then
        local job = ply.getJobTable and ply:getJobTable()
        return istable(job) and job.medic == true
    end
    local mode = DMS.Get("medic_mode")
    if mode == "all" then return true end
    local byTeam, byGroup = false, false
    if mode == "teams" or mode == "teams_groups" then
        local name = string.lower(team.GetName(ply:Team()) or "")
        for _, t in ipairs(DMS.GetList("medic_teams")) do if t == name then byTeam = true end end
    end
    if mode == "groups" or mode == "teams_groups" then
        local group = string.lower(ply:GetUserGroup() or "")
        for _, g in ipairs(DMS.GetList("medic_groups")) do if g == group then byGroup = true end end
    end
    return byTeam or byGroup
end

timer.Create("DMS.MedicFlags", 2, 0, function()
    for _, ply in player.Iterator() do
        local medic = DMS.ComputeMedic(ply)
        if ply:GetNW2Bool("DMS.Medic", false) ~= medic then ply:SetNW2Bool("DMS.Medic", medic) end
    end
end)

--------------------------------------------------------------------------------
-- Speichern
--------------------------------------------------------------------------------

function DMS.SavePatient(ply)
    if not DMS.Get("persist") or not IsValid(ply) or ply:IsBot() then return end
    local tbl = DMS.Patients[ply:SteamID64()]
    if tbl then DMS.DB.SavePatient(ply:SteamID64(), tbl) end
end

timer.Create("DMS.Autosave", 60, 0, function()
    for _, ply in player.Iterator() do DMS.SavePatient(ply) end
end)

hook.Add("ShutDown", "DMS.Save", function()
    for _, ply in player.Iterator() do DMS.SavePatient(ply) end
end)

hook.Add("PlayerInitialSpawn", "DMS.Load", function(ply)
    local saved = DMS.Get("persist") and not ply:IsBot() and DMS.DB.LoadPatient(ply:SteamID64())
    if istable(saved) and saved.bp then
        local fresh = DMS.NewPatient()
        for k, v in pairs(fresh) do if saved[k] == nil then saved[k] = v end end
        DMS.Patients[ply:SteamID64()] = saved
        ply.DMS_KeepState = true -- der erste Spawn soll den Zustand nicht zuruecksetzen
    end
end)

--------------------------------------------------------------------------------
-- Bewusstlosigkeit
--------------------------------------------------------------------------------

local function removeRagdoll(ply)
    local rag = ply:GetNW2Entity("DMS.Ragdoll")
    if IsValid(rag) then rag:Remove() end
    ply:SetNW2Entity("DMS.Ragdoll", NULL)
end

function DMS.KnockOut(ply, byHP)
    if not ply:Alive() then return end
    local tbl = DMS.GetPatient(ply)

    local rag = ents.Create("prop_ragdoll")
    rag:SetModel(ply:GetModel())
    rag:SetPos(ply:GetPos())
    rag:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    rag:SetSkin(ply:GetSkin())
    for _, bg in ipairs(ply:GetBodyGroups() or {}) do rag:SetBodygroup(bg.id, ply:GetBodygroup(bg.id)) end
    rag:Spawn()
    rag:Activate()
    rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    local vel = ply:GetVelocity()
    for i = 0, rag:GetPhysicsObjectCount() - 1 do
        local phys = rag:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            local pos, ang = ply:GetBonePosition(rag:TranslatePhysBoneToBone(i))
            if pos then phys:SetPos(pos) phys:SetAngles(ang) end
            phys:SetVelocity(vel)
        end
    end

    rag.DMS_Equip = {}
    for _, wep in ipairs(ply:GetWeapons()) do rag.DMS_Equip[#rag.DMS_Equip + 1] = wep:GetClass() end
    rag.DMS_Ammo = ply:GetAmmo()
    rag.DMS_Health, rag.DMS_Armor = ply:Health(), ply:Armor()
    if byHP then rag.DMS_Health = math.max(1, math.floor(ply:GetMaxHealth() * 0.25)) end

    rag:SetNW2Entity("DMS.RagdollOwner", ply)
    ply:SetNW2Entity("DMS.Ragdoll", rag)

    tbl.down_since = os.time()
    tbl.recovery_position = false
    ply:SetNW2Float("DMS.DownAt", CurTime())
    DMS.Log(tbl, L("Bewusstlos"))

    ply.DMS_Downing = true
    ply:KillSilent()
    ply.DMS_Downing = nil
    ply:Spectate(OBS_MODE_CHASE)
    ply:SpectateEntity(rag)
end

-- Am Koerper wieder aufstehen, mit Ausruestung
function DMS.Revive(ply)
    if ply:Alive() then return end
    local rag = ply:GetNW2Entity("DMS.Ragdoll")
    if not IsValid(rag) then return end

    local pos, mdl, skin = rag:GetPos(), rag:GetModel(), rag:GetSkin()
    local bodygroups = {}
    for _, bg in ipairs(rag:GetBodyGroups() or {}) do bodygroups[bg.id] = rag:GetBodygroup(bg.id) end
    local equip, ammo, hp, armor = rag.DMS_Equip or {}, rag.DMS_Ammo or {}, rag.DMS_Health, rag.DMS_Armor

    ply.DMS_KeepState = true
    ply:UnSpectate()
    ply:Spawn()
    ply:SetPos(pos + Vector(0, 0, 4))
    ply:SetModel(mdl)
    ply:SetSkin(skin)
    for id, v in pairs(bodygroups) do ply:SetBodygroup(id, v) end
    ply:StripWeapons()
    for _, class in ipairs(equip) do ply:Give(class) end
    for id, amount in pairs(ammo) do ply:SetAmmo(amount, id) end
    if hp then ply:SetHealth(math.max(hp, 1)) end
    if armor then ply:SetArmor(armor) end
    removeRagdoll(ply)

    local tbl = DMS.GetPatient(ply)
    tbl.down_since = nil
    tbl.hp_down = nil
    tbl.recovery_position = false
    DMS.Log(tbl, L("Wieder bei Bewusstsein"))
end

hook.Add("PlayerSpawn", "DMS.Spawn", function(ply)
    removeRagdoll(ply)
    if ply.DMS_KeepState then
        ply.DMS_KeepState = nil
    elseif DMS.Get("reset_on_respawn") then
        DMS.Patients[ply:SteamID64()] = DMS.NewPatient()
    end
    local tbl = DMS.GetPatient(ply)
    tbl.down_since = nil
    tbl.hp_down = nil
    ply:SetNW2Float("DMS.DownAt", 0)

    -- Datapad je nach Einstellung
    timer.Simple(0.5, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local mode = DMS.Get("auto_datapad")
        if (mode == "all" or (mode == "medics" and DMS.ComputeMedic(ply))) and not ply:HasWeapon("dms_datapad") then
            ply:Give("dms_datapad")
        end
    end)
end)

-- Respawn erst nach der eingestellten Zeit (0 = nur Wiederbelebung)
hook.Add("PlayerDeathThink", "DMS.RespawnDelay", function(ply)
    local tbl = DMS.Patients[ply:SteamID64()]
    if not tbl or not tbl.down_since or not IsValid(ply:GetNW2Entity("DMS.Ragdoll")) then return end
    local delay = tonumber(DMS.Get("respawn_delay")) or 0
    if delay <= 0 or os.time() - tbl.down_since < delay then return false end
end)

-- Spielt der Spieler nicht mehr, bleibt der Koerper nicht liegen
hook.Add("PlayerDisconnected", "DMS.Disconnect", function(ply)
    DMS.SavePatient(ply)
    removeRagdoll(ply)
    DMS.Patients[ply:SteamID64()] = nil
end)

-- Echter Tod (z. B. kill in der Konsole) waehrend der Bewusstlosigkeit: Koerper weg
hook.Add("PlayerDeath", "DMS.RealDeath", function(ply)
    if ply.DMS_Downing then return end
    removeRagdoll(ply)
end)

-- Lua-Refresh: wer schon spielt, bekommt einen Zustand
for _, ply in player.Iterator() do DMS.GetPatient(ply) end
