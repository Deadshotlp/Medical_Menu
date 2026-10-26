--[[
    DMS - Konfigurationsmenue (Client). Symbol im Kontextmenue (C), nur fuer
    Superadmins; Konsole: dms_config.

    Seiten: Einstellungen je Gruppe, Sprache, Verletzungen, Aktionen
    (Diagnose, Medikation, Behandlung, Sonstiges), eigene Inhalte (neue
    Verletzungen, Diagnosen, Medikamente, Behandlungen; data/sh_custom.lua)
    und Patienten (Admin: heilen, wiederbeleben). Jede Aenderung geht sofort
    an den Server.
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
            -- Nur mit DarkRP waehlbar
            if key == "darkrp_medic" and not DMS.HasDarkRP() then
                c:SetText(L("DarkRP ist nicht geladen"))
                c:SetTextColor(COL.dim)
                c:SetMouseInputEnabled(false)
                if IsValid(c.Button) then c.Button:SetEnabled(false) c.Button:SetMouseInputEnabled(false) end
                if IsValid(c.Label) then c.Label:SetMouseInputEnabled(false) end
            end
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

--------------------------------------------------------------------------------
-- Felder (auch fuer eigene Inhalte)
--------------------------------------------------------------------------------

-- Alle Behandlungen als Auswahl {id, Name}
local function treatmentChoices()
    local out = {}
    for _, a in ipairs(DMS.Treatments) do out[#out + 1] = {a.id, L(a.name) .. "  (" .. a.id .. ")"} end
    return out
end

local function mapToText(m)
    local parts = {}
    for k, v in SortedPairs(m or {}) do parts[#parts + 1] = k .. " = " .. v end
    return table.concat(parts, ", ")
end

local function textToMap(s)
    local out = {}
    for _, part in ipairs(string.Explode(",", s or "")) do
        local k, v = string.match(part, "^%s*([%w_]+)%s*=%s*([%w_]+)%s*$")
        if k then out[k] = v end
    end
    return out
end

-- Ein Eingabefeld je Art; liefert eine Funktion, die den Wert ausliest
local function fieldWidget(scroll, label, art, value, choices, default)
    if art == "multi" or art == "list" then
        UI.Header(scroll, label)
        local set = {}
        for _, k in ipairs(value or {}) do set[k] = true end
        local checks = {}
        for _, c in ipairs(art == "list" and treatmentChoices() or choices) do
            local ch = UI.Check(scroll, L(c[2]), set[c[1]] == true)
            ch:Dock(TOP)
            ch:DockMargin(0, 0, 0, 2)
            checks[#checks + 1] = {c[1], ch}
        end
        return function()
            local out = {}
            for _, c in ipairs(checks) do if c[2]:GetChecked() then out[#out + 1] = c[1] end end
            return out
        end
    end

    local row = UI.FormRow(scroll, label, 30, 260)
    if art == "bool" then
        local c = UI.Check(row, default ~= nil and string.format(L("Standard: %s"), default and L("Ja") or L("Nein")) or "", value)
        c:Dock(FILL)
        return function() return c:GetChecked() end
    elseif art == "choice" then
        local entries = {}
        for _, c in ipairs(choices) do entries[#entries + 1] = {c[1], L(c[2])} end
        local c = UI.Combo(row, entries, value)
        c:Dock(LEFT)
        c:SetWide(280)
        return function() return UI.ComboValue(c) end
    elseif art == "map" then
        local e = UI.Entry(row, mapToText(value), "operativer_eingriff = fracture_simple")
        e:Dock(FILL)
        return function() return textToMap(e:GetValue()) end
    end
    local e = UI.Entry(row, value == nil and "" or value, default ~= nil and tostring(default) or nil)
    e:Dock(LEFT)
    e:SetWide(art == "string" and 280 or 120)
    if default ~= nil and art == "number" then
        local u = UI.Label(row, string.format(L("Standard: %s"), tostring(default)), "DMS.12", COL.dim)
        u:Dock(FILL)
        u:DockMargin(8, 0, 0, 0)
    end
    if art == "number" then return function() return tonumber(e:GetValue()) end end
    return function() return e:GetValue() end
end

-- Hilfe zu Umwandlungen: welche Verletzungs-IDs es gibt
local function transformHelp(scroll)
    local ids = {}
    for _, inj in ipairs(DMS.Injuries) do ids[#ids + 1] = inj.id end
    table.sort(ids)
    UI.Info(scroll, L("Umwandlung: Behandlung = Ziel, mehrere mit Komma. Ziel ist eine Verletzungs-ID oder remove (entfernt die Verletzung). Die Behandlung muss in der Liste der Verletzung stehen.")
        .. "\n" .. L("Verletzungs-IDs: ") .. table.concat(ids, ", "), COL.dim, "DMS.12")
end

local function same(a, b)
    if istable(a) or istable(b) then return util.TableToJSON(a or {}) == util.TableToJSON(b or {}) end
    return a == b
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
            local def = item.defaults[key]
            if fkind == "list" or fkind == "map" then
                if fkind == "map" then transformHelp(scroll) end
                controls[key] = fieldWidget(scroll, L(f[3]), fkind, item[key])
            elseif fkind == "bool" then
                controls[key] = fieldWidget(scroll, L(f[3]), "bool", item[key], nil, def)
            else
                controls[key] = fieldWidget(scroll, L(f[3]), "number", over[key], nil, def)
            end
        end

        UI.ButtonRow(scroll, {
            {L("Speichern"), function()
                local data = {}
                if dis:GetChecked() ~= item.defaults.disabled then data.disabled = dis:GetChecked() end
                for key, get in pairs(controls) do
                    local v = get()
                    if v ~= nil and not same(v, item.defaults[key]) then data[key] = v end
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

--------------------------------------------------------------------------------
-- Eigene Inhalte
--------------------------------------------------------------------------------

local function setCustom(kind, id, data)
    send("DMS.CfgCustom", function()
        net.WriteString(kind)
        net.WriteString(id)
        net.WriteString(data and util.TableToJSON(data) or "")
    end)
end

CFG.customKind = CFG.customKind or "injuries"

local function customPage(parent)
    local tabs = vgui.Create("DPanel", parent)
    tabs:Dock(TOP)
    tabs:SetTall(30)
    tabs:DockMargin(0, 0, 0, 8)
    tabs.Paint = nil
    local buttons = {}
    for i, k in ipairs(DMS.CustomKinds) do
        local b = UI.Button(tabs, L(k.name), function()
            CFG.customKind = k.key
            parent:Clear()
            parent.PerformLayout = nil
            customPage(parent)
        end)
        b.Think = function(s) s.Col = CFG.customKind == k.key and COL.accent or COL.info end
        buttons[i] = b
    end
    tabs.PerformLayout = function(_, w, h)
        local bw = (w - (#buttons - 1) * 4) / #buttons
        for i, b in ipairs(buttons) do b:SetPos((i - 1) * (bw + 4), 0) b:SetSize(bw, h) end
    end

    local kind = CFG.customKind
    local schema = DMS.CustomSchema[kind]

    local left = vgui.Create("DPanel", parent)
    left:Dock(LEFT)
    left:SetWide(parent:GetWide() * 0.35)
    left.Paint = nil
    local lst = UI.List(left, {{L("Name")}, {L("ID"), 150}})
    lst:Dock(FILL)

    local edit = vgui.Create("DPanel", parent)
    edit:Dock(FILL)
    edit:DockMargin(10, 0, 0, 0)
    edit.Paint = nil
    parent.PerformLayout = function(_, w) left:SetWide(w * 0.35) end

    -- Seite neu aufbauen, sobald der Server gespeichert hat
    local function reloadSoon()
        timer.Simple(0.6, function()
            if IsValid(parent) then parent:Clear() parent.PerformLayout = nil customPage(parent) end
        end)
    end

    local function show(id, data)
        edit:Clear()
        local scroll = UI.Scroll(edit)
        local isNew = id == nil
        UI.Header(scroll, isNew and L("Neuer Eintrag") or (data.name or id))

        local idEntry
        if isNew then
            local row = UI.FormRow(scroll, L("ID (Kleinbuchstaben, Ziffern, _)"), 30, 260)
            idEntry = UI.Entry(row, "", L("leer = aus dem Namen"))
            idEntry:Dock(LEFT)
            idEntry:SetWide(280)
        else
            UI.Info(scroll, "ID: " .. id, COL.dim, "DMS.12")
        end

        local controls = {}
        for _, f in ipairs(schema) do
            if f[2] == "map" then transformHelp(scroll) end
            local value = data[f[1]]
            if value == nil then value = f[4] end
            controls[f[1]] = fieldWidget(scroll, L(f[3]), f[2], value, f[5])
        end

        local function collect()
            local out = {}
            for key, get in pairs(controls) do out[key] = get() end
            return out
        end

        local defs = {{L("Speichern"), function()
            local d = collect()
            local newId = id or DMS.CustomId((idEntry and idEntry:GetValue() ~= "") and idEntry:GetValue() or d.name)
            if newId == "" then
                notification.AddLegacy(L("Bitte eine ID oder einen Namen angeben."), NOTIFY_ERROR, 3)
                return
            end
            setCustom(kind, newId, d)
            reloadSoon()
        end, COL.ok}}
        if not isNew then
            defs[#defs + 1] = {L("Löschen"), function()
                Derma_Query(string.format(L("%s wirklich löschen?"), id), L("Löschen"), L("Ja"), function()
                    setCustom(kind, id, nil)
                    reloadSoon()
                end, L("Nein"))
            end, COL.bad}
        end
        UI.ButtonRow(scroll, defs, 32)
    end

    for id, d in SortedPairs(((DMS.Config.Custom or {})[kind]) or {}) do
        local line = lst:AddLine(L(d.name or id), id)
        line.customId, line.customData = id, d
    end
    lst.OnRowSelected = function(_, _, line) show(line.customId, line.customData) end

    local _, row = UI.ButtonRow(left, {{L("Neu"), function() show(nil, {}) end, COL.ok}}, 32)
    row:Dock(BOTTOM)

    UI.Info(edit, L("Hier lassen sich eigene Einträge anlegen. Sie verhalten sich wie die mitgelieferten und lassen sich danach auch auf den übrigen Seiten anpassen."))
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
    out[#out + 1] = {"Eigene Inhalte", customPage}
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
