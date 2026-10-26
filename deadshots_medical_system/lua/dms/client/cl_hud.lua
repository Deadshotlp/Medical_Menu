--[[
    DMS - Anzeige (Client).

    Bewusstlos: Bildschirm abgedunkelt, Hinweis, Countdown bis zum Respawn und
    Knopf (F3) fuer den eigenen Zustand. Bei Bewusstsein (wenn "hud_enabled"):
    kleine Warnung, wenn Puls oder Sauerstoff aus dem Rahmen fallen.
]]

DMS = DMS or {}

local L = DMS.L
local COL = DMS.UI.COL

local function isDown(ply)
    return not ply:Alive() and IsValid(ply:GetNW2Entity("DMS.Ragdoll"))
end

hook.Add("HUDPaint", "DMS.HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local w, h = ScrW(), ScrH()

    if isDown(ply) then
        surface.SetDrawColor(0, 0, 0, 200)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText(L("Bewusstlos"), "DMS.60", w / 2, h * 0.38, COL.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(L("Ein Medic oder Kamerad kann dich versorgen."), "DMS.22", w / 2, h * 0.45, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local delay = tonumber(DMS.Get("respawn_delay")) or 0
        local text
        if delay <= 0 then
            text = L("Respawn nur durch Wiederbelebung")
        else
            local left = math.ceil(ply:GetNW2Float("DMS.DownAt", 0) + delay - CurTime())
            text = left > 0 and string.format(L("Respawn möglich in %d s"), left) or L("Klicken, um zu respawnen")
        end
        draw.SimpleText(text, "DMS.20", w / 2, h * 0.5, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local key = tonumber(DMS.Get("key_self_down")) or 0
        if key > 0 then
            draw.SimpleText(string.format(L("%s: eigenen Zustand ansehen"), string.upper(input.GetKeyName(key) or "?")), "DMS.18",
                w / 2, h * 0.54, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return
    end

    if not ply:Alive() or not DMS.Get("hud_enabled") then return end
    local puls, spo2 = ply:GetNW2Int("DMS.Puls", 75), ply:GetNW2Int("DMS.SPO2", 97)
    local warn = {}
    if puls < 60 or puls > 180 then warn[#warn + 1] = string.format(L("Puls: %d bpm"), puls) end
    if spo2 < 90 then warn[#warn + 1] = string.format(L("Sauerstoffsättigung: %d %%"), spo2) end
    if #warn == 0 then return end

    local pulse = math.abs(math.sin(CurTime() * 3))
    local col = Color(COL.bad.r, COL.bad.g, COL.bad.b, 120 + pulse * 135)
    local y = h * 0.8
    for i, t in ipairs(warn) do
        draw.SimpleTextOutlined(t, "DMS.20", w / 2, y + (i - 1) * 24, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
    end
end)

-- Tasten aus den Einstellungen (Konfiguration "Steuerung und Datapad"):
-- Patient untersuchen, eigener Zustand, eigener Zustand im Bewusstlosen.
-- Nochmal druecken schliesst das offene Fenster. Beim Aufwachen schliesst
-- das eigene Fenster.
local wasDown = false
local keysWas = {}

local function pressed(setting)
    local key = tonumber(DMS.Get(setting)) or 0
    local now = key > 0 and input.IsKeyDown(key) or false
    local edge = now and not keysWas[setting]
    keysWas[setting] = now
    return edge
end

hook.Add("Think", "DMS.SelfKey", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local down = isDown(ply)
    local free = not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible() and not ply:IsTyping()
    local examine, self_, selfDown = pressed("key_examine"), pressed("key_self"), pressed("key_self_down")

    if free then
        local open = IsValid(DMS.Interface.frame)
        if (examine or self_ or (selfDown and down)) and open then
            DMS.Interface.Close()
        elseif down and (selfDown or self_) then
            DMS.OpenPatient(ply)
        elseif not down and self_ then
            DMS.OpenPatient(ply)
        elseif not down and examine and ply:Alive() and not vgui.CursorVisible() then
            DMS.OpenLookedAt()
        end
    end

    if wasDown and not down and DMS.Interface.patient == ply then DMS.Interface.Close() end
    wasDown = down
end)

hook.Add("HUDShouldDraw", "DMS.HideWhileDown", function(name)
    if name == "CHudDamageIndicator" and IsValid(LocalPlayer()) and isDown(LocalPlayer()) then return false end
end)
