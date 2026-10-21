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
        draw.SimpleText(L("F3: eigenen Zustand ansehen"), "DMS.18", w / 2, h * 0.54, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

-- Den eigenen Zustand ansehen (auch bewusstlos)
-- und beim Aufwachen das eigene Fenster schliessen
local wasDown, keyWas = false, false
hook.Add("Think", "DMS.SelfKey", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local down = isDown(ply)
    local key = input.IsKeyDown(KEY_F3) and not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible()
    if key and not keyWas and down and not IsValid(DMS.Interface.frame) then DMS.OpenPatient(ply) end
    keyWas = key
    if wasDown and not down and DMS.Interface.patient == ply then DMS.Interface.Close() end
    wasDown = down
end)

hook.Add("HUDShouldDraw", "DMS.HideWhileDown", function(name)
    if name == "CHudDamageIndicator" and IsValid(LocalPlayer()) and isDown(LocalPlayer()) then return false end
end)
