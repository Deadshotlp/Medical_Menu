--[[
    DMS - Behandlungsfenster (Client).

    Links Aktionen (Diagnose, Medikation, Behandlung, Sonstiges) fuer den
    gewaehlten Koerperteil, in der Mitte Triage-Karte und Koerperbild
    (anklicken waehlt den Koerperteil; farbig: verletzt, Bruch, Tourniquet),
    rechts Uebersicht und Vitalwerte, unten Aktivitaetsprotokoll und
    Schnellinfo. Aktionen laufen mit Fortschrittsbalken; die Dauer prueft der
    Server.

    Aktualisiert wird je Bereich nur, was sich geaendert hat (Kennungen in
    IF.Refresh; Uebersicht tauscht nur Texte) - sonst flackerte das Fenster
    bei jeder Berechnung.
]]

DMS = DMS or {}
DMS.Interface = DMS.Interface or {}
local IF = DMS.Interface
local UI = DMS.UI
local COL = UI.COL
local L = DMS.L

local TRIAGE = {
    [0] = {"Keine Priorität", Color(220, 220, 220)},
    [1] = {"Niedrige Priorität", Color(60, 180, 80)},
    [2] = {"Mittlere Priorität", Color(255, 150, 40)},
    [3] = {"Hohe Priorität", Color(235, 60, 50)},
    [4] = {"Verstorben", Color(120, 120, 120)},
}

-- Klickflaechen auf dem Koerperbild (Anteile des 512x512-Bildes), in Pruefreihenfolge
local REGIONS = {
    {1, 231, 30, 281, 104},
    {4, 286, 101, 344, 286},
    {5, 167, 100, 229, 286},
    {2, 216, 99, 295, 255},
    {6, 258, 224, 311, 481},
    {7, 199, 223, 252, 480},
}

local mats = {}
local function mat(name)
    if mats[name] == nil then
        local m = Material("dms/body/" .. name .. ".png", "smooth")
        mats[name] = (m and not m:IsError()) and m or false
    end
    return mats[name] or nil
end

IF.part = IF.part or 0
IF.tab = IF.tab or "diagnostics"

--------------------------------------------------------------------------------
-- Netz
--------------------------------------------------------------------------------

function DMS.OpenPatient(ent)
    IF.requested = CurTime()
    net.Start("DMS.Open")
    net.WriteEntity(ent)
    net.SendToServer()
end

net.Receive("DMS.Data", function()
    local patient = net.ReadEntity()
    local size = net.ReadUInt(32)
    local data = util.JSONToTable(util.Decompress(net.ReadData(size)) or "")
    if not IsValid(patient) or not data then return end

    if IF.patient ~= patient or not IsValid(IF.frame) then
        -- Nachzuegler nach dem Schliessen oeffnen kein neues Fenster
        if CurTime() - (IF.requested or -10) > 3 then return end
        IF.requested = nil
        IF.patient = patient
        IF.part = 0
        IF.data = data
        IF.Open()
    else
        IF.data = data
        IF.Refresh()
    end
end)

net.Receive("DMS.ActionStarted", function()
    local id, time = net.ReadString(), net.ReadFloat()
    local action = DMS.ActionsById[id]
    if not action then return end
    IF.running = {id = id, name = L(action.name), start = CurTime(), time = time, part = IF.part, patient = IF.patient}
    if time <= 0 then IF.FinishAction() end
end)

function IF.FinishAction()
    local r = IF.running
    IF.running = nil
    if not r or not IsValid(r.patient) then return end
    net.Start("DMS.Action")
    net.WriteString("finish")
    net.WriteEntity(r.patient)
    net.WriteString(r.id)
    net.WriteUInt(r.part, 4)
    net.SendToServer()
end

function IF.CancelAction()
    if not IF.running then return end
    IF.running = nil
    net.Start("DMS.Action")
    net.WriteString("cancel")
    net.SendToServer()
end

hook.Add("Think", "DMS.ActionProgress", function()
    local r = IF.running
    if r and CurTime() >= r.start + r.time then IF.FinishAction() end
end)

--------------------------------------------------------------------------------
-- Inhalt
--------------------------------------------------------------------------------

local function partInjuries(data, part)
    local out = {}
    for _, inj in ipairs(data.injuries or {}) do
        if DMS.PartMatches(part, inj.wo) then out[#out + 1] = inj end
    end
    return out
end

-- Moegliche Aktionen im gewaehlten Tab (fuer Anzeige und Kennung)
local function availableActions()
    local data, patient = IF.data, IF.patient
    local cat
    for _, c in ipairs(DMS.ActionCategories) do if c.key == IF.tab then cat = c end end
    local out = {}
    if IF.part == 0 then return out end
    for _, action in ipairs(cat and cat.list or {}) do
        if DMS.CanDoAction(LocalPlayer(), action, data, IF.part, patient) then out[#out + 1] = action end
    end
    return out
end

local function buildActions(panel, actions)
    panel:Clear()
    local patient = IF.patient

    local tabs = vgui.Create("DPanel", panel)
    tabs:Dock(TOP)
    tabs:SetTall(30)
    tabs.Paint = nil
    local buttons = {}
    for i, cat in ipairs(DMS.ActionCategories) do
        local b = UI.Button(tabs, L(cat.name), function() IF.tab = cat.key IF.Refresh(true) end)
        b.Font = "DMS.14"
        b.Think = function(s) s.Col = IF.tab == cat.key and COL.accent or COL.info end
        buttons[i] = b
    end
    tabs.PerformLayout = function(_, w, h)
        local bw = (w - (#buttons - 1) * 4) / #buttons
        for i, b in ipairs(buttons) do b:SetPos((i - 1) * (bw + 4), 0) b:SetSize(bw, h) end
    end

    local scroll = UI.Scroll(panel)
    scroll:DockMargin(0, 8, 0, 0)

    if IF.part == 0 then
        UI.Info(scroll, L("Wählen Sie einen Körperteil aus, um fortzufahren."), COL.dim, "DMS.16")
        return
    end

    for _, action in ipairs(actions) do
        local b = UI.Button(scroll, L(action.name) .. "  (" .. (action.time or 0) .. " s)", function()
            if IF.running then return end
            net.Start("DMS.Action")
            net.WriteString("start")
            net.WriteEntity(patient)
            net.WriteString(action.id)
            net.WriteUInt(IF.part, 4)
            net.SendToServer()
        end, action.medic and COL.accent or COL.info)
        b:Dock(TOP)
        b:DockMargin(0, 0, 0, 4)
        b:SetTall(34)
    end
    if #actions == 0 then UI.Info(scroll, L("Hier ist gerade nichts möglich."), COL.dim, "DMS.16") end
    if not DMS.IsMedic(LocalPlayer()) then
        UI.Info(scroll, L("Weitere Aktionen können nur Medics ausführen."), COL.dim, "DMS.12")
    end
end

-- Zustand je Koerperteil fuer das Koerperbild (aus den aktuellen Daten)
local function partStates(data)
    local injured, fractured, tourniquet = {}, {}, {}
    for _, inj in ipairs(data.injuries or {}) do injured[inj.wo == 3 and 2 or inj.wo] = true end
    for i, bp in ipairs(data.body_part or {}) do
        if bp.fractured then fractured[i] = true end
        if bp.tourniquet then tourniquet[i] = true end
    end
    return injured, fractured, tourniquet
end

local function buildBody(panel)
    panel:Clear()
    local data = IF.data

    -- Triage
    local card = TRIAGE[data.triage_card or 0] or TRIAGE[0]
    if DMS.IsMedic(LocalPlayer()) then
        local entries = {}
        for i = 0, 4 do entries[#entries + 1] = {i, L(TRIAGE[i][1])} end
        local c = UI.Combo(panel, entries, data.triage_card or 0)
        c:Dock(TOP)
        c:SetTall(28)
        c:SetTextColor(card[2])
        c.OnSelect = function(_, _, _, v)
            net.Start("DMS.Triage")
            net.WriteEntity(IF.patient)
            net.WriteUInt(v, 3)
            net.SendToServer()
        end
    else
        local l = UI.Label(panel, L("Triage: ") .. L(card[1]), "DMS.20", card[2])
        l:Dock(TOP)
        l:SetTall(28)
        l:SetContentAlignment(5)
    end

    local body = vgui.Create("DPanel", panel)
    body:Dock(FILL)
    body:DockMargin(0, 6, 0, 0)
    body.Paint = function(s, w, h)
        -- Zustand bei jedem Zeichnen aus den neuesten Daten: kein Neuaufbau noetig
        local injured, fractured, tourniquet = partStates(IF.data or {})
        local size = math.min(w, h)
        local x, y = (w - size) / 2, (h - size) / 2
        s.box = {x, y, size}
        local function drawPart(name, col)
            local m = mat(name)
            if not m then return end
            surface.SetMaterial(m)
            surface.SetDrawColor(col or color_white)
            surface.DrawTexturedRect(x, y, size, size)
        end
        drawPart("background")
        for i, def in ipairs(DMS.BodyParts) do
            if def.mergeInto then continue end
            if IF.part == i then drawPart(def.image .. "_s") end
            if injured[i] then drawPart(def.image, Color(255, 125, 0)) end
            if fractured[i] then
                if mat(def.image .. "_b") then drawPart(def.image .. "_b", Color(255, 0, 0)) else drawPart(def.image, Color(255, 40, 40, 180)) end
            end
            if tourniquet[i] then drawPart(def.image .. "_t", Color(60, 120, 255)) end
        end
        draw.SimpleText("R", "DMS.40", x + size * 0.12, y + size * 0.1, Color(255, 255, 255, 90))
        draw.SimpleText("L", "DMS.40", x + size * 0.88, y + size * 0.1, Color(255, 255, 255, 90), TEXT_ALIGN_RIGHT)
        -- Hover
        local hx, hy = s:CursorPos()
        local hover = s.PartAt and s:PartAt(hx, hy)
        if hover then
            draw.SimpleText(L(DMS.BodyParts[hover].name), "DMS.16", hx + 14, hy, COL.text)
        end
    end
    body.PartAt = function(s, mx, my)
        if not s.box then return nil end
        local x, y, size = unpack(s.box)
        local px, py = (mx - x) / size * 512, (my - y) / size * 512
        for _, r in ipairs(REGIONS) do
            if px >= r[2] and px <= r[4] and py >= r[3] and py <= r[5] then return r[1] end
        end
        return nil
    end
    body.OnMousePressed = function(s)
        local part = s:PartAt(s:CursorPos())
        if part then
            IF.part = part
            surface.PlaySound("buttons/lightswitch2.wav")
            IF.Refresh(true)
        end
    end
    body:SetCursor("hand")
end

-- Uebersicht als Zeilen {Text, Farbe, Schrift, Umbruch}
local function overviewLines(data)
    local out = {}
    local function line(text, col, font, wrap) out[#out + 1] = {text, col or COL.text, font or "DMS.16", wrap} end

    if data.vital_monitoring then
        line(L("Vitalwerte"), COL.dim, "DMS.14")
        line(string.format(L("Puls: %d bpm"), data.puls or 0), (data.puls or 0) < 50 and COL.bad or COL.text)
        line(string.format(L("Blutdruck: %d/%d mmHg"), data.bp[1], data.bp[2]))
        line(string.format(L("Sauerstoffsättigung: %d %%"), data.spo2 or 0), (data.spo2 or 0) < 85 and COL.bad or COL.text)
        line(string.format(L("Atemfrequenz: %d/min"), data.respiratory_system.breathing_rate or 0))
        line("")
    end

    line(L("Gesamtzustand"), COL.dim, "DMS.14")
    if data.alive then
        line(L("Bei Bewusstsein"), COL.ok)
    else
        local left = data.down_left
        line(L("Bewusstlos") .. ((left and left > 0) and string.format(L(" (Respawn möglich in %d s)"), left) or ""), COL.bad)
    end

    local blood = data.blood_amount or 5.5
    if blood >= 5.4 then line(L("Kein Blutverlust"), COL.ok)
    elseif blood > 4.0 then line(L("Geringer Blutverlust"), COL.warn)
    elseif blood > 3.0 then line(L("Starker Blutverlust"), Color(255, 125, 0))
    else line(L("Tödlicher Blutverlust"), COL.bad) end

    local pain = data.pain_level or 0
    if not data.alive then line(L("Keine Reaktion auf Schmerz"), COL.bad)
    elseif pain <= 0.05 then line(L("Kein Schmerz"), COL.ok)
    elseif pain < 1.5 then line(L("Leichter Schmerz"), COL.warn)
    elseif pain < 3 then line(L("Mäßiger Schmerz"), Color(255, 125, 0))
    else line(L("Starker Schmerz"), COL.bad) end

    if not data.respiratory_system.airway_clear then line(L("Atemwege verlegt"), COL.bad) end
    if data.recovery_position then line(L("In stabiler Seitenlage"), COL.info) end
    if (data.stunning_level or 0) > 0.05 then line(L("Betäubt"), COL.warn) end
    if #(data.infections or {}) > 0 and data.vital_monitoring then
        line(string.format(L("Fieber (%d Infektion(en))"), #data.infections), COL.warn)
    end
    if #(data.medication or {}) > 0 then
        local names = {}
        for _, m in ipairs(data.medication) do names[#names + 1] = L(m.name) end
        line(L("Medikamente: ") .. table.concat(names, ", "), COL.info, "DMS.14", true)
    end

    line("")
    if IF.part == 0 then
        line(L("Kein Körperteil ausgewählt"), COL.dim)
        return out
    end

    local part = data.body_part[IF.part] or {}
    line(L(DMS.BodyParts[IF.part].name), COL.text, "DMS.20")
    local bleeding = (part.bleeding or 0) + (IF.part == 2 and (data.body_part[3] or {}).bleeding or 0)
    if bleeding > 0 then line(part.tourniquet and L("Blutung (abgebunden)") or L("Blutet"), part.tourniquet and COL.warn or COL.bad) end
    if part.fractured then line(L("Fraktur"), COL.bad) end
    if part.tourniquet then line(L("Tourniquet angelegt"), COL.info) end
    if part.has_iv then line(L("Zugang gelegt"), COL.info) end

    local injuries = partInjuries(data, IF.part)
    if #injuries == 0 then
        line(L("Keine Verletzungen"), COL.ok)
    else
        line(L("Verletzungen:"), COL.dim, "DMS.14")
        for _, inj in ipairs(injuries) do
            local rest = #(inj.treatment or {})
            line("• " .. L(inj.name) .. (rest > 0 and string.format(L("  (noch %d Behandlung(en))"), rest) or L("  (versorgt)")),
                rest == 0 and COL.ok or COL.text, "DMS.14", true)
        end
    end
    return out
end

-- Zeilen anzeigen: gleicher Aufbau -> nur Text und Farbe tauschen (kein
-- Neuaufbau, kein Flackern, Bildlauf bleibt), sonst neu anlegen
local function showLines(panel, specs)
    local labels = panel.dmsLabels
    local same = labels and #labels == #specs
    if same then
        for i, s in ipairs(specs) do
            if labels[i].dmsFont ~= s[3] or labels[i].dmsWrap ~= s[4] then same = false break end
        end
    end
    if same then
        for i, s in ipairs(specs) do
            local l = labels[i]
            if l:GetText() ~= s[1] then l:SetText(s[1]) end
            l:SetTextColor(s[2])
        end
        return
    end

    panel:Clear()
    local scroll = UI.Scroll(panel)
    labels = {}
    for i, s in ipairs(specs) do
        local l = UI.Label(scroll, s[1], s[3], s[2])
        l:Dock(TOP)
        l:SetTall(22)
        l.dmsFont, l.dmsWrap = s[3], s[4]
        if s[4] then
            l:SetWrap(true)
            l:SetAutoStretchVertical(true)
        end
        labels[i] = l
    end
    panel.dmsLabels = labels
end

local function buildLog(panel, title, entries)
    -- Nur bei neuen Eintraegen neu aufbauen
    local last = entries[#entries]
    local sig = #entries .. ":" .. (last and (tostring(last.time) .. tostring(last.str)) or "")
    if panel.dmsSig == sig then return end
    panel.dmsSig = sig

    panel:Clear()
    local head = UI.Label(panel, title, "DMS.16", COL.dim)
    head:Dock(TOP)
    head:SetTall(22)
    local scroll = UI.Scroll(panel)
    for i = #entries, math.max(1, #entries - 40), -1 do
        local e = entries[i]
        local l = UI.Label(scroll, DMS.FormatTime(e.time or 0) .. "  " .. tostring(e.str), "DMS.14", COL.text)
        l:Dock(TOP)
        l:SetWrap(true)
        l:SetAutoStretchVertical(true)
    end
end

--------------------------------------------------------------------------------
-- Fenster
--------------------------------------------------------------------------------

-- Aktualisieren: jeder Bereich nur, wenn sich sein Inhalt geaendert hat
-- (full = alles neu, z. B. anderer Koerperteil oder Tab)
function IF.Refresh(full)
    if not IsValid(IF.frame) or not IF.data then return end
    local data = IF.data
    local medic = DMS.IsMedic(LocalPlayer())

    local actions = availableActions()
    local ids = {}
    for i, a in ipairs(actions) do ids[i] = a.id end
    local actionSig = IF.tab .. ":" .. IF.part .. ":" .. tostring(medic) .. ":" .. table.concat(ids, ",")
    if full or IF.actionSig ~= actionSig then
        buildActions(IF.actions, actions)
        IF.actionSig = actionSig
    end

    local bodySig = tostring(data.triage_card or 0) .. ":" .. tostring(medic)
    if full or IF.bodySig ~= bodySig then
        buildBody(IF.body)
        IF.bodySig = bodySig
    end

    showLines(IF.overview, overviewLines(data))
    if full then IF.log.dmsSig, IF.quick.dmsSig = nil, nil end
    buildLog(IF.log, L("Aktivitätsprotokoll"), data.activity_log or {})
    buildLog(IF.quick, L("Schnellinfo"), data.quick_overview_log or {})
end

function IF.Close()
    if IsValid(IF.frame) then IF.frame:Remove() end
end

function IF.Open()
    if IsValid(IF.frame) then IF.frame:Remove() end
    local w, h = math.min(ScrW() - 80, 1500), math.min(ScrH() - 80, 900)
    local f = UI.Frame(L("Medizinische Schnittstelle") .. "  -  " .. tostring(IF.data.name or "?"), w, h)
    IF.frame = f
    f.OnRemove = function()
        IF.CancelAction()
        if IsValid(IF.patient) then
            net.Start("DMS.Close")
            net.WriteEntity(IF.patient)
            net.SendToServer()
        end
        IF.patient = nil
    end
    local baseThink = f.Think
    f.Think = function(s)
        baseThink(s)
        if not IsValid(IF.patient) or (IF.patient ~= LocalPlayer() and not LocalPlayer():Alive()) then s:Remove() end
    end

    local bottom = vgui.Create("DPanel", f)
    bottom:Dock(BOTTOM)
    bottom:SetTall(h * 0.24)
    bottom:DockMargin(0, 8, 0, 0)
    bottom.Paint = nil
    IF.log = UI.Box(bottom)
    IF.log:Dock(LEFT)
    IF.log:DockPadding(8, 6, 8, 6)
    IF.quick = UI.Box(bottom)
    IF.quick:Dock(FILL)
    IF.quick:DockMargin(8, 0, 0, 0)
    IF.quick:DockPadding(8, 6, 8, 6)
    bottom.PerformLayout = function(_, bw) IF.log:SetWide(bw / 2 - 4) end

    -- Laufende Aktion
    local progress = vgui.Create("DPanel", f)
    progress:Dock(BOTTOM)
    progress:SetTall(34)
    progress:DockMargin(0, 8, 0, 0)
    progress.Paint = function(_, pw, ph)
        draw.RoundedBox(0, 0, 0, pw, ph, COL.panel)
        local r = IF.running
        if not r then
            draw.SimpleText(L("Bereit"), "DMS.14", 10, ph / 2, COL.dim, nil, TEXT_ALIGN_CENTER)
            return
        end
        local frac = math.Clamp((CurTime() - r.start) / math.max(r.time, 0.01), 0, 1)
        draw.RoundedBox(0, 0, 0, pw * frac, ph, Color(COL.accent.r, COL.accent.g, COL.accent.b, 120))
        draw.SimpleText(string.format("%s  -  %s %.0f s", r.name, L("noch"), math.max(0, r.start + r.time - CurTime())), "DMS.16",
            10, ph / 2, COL.text, nil, TEXT_ALIGN_CENTER)
    end
    local cancel = UI.Button(progress, L("Abbrechen"), function() IF.CancelAction() end, COL.bad)
    cancel:Dock(RIGHT)
    cancel:SetWide(120)
    cancel.Think = function(s) s:SetVisible(IF.running ~= nil) end

    local main = vgui.Create("DPanel", f)
    main:Dock(FILL)
    main.Paint = nil
    IF.actions = UI.Box(main)
    IF.actions:Dock(LEFT)
    IF.actions:DockPadding(8, 8, 8, 8)
    IF.overview = UI.Box(main)
    IF.overview:Dock(RIGHT)
    IF.overview:DockPadding(8, 8, 8, 8)
    IF.body = UI.Box(main)
    IF.body:Dock(FILL)
    IF.body:DockMargin(8, 0, 8, 0)
    IF.body:DockPadding(8, 8, 8, 8)
    main.PerformLayout = function(_, mw)
        IF.actions:SetWide(mw * 0.3)
        IF.overview:SetWide(mw * 0.3)
    end

    IF.actionSig, IF.bodySig = nil, nil
    IF.Refresh(true)
end

hook.Add("OnPauseMenuShow", "DMS.CloseInterface", function()
    if IsValid(IF.frame) then
        IF.Close()
        return false
    end
end)
