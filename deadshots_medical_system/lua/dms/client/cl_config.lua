--[[
    DMS - Konfigurationsmenue (Client). Symbol im Kontextmenue (C), nur fuer
    Superadmins; Konsole: dms_config.

    Seiten: Einstellungen je Gruppe, Sprache, Verletzungen, Aktionen
    (Diagnose, Medikation, Behandlung, Sonstiges) und Patienten (Admin:
    heilen, wiederbeleben). Jede Aenderung geht sofort an den Server.
]]

DMS = DMS or {}

local UI = DMS.UI
local COL = UI.COL
local L = DMS.L

local CFG = {}
DMS.ConfigMenu = CFG

local function send(name, fn)
    net.Start(name)
    fn()
    net.SendToServer()
end

local function setSetting(key, value)
    send("DMS.CfgSet", function()
        net.WriteString(key)
        net.WriteString(util.TableToJSON({v = value}))
    end)
end

local function setOverride(kind, id, data)
    send("DMS.CfgOverride", function()
        net.WriteString(kind)
        net.WriteString(id)
        net.WriteString(data and util.TableToJSON(data) or "")
    end)
end

--------------------------------------------------------------------------------
-- Seiten
--------------------------------------------------------------------------------

local function settingsPage(parent, group)
    local scroll = UI.Scroll(parent)
    for _, d in ipairs(DMS.SettingDefs) do
        if d[4] ~= group then continue end
        local key, kind = d[1], d[3]
        local row = UI.FormRow(scroll, L(d[5]), 30, 340)
        local value = DMS.Get(key)
        if kind == "bool" then
            local c = UI.Check(row, d[6] ~= "" and L(d[6]) or "", value)
            c:Dock(FILL)
            c.OnChange = function(_, v) setSetting(key, v) end
        elseif kind == "choice" then
            local entries = {}
            for _, o in ipairs(d[7]) do entries[#entries + 1] = {o[1], L(o[2])} end
            local c = UI.Combo(row, entries, value)
            c:Dock(LEFT)
            c:SetWide(260)
            c.OnSelect = function(_, _, _, v) setSetting(key, v) end
        else
            local e = UI.Entry(row, value)
            e:Dock(LEFT)
            e:SetWide(kind == "number" and 120 or 260)
            if kind == "number" then e:SetNumeric(true) end
            local function commit()
                local v = e:GetValue()
                if kind == "number" then v = tonumber(v) if not v then return end end
                if v ~= DMS.Get(key) then setSetting(key, v) end
            end
            e.OnEnter = commit
            e.OnLoseFocus = function(s) commit() DTextEntry.OnLoseFocus(s) end
            if d[6] and d[6] ~= "" then
                local u = UI.Label(row, L(d[6]), "DMS.12", COL.dim)
                u:Dock(FILL)
                u:DockMargin(8, 0, 0, 0)
            end
        end
    end
end

local function languagePage(parent)
    local scroll = UI.Scroll(parent)
    UI.Info(scroll, L("Sprache aller Texte des Addons (für alle Spieler)."))
    local row = UI.FormRow(scroll, L("Sprache"), 30, 200)
    local entries = {}
    for _, l in ipairs(DMS.Languages) do entries[#entries + 1] = {l.id, l.name} end
    local c = UI.Combo(row, entries, GetConVar("dms_language"):GetString())
    c:Dock(LEFT)
    c:SetWide(200)
    c.OnSelect = function(_, _, _, v)
        send("DMS.CfgLang", function() net.WriteString(v) end)
        timer.Simple(0.5, function() if IsValid(CFG.frame) then CFG.Open(CFG.page) end end)
    end

    UI.Header(scroll, L("Zurücksetzen"))
    UI.Info(scroll, L("Setzt alle Einstellungen, Verletzungen und Aktionen auf den Standard zurück."))
    UI.ButtonRow(scroll, {{L("Alles zurücksetzen"), function()
        Derma_Query(L("Wirklich alle Einstellungen zurücksetzen?"), L("Zurücksetzen"), L("Ja"), function()
            send("DMS.CfgReset", function() end)
            timer.Simple(0.5, function() if IsValid(CFG.frame) then CFG.Open(CFG.page) end end)
        end, L("Nein"))
    end, COL.bad}})
end

-- Liste links, Felder rechts (Verletzungen und Aktionen)
local function overridePage(parent, kind, items, fieldsFor)
    local lst = UI.List(parent, {{L("Name")}, {L("Aus"), 40}})
    lst:Dock(LEFT)
    lst:SetWide(parent:GetWide() * 0.45)
    parent.PerformLayout = function(_, w) lst:SetWide(w * 0.45) end

    local edit = vgui.Create("DPanel", parent)
    edit:Dock(FILL)
    edit:DockMargin(10, 0, 0, 0)
    edit.Paint = nil

    local function show(item)
        edit:Clear()
        local scroll = UI.Scroll(edit)
        UI.Header(scroll, L(item.name))
        UI.Info(scroll, "ID: " .. item.id, COL.dim, "DMS.12")
        local over = table.Copy(((DMS.Config.Overrides or {})[kind] or {})[item.id] or {})
        local controls = {}

        local dis = UI.Check(scroll, L("Deaktiviert"), item.disabled)
        dis:Dock(TOP)
        dis:DockMargin(0, 0, 0, 8)
        for _, f in ipairs(fieldsFor(item)) do
            local key, fkind = f[1], f[2]
            local row = UI.FormRow(scroll, L(f[3]), 30, 230)
            local def = item.defaults[key]
            if fkind == "bool" then
                local c = UI.Check(row, string.format(L("Standard: %s"), def and L("Ja") or L("Nein")), item[key])
                c:Dock(FILL)
                controls[key] = function() return c:GetChecked() end
            else
                local e = UI.Entry(row, over[key] ~= nil and over[key] or "", tostring(def))
                e:Dock(LEFT)
                e:SetWide(120)
                local u = UI.Label(row, string.format(L("Standard: %s"), tostring(def)), "DMS.12", COL.dim)
                u:Dock(FILL)
                u:DockMargin(8, 0, 0, 0)
                controls[key] = function() return tonumber(e:GetValue()) end
            end
        end

        UI.ButtonRow(scroll, {
            {L("Speichern"), function()
                local data = {}
                if dis:GetChecked() ~= item.defaults.disabled then data.disabled = dis:GetChecked() end
                for key, get in pairs(controls) do
                    local v = get()
                    if v ~= nil and v ~= item.defaults[key] then data[key] = v end
                end
                setOverride(kind, item.id, next(data) and data or nil)
                notification.AddLegacy(L("Gespeichert."), NOTIFY_GENERIC, 2)
            end, COL.ok},
            {L("Standard"), function()
                setOverride(kind, item.id, nil)
                timer.Simple(0.5, function() if IsValid(edit) then show(item) end end)
            end, COL.warn},
        }, 32)
    end

    for _, item in ipairs(items) do
        local line = lst:AddLine(L(item.name), item.disabled and "X" or "")
        line.item = item
    end
    lst.OnRowSelected = function(_, _, line) show(line.item) end
end

local function injuriesFields() return DMS.InjuryFields end
local function actionFields(item)
    if item.category ~= "medication" then return DMS.ActionFields end
    local out = table.Copy(DMS.ActionFields)
    for _, f in ipairs(DMS.MedicationFields) do out[#out + 1] = f end
    return out
end

local function actionsPage(parent, items)
    overridePage(parent, "actions", items, actionFields)
end

local function patientsPage(parent)
    local lst = UI.List(parent, {{L("Name")}, {L("Zustand"), 120}, {L("Puls"), 60}, {L("SpO2"), 60}, {L("Blut (l)"), 70},
        {L("Verletzungen"), 90}, {L("Medic"), 60}})
    lst:Dock(FILL)
    local buttons = UI.ButtonRow(parent, {
        {L("Heilen"), function() CFG.Admin(lst, "heal") end, COL.ok},
        {L("Wiederbeleben"), function() CFG.Admin(lst, "revive") end, COL.info},
        {L("Aktualisieren"), function() send("DMS.CfgPatients", function() end) end, COL.dim},
    }, 32)
    buttons[1]:GetParent():Dock(BOTTOM)
    CFG.patientList = lst
    send("DMS.CfgPatients", function() end)
end

function CFG.Admin(lst, what)
    local line = lst:GetSelectedLine() and lst:GetLine(lst:GetSelectedLine())
    local ent = line and Entity(line.entIndex)
    if not IsValid(ent) then return end
    send("DMS.CfgAdmin", function()
        net.WriteString(what)
        net.WriteEntity(ent)
    end)
end

net.Receive("DMS.CfgPatients", function()
    local lst = CFG.patientList
    if not IsValid(lst) then return end
    local data = util.JSONToTable(net.ReadString()) or {}
    lst:Clear()
    for _, p in ipairs(data) do
        local state = p.down and L("Bewusstlos") or (p.alive and L("Bei Bewusstsein") or L("Tot"))
        local line = lst:AddLine(p.name, state, p.puls, p.spo2, p.blood, p.injuries, p.medic and L("Ja") or L("Nein"))
        line.entIndex = p.ent
    end
end)

--------------------------------------------------------------------------------
-- Fenster
--------------------------------------------------------------------------------

local function pages()
    local out = {}
    for _, g in ipairs(DMS.SettingGroups) do
        out[#out + 1] = {g[2], function(p) settingsPage(p, g[1]) end}
    end
    out[#out + 1] = {"Sprache", languagePage}
    out[#out + 1] = {"Verletzungen", function(p) overridePage(p, "injuries", DMS.Injuries, injuriesFields) end}
    for _, cat in ipairs(DMS.ActionCategories) do
        out[#out + 1] = {cat.name, function(p) actionsPage(p, cat.list) end}
    end
    out[#out + 1] = {"Patienten", patientsPage}
    return out
end

function CFG.Open(page)
    if not LocalPlayer():IsSuperAdmin() then
        notification.AddLegacy(L("Nur für Superadmins."), NOTIFY_ERROR, 3)
        return
    end
    if IsValid(CFG.frame) then CFG.frame:Remove() end
    local f = UI.Frame(L("Deadshot's Medical System - Konfiguration"), math.min(ScrW() - 80, 1200), math.min(ScrH() - 80, 760))
    CFG.frame = f

    local nav = vgui.Create("DPanel", f)
    nav:Dock(LEFT)
    nav:SetWide(210)
    nav.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.panel) end
    nav:DockPadding(6, 6, 6, 6)

    local content = vgui.Create("DPanel", f)
    content:Dock(FILL)
    content:DockMargin(10, 0, 0, 0)
    content:DockPadding(10, 10, 10, 10)
    content.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.panel) end

    local all = pages()
    local function choose(i)
        CFG.page = i
        content:Clear()
        content.PerformLayout = nil
        all[i][2](content)
    end
    for i, pg in ipairs(all) do
        local b = UI.Button(nav, L(pg[1]), function() choose(i) end)
        b:Dock(TOP)
        b:DockMargin(0, 0, 0, 4)
        b:SetTall(32)
        b.Think = function(s) s.Col = CFG.page == i and COL.accent or COL.info end
    end
    choose(math.Clamp(page or 1, 1, #all))
end

concommand.Add("dms_config", function() CFG.Open() end)

list.Set("DesktopWindows", "DMSConfig", {
    title = "Medical System",
    icon = "icon64/tool.png",
    width = 10,
    height = 10,
    onewindow = true,
    init = function(_, window)
        window:Remove()
        CFG.Open()
    end,
})
