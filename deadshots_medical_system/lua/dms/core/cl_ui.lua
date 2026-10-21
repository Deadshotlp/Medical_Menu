--[[
    DMS - Oberflaechen-Bausteine (eigenstaendig, kein Gamemode noetig).

    Schriften "DMS.<Groesse>" (auf 1080p bezogen) und einfache Bausteine im
    einheitlichen Stil: Fenster, Knoepfe, Beschriftungen, Eingaben, Auswahl,
    Haken, Listen, Bildlauf.
]]

DMS = DMS or {}
DMS.UI = DMS.UI or {}
local UI = DMS.UI

UI.COL = {
    bg = Color(14, 18, 24, 250), panel = Color(24, 30, 40), panel2 = Color(30, 37, 49), line = Color(46, 54, 68),
    accent = Color(220, 70, 70), ok = Color(90, 210, 130), warn = Color(240, 190, 70), bad = Color(240, 90, 80),
    info = Color(110, 170, 255), text = Color(225, 230, 240), dim = Color(140, 150, 165),
}
local COL = UI.COL

local function createFonts()
    for _, size in ipairs({11, 12, 14, 16, 18, 20, 22, 25, 30, 40, 60}) do
        surface.CreateFont("DMS." .. size, {font = "Roboto", size = math.max(10, math.Round(ScrH() * size / 1080)), weight = 500, extended = true})
    end
    surface.CreateFont("DMS.3D", {font = "Roboto", size = 64, weight = 600, extended = true})
    surface.CreateFont("DMS.3DSmall", {font = "Roboto", size = 40, weight = 500, extended = true})
end
createFonts()
hook.Add("OnScreenSizeChanged", "DMS.Fonts", createFonts)

function UI.W(x) return ScrW() * x / 1920 end
function UI.H(y) return ScrH() * y / 1080 end

function UI.Frame(title, w, h)
    local f = vgui.Create("DFrame")
    f:SetSize(w, h)
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f.Paint = function(_, pw, ph)
        draw.RoundedBox(0, 0, 0, pw, ph, COL.bg)
        surface.SetDrawColor(COL.accent)
        surface.DrawRect(0, 0, pw, 2)
        draw.SimpleText(title, "DMS.20", 12, 6, COL.text)
    end
    f:DockPadding(10, 36, 10, 10)
    return f
end

function UI.Button(parent, text, onClick, col)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.Label = text
    b.Col = col or COL.info
    b.DoClick = function(s)
        if s.Disabled then return end
        surface.PlaySound("buttons/button15.wav")
        onClick(s)
    end
    b.Paint = function(s, w, h)
        local c = s.Col
        local bg = s.Disabled and Color(28, 32, 40) or (s:IsHovered() and Color(c.r * 0.3, c.g * 0.3, c.b * 0.3) or COL.panel2)
        draw.RoundedBox(0, 0, 0, w, h, bg)
        surface.SetDrawColor(s.Disabled and COL.line or c)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(s.Label, s.Font or "DMS.16", w / 2, h / 2, s.Disabled and COL.dim or COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return b
end

function UI.Label(parent, text, font, col)
    local l = vgui.Create("DLabel", parent)
    l:SetFont(font or "DMS.14")
    l:SetTextColor(col or COL.text)
    l:SetText(text or "")
    return l
end

-- Mehrzeiliger Text oben angedockt
function UI.Info(parent, text, col, font)
    local l = UI.Label(parent, text, font or "DMS.14", col or COL.dim)
    l:Dock(TOP)
    l:DockMargin(0, 0, 0, 6)
    l:SetWrap(true)
    l:SetAutoStretchVertical(true)
    return l
end

function UI.Header(parent, text)
    local p = vgui.Create("DPanel", parent)
    p:Dock(TOP)
    p:DockMargin(0, 10, 0, 6)
    p:SetTall(26)
    p.Paint = function(_, w, h)
        surface.SetDrawColor(COL.accent)
        surface.DrawRect(0, h - 2, w, 2)
        draw.SimpleText(text, "DMS.18", 2, 2, COL.text)
    end
    return p
end

function UI.Entry(parent, value, placeholder)
    local e = vgui.Create("DTextEntry", parent)
    e:SetFont("DMS.16")
    e:SetValue(value == nil and "" or tostring(value))
    if placeholder then e:SetPlaceholderText(placeholder) end
    return e
end

function UI.Combo(parent, entries, selected)
    local c = vgui.Create("DComboBox", parent)
    c:SetFont("DMS.14")
    c:SetSortItems(false)
    for _, e in ipairs(entries) do c:AddChoice(e[2], e[1], e[1] == selected) end
    return c
end

function UI.ComboValue(c)
    local _, data = c:GetSelected()
    return data
end

function UI.Check(parent, text, value)
    local c = vgui.Create("DCheckBoxLabel", parent)
    c:SetText(text)
    c:SetFont("DMS.14")
    c:SetTextColor(COL.text)
    c:SetValue(value and true or false)
    return c
end

-- Zeile: Beschriftung links (feste Breite), Feld rechts
function UI.FormRow(parent, label, height, labelWidth)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 4)
    row:SetTall(height or 28)
    row.Paint = nil
    local l = UI.Label(row, label, "DMS.14", COL.dim)
    l:Dock(LEFT)
    l:SetWide(labelWidth or 220)
    return row
end

function UI.ButtonRow(parent, defs, height)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:DockMargin(0, 4, 0, 4)
    row:SetTall(height or 30)
    row.Paint = nil
    local buttons = {}
    for i, d in ipairs(defs) do buttons[i] = UI.Button(row, d[1], d[2], d[3]) end
    row.PerformLayout = function(_, w, h)
        local bw = (w - (#buttons - 1) * 6) / #buttons
        for i, b in ipairs(buttons) do
            b:SetPos((i - 1) * (bw + 6), 0)
            b:SetSize(bw, h)
        end
    end
    return buttons, row
end

function UI.Scroll(parent)
    local s = vgui.Create("DScrollPanel", parent)
    s:Dock(FILL)
    local bar = s:GetVBar()
    bar:SetWide(8)
    bar.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.panel) end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.line) end
    return s
end

function UI.List(parent, columns)
    local l = vgui.Create("DListView", parent)
    l:SetMultiSelect(false)
    l:SetDataHeight(22)
    for _, c in ipairs(columns) do
        local col = l:AddColumn(c[1])
        if c[2] then col:SetFixedWidth(c[2]) end
    end
    l.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.panel) end
    for _, col in ipairs(l.Columns) do
        col.Header:SetFont("DMS.14")
        col.Header:SetTextColor(COL.text)
        col.Header.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.panel2) end
    end
    local add = l.AddLine
    l.AddLine = function(s, ...)
        local line = add(s, ...)
        for _, col in pairs(line.Columns) do
            col:SetFont("DMS.14")
            col:SetTextColor(COL.text)
        end
        line.Paint = function(ln, w, h)
            if ln:IsSelected() then
                draw.RoundedBox(0, 0, 0, w, h, Color(COL.accent.r, COL.accent.g, COL.accent.b, 60))
            elseif ln:IsHovered() then
                draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255, 10))
            end
        end
        return line
    end
    return l
end

-- Kasten mit Hintergrund
function UI.Box(parent)
    local p = vgui.Create("DPanel", parent)
    p.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.panel) end
    return p
end
