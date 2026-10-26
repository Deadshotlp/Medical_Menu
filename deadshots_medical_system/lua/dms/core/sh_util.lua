--[[
    DMS - kleine Hilfen.
]]

DMS = DMS or {}

function DMS.IsBetween(value, low, high)
    return isnumber(value) and value >= low and value <= high
end

-- Lineare Interpolation ueber Stuetzpunkte {{x, y}, ...} (x absteigend oder aufsteigend)
function DMS.Interpolate(x, points)
    table.sort(points, function(a, b) return a.x < b.x end)
    if x <= points[1].x then return points[1].y end
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        if x <= b.x then
            return a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
        end
    end
    return points[#points].y
end

function DMS.DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do copy[DMS.DeepCopy(k)] = DMS.DeepCopy(v) end
    return copy
end

-- Fahrer eines Sitzes (GetDriver gibt es nur auf dem Server)
function DMS.DriverOf(veh)
    if not IsValid(veh) or not veh:IsVehicle() then return nil end
    if SERVER then
        local d = veh:GetDriver()
        return IsValid(d) and d or nil
    end
    for _, ply in player.Iterator() do
        if ply:GetVehicle() == veh then return ply end
    end
    return nil
end

-- Spieler hinter einem Ziel: Spieler selbst, Koerper (Ragdoll) eines
-- Bewusstlosen oder Insasse eines Sitzes
function DMS.PatientOf(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return ent end
    if ent:GetClass() == "prop_ragdoll" then
        local owner = ent:GetNW2Entity("DMS.RagdollOwner")
        return IsValid(owner) and owner or nil
    end
    if ent:IsVehicle() then return DMS.DriverOf(ent) end
    return nil
end

-- Wo liegt der Patient gerade (fuer Abstaende): Spieler oder sein Koerper
function DMS.BodyOf(ply)
    if not IsValid(ply) then return nil end
    if ply:Alive() then return ply end
    local rag = ply:GetNW2Entity("DMS.Ragdoll")
    return IsValid(rag) and rag or nil
end

function DMS.InRange(actor, patient, extra)
    local body = DMS.BodyOf(patient)
    if not IsValid(actor) or not IsValid(body) then return false end
    if actor == patient then return true end
    local range = (DMS.Get and DMS.Get("interaction_range") or 100) + (extra or 0)
    local eye = actor:EyePos()
    return eye:DistToSqr(body:NearestPoint(eye)) <= range * range
end

-- Laeuft DarkRP? (Jobs mit eigenen Feldern wie medic = true)
function DMS.HasDarkRP()
    return istable(DarkRP) and istable(RPExtraTeams)
end

-- Medic? Server entscheidet (Einstellungen) und verteilt es als NW2-Bool
function DMS.IsMedic(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if SERVER and DMS.ComputeMedic then return DMS.ComputeMedic(ply) end
    return ply:GetNW2Bool("DMS.Medic", false)
end

function DMS.FormatTime(t)
    return os.date("%H:%M:%S", t)
end
