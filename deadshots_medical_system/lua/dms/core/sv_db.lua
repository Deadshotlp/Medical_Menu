--[[
    DMS - Speicher (SQLite, sv.db).

      dms_settings  key -> JSON-Wert (Einstellungen, "overrides")
      dms_patients  steamid -> JSON (Zustand eines Spielers, wenn
                    "persist" an ist)
]]

DMS = DMS or {}
DMS.DB = DMS.DB or {}
local DB = DMS.DB

util.AddNetworkString("DMS.Config")

sql.Query("CREATE TABLE IF NOT EXISTS dms_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
sql.Query("CREATE TABLE IF NOT EXISTS dms_patients (steamid TEXT PRIMARY KEY, data TEXT NOT NULL, updated INTEGER NOT NULL DEFAULT 0)")

local function encode(v) return util.TableToJSON({v = v}) or "{}" end
local function decode(s) local t = util.JSONToTable(s or "") return t and t.v end

function DB.LoadSettings()
    local values, overrides = {}, {}
    for _, row in ipairs(sql.Query("SELECT key, value FROM dms_settings") or {}) do
        local v = decode(row.value)
        if row.key == "overrides" then
            overrides = istable(v) and v or {}
        elseif DMS.SettingDefsByKey[row.key] and v ~= nil then
            values[row.key] = v
        end
    end
    DMS.Config.Values = values
    DMS.Config.Overrides = overrides
end

function DB.SaveSetting(key, value)
    sql.Query("REPLACE INTO dms_settings (key, value) VALUES (" .. sql.SQLStr(key) .. ", " .. sql.SQLStr(encode(value)) .. ")")
end

function DB.SavePatient(steamid, data)
    sql.Query("REPLACE INTO dms_patients (steamid, data, updated) VALUES (" .. sql.SQLStr(steamid) .. ", "
        .. sql.SQLStr(util.TableToJSON(data) or "{}") .. ", " .. os.time() .. ")")
end

function DB.LoadPatient(steamid)
    local row = sql.QueryRow("SELECT data FROM dms_patients WHERE steamid = " .. sql.SQLStr(steamid))
    return row and util.JSONToTable(row.data) or nil
end

function DB.DeletePatient(steamid)
    sql.Query("DELETE FROM dms_patients WHERE steamid = " .. sql.SQLStr(steamid))
end

-- Einstellungen an einen oder alle Clients
function DMS.SendConfig(target)
    local packed = util.Compress(util.TableToJSON({values = DMS.Config.Values, overrides = DMS.Config.Overrides}) or "{}") or ""
    net.Start("DMS.Config")
    net.WriteUInt(#packed, 32)
    net.WriteData(packed, #packed)
    if IsValid(target) then net.Send(target) else net.Broadcast() end
end

DB.LoadSettings()

hook.Add("PlayerInitialSpawn", "DMS.SendConfig", function(ply)
    timer.Simple(2, function() if IsValid(ply) then DMS.SendConfig(ply) end end)
end)
