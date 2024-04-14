local y = 1
local lastexecute = 0

local local_player_table = {
    ["Kopf"] = {},
    ["Torso"] = {},
    ["Linker Arm"] = {},
    ["Rechter Arm"] = {},
    ["Linkes Bein"] = {},
    ["Rechtes Bein"] = {},
    ["Total_verletzungen"] = 0,
    ["Puls"] = 70,
    ["Spo2"] = 100,
    ["Blood pressure"] = {120, 80},
    ["Blut"] = 7000,
    ["Blutverlust"] = "No",
    ["IV"] = 0,
    ["Blutet"] = "No",
    ["schmerz"] = "No",
    ["Log"] = {},
    ["Quick view"] = {},
}

local behandlungen = {
    ["Aktionen"] = {
        [1] = {["display_name"] = "Check Puls", ["behandlungsdauer"] = 5, ["kategorie"] = 1, ["quick_view_name"] = "Puls", ["needs_medic"] = false},
        [2] = {["display_name"] = "Check Spo2", ["behandlungsdauer"] = 5, ["kategorie"] = 1, ["quick_view_name"] = "Spo2", ["needs_medic"] = true},
        [3] = {["display_name"] = "Check Blood pressure", ["behandlungsdauer"] = 5, ["kategorie"] = 1, ["quick_view_name"] = "Blood pressure", ["needs_medic"] = true},
    },
    ["Medikamente"] = {
        [1] = {["display_name"] = "Epinephrine", ["ist_aktiv"] = false, ["zuletzt_gegeben"] = 0, ["wirk_dauer"] = 60, ["max"] = 180, ["min"] = 120, ["toModifi"] = "Puls", ["behandlungsdauer"] = 10, ["kategorie"] = 2, ["needs_medic"] = true},
    },
    ["Transfusion"] = {
        [1] = {["display_name"] = "NaCl 500ml", ["ist_aktiv"] = false, ["zuletzt_gegeben"] = 0, ["wirk_dauer"] = 185, ["Modifier"] = 2.7, ["behandlungsdauer"] = 15, ["kategorie"] = 3, ["needs_medic"] = false},
    },
    ["Verletzungen"] = {
        [1] = {["display_name"] = "Bandage the Blaster Wound",["behandlungsdauer"] = 10, ["kategorie"] = 3, ["verletzungs_name"] = "Blaster Wound", ["wird_zu"] = nil, ["kann_erlitten_werden"] = true, ["warscheinlichkeit"] = 50, ["DMG_Typ"] = {2}, ["needs_medic"] = false},
    },
}

local interaktion = {
    ["kadenz"] = 1,
    ["zuletzt_gesendet"] = 0,
    ["player"] = nil,
    ["hat_begonnen"] = false,
}

local aktion = {
    ["zeit"] = 0,
    ["name"] = nil,
}

local secon_player_table = {
}

local icon_index = 1
local dummy_index = 2

local heder_panel
local heder_label_1
local heder_label_2
local heder_button_1

local body_panel
local body_line
local body_action_panel
local body_overview_panel
local body_action_label
local body_name_label
local body_overview_label
local body_bleding_label
local body_blood_loss_label
local body_iv_label
local body_pain_label
local body_indikater_label
local body_injuri_label
local body_icon_button
local body_icon_paths = {
    "icons/symbol1.png",
    "icons/symbol2.png",
    "icons/symbol3.png",
    "icons/symbol4.png",
}
local body_dummy_button
local body_dummy_paths = {
    "bilder/kopf.png",
    "bilder/torso.png",
    "bilder/arm_links.png",
    "bilder/arm_rechts.png",
    "bilder/bein_links.png",
    "bilder/bein_rechts.png",
}
local body_dummy_v_paths = {
    "bilder/kopf_v.png",
    "bilder/torso_v.png",
    "bilder/arm_links_v.png",
    "bilder/arm_rechts_v.png",
    "bilder/bein_links_v.png",
    "bilder/bein_rechts_v.png",
}

local sub_panel
local sub_line_1
local sub_line_2
local sub_log_headline_label
local sub_view_headline_label
local sub_log_label
local sub_view_label

local treatment_buttons

local DProgress

hook.Add("Think", "Monitoring", function()
    local currentTime = CurTime()
    if currentTime - lastexecute >= y then
        lastexecute = currentTime

        --Puls
        if LocalPlayer():IsSprinting() then
            if local_player_table["Puls"] > 120 then
                local_player_table["Puls"] = local_player_table["Puls"] - math.random(1, 10)
            elseif local_player_table["Puls"] < 100 then
                local_player_table["Puls"] = local_player_table["Puls"] + math.random(1, 10)
            else
                local_player_table["Puls"] = local_player_table["Puls"] + math.random(-3, 7)
            end
        else
            if local_player_table["Puls"] > 70 then
                local_player_table["Puls"] = local_player_table["Puls"] - math.random(1, 10)
            elseif local_player_table["Puls"] < 65 then
                local_player_table["Puls"] = local_player_table["Puls"] + math.random(1, 10)
            else
                local_player_table["Puls"] = local_player_table["Puls"] + math.random(-5, 7)
            end
        end

        if local_player_table["Total_verletzungen"] > 0 then
            local_player_table["Puls"] = math.floor(local_player_table["Puls"] / (local_player_table["Total_verletzungen"] * 0.003 + 1))
        end

        for _, i in pairs(behandlungen["Medikamente"]) do
            if i["ist_aktiv"] then
                if i["zuletzt_gegeben"] + i["wirk_dauer"] >= currentTime then
                    if i["toModifi"] == "Puls" then
                        if local_player_table["Puls"] > i["max"] then
                            local_player_table["Puls"] = local_player_table["Puls"] - math.random(5, 20)
                        elseif local_player_table["Puls"] < i["min"] then
                            local_player_table["Puls"] = local_player_table["Puls"] + math.random(5, 20)
                        else
                            local_player_table["Puls"] = local_player_table["Puls"] + math.random(-10, 10)
                        end
                    elseif i["toModifi"] == "Blood pressure" then
                        if local_player_table["Blood pressure"][1] > i["max"] then
                            local_player_table["Blood pressure"][1] = local_player_table["Blood pressure"][1] - math.random(1, 10)
                        elseif local_player_table["Blood pressure"][1] < i["min"][1] then
                            local_player_table["Blood pressure"][1] = local_player_table["Blood pressure"][1] + math.random(5, 20)
                        else
                            local_player_table["Blood pressure"][1] = local_player_table["Blood pressure"][1] + math.random(-5, 5)
                        end
                    elseif i["toModifi"] == "Spo2" then    
                        if local_player_table["Spo2"] > i["max"] then
                            local_player_table["Spo2"] = local_player_table["Spo2"] - math.random(1, 10)
                        elseif local_player_table["Spo2"] < i["min"] then
                            local_player_table["Spo2"] = local_player_table["Spo2"] + math.random(5, 20)
                        else
                            local_player_table["Spo2"] = local_player_table["Spo2"] + math.random(-5, 5)
                        end
                    end    
                else
                    i["ist_aktiv"] = false
                end
            end
        end

        if local_player_table["Puls"] < 35 and LocalPlayer():Alive() or local_player_table["Puls"] > 230 and LocalPlayer():Alive() then
            net.Start("NidrigeVitalwerte")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        elseif local_player_table["Blood pressure"][1] < 35 and LocalPlayer():Alive() or local_player_table["Blood pressure"][1] > 180 and LocalPlayer():Alive() then
            net.Start("NidrigeVitalwerte")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        elseif local_player_table["Spo2"] < 60 and LocalPlayer():Alive() then
            net.Start("NidrigeVitalwerte")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        elseif local_player_table["Puls"] > 70 and local_player_table["Puls"] < 180 and local_player_table["Blood pressure"][1] > 60 and local_player_table["Blood pressure"][1] < 180 and local_player_table["Spo2"] > 85 and local_player_table["Total_verletzungen"] == 0 and not LocalPlayer():Alive() then
            net.Start("NormaleVitalwerte")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        end

        --Blutdruck
        if local_player_table["Blut"] > 7500 then
            local_player_table["Blood pressure"][1] = local_player_table["Blood pressure"][1] * (local_player_table["Blut"] * 0.0001 + 1)
        elseif local_player_table["Blut"] < 6500 then
            if local_player_table["Blood pressure"][1] / (local_player_table["Blut"] * 0.0001 + 1) < 0 then
                local_player_table["Blood pressure"][1] = 0
            else
                local_player_table["Blood pressure"][1] = local_player_table["Blood pressure"][1] / (local_player_table["Blut"] * 0.0001 + 1)
            end
        end
        if local_player_table["Blood pressure"][1] > 135 then
            local_player_table["Blood pressure"][1] = local_player_table["Blood pressure"][1] - math.random(1, 10)
        elseif local_player_table["Blood pressure"][1] < 105 then
            local_player_table["Blood pressure"][1] = local_player_table["Blood pressure"][1] + math.random(1, 10)
        else
            local_player_table["Blood pressure"][1] = local_player_table["Blood pressure"][1] + math.random(-10, 15)
        end
        local_player_table["Blood pressure"][2] = local_player_table["Blood pressure"][1] - math.random(20, 50)

        --Spo2
        if local_player_table["Puls"] < 50 then 
            local_player_table["Spo2"] = local_player_table["Spo2"] / (local_player_table["Puls"] * 0.001 + 1)
        elseif local_player_table["Puls"] > 70 then
            if local_player_table["Spo2"] * (local_player_table["Puls"] * 0.001 + 1) > 100 then
                local_player_table["Spo2"] = 100
            else
                local_player_table["Spo2"] = local_player_table["Spo2"] * (local_player_table["Puls"] * 0.001 + 1)
            end
        elseif local_player_table["Puls"] >= 55 and local_player_table["Puls"] <= 70 then
            local_player_table["Spo2"] = local_player_table["Spo2"] math.random(-3, 10)
            if local_player_table["Spo2"] > 100 then
                local_player_table["Spo2"] = 100
            end
        end
        --blutungen
        if local_player_table["Total_verletzungen"] > 0 then
            if local_player_table["Total_verletzungen"] <= 5 then
                local_player_table["Blutet"] = "Light"
            elseif local_player_table["Total_verletzungen"] > 5 and local_player_table["Total_verletzungen"] <= 15 then 
                local_player_table["Blutet"] = "Medium"
            elseif local_player_table["Total_verletzungen"] > 15 then
                local_player_table["Blutet"] = "Strong"
            end
        else
            local_player_table["Blutet"] = "No"
        end

        if local_player_table["Blutet"] == "Light" then
            local_player_table["Blut"] = local_player_table["Blut"] - 1.5
        elseif local_player_table["Blutet"] == "Medium" then
            local_player_table["Blut"] = local_player_table["Blut"] - 3
        elseif local_player_table["Blutet"] == "Strong" then
            local_player_table["Blut"] = local_player_table["Blut"] - 4.5
        elseif local_player_table["Blut"] < 7000 then
            local_player_table["Blut"] = local_player_table["Blut"] + 0.01
        elseif local_player_table["Blut"] > 7000 then
            local_player_table["Blut"] = local_player_table["Blut"] - 0.01
        end 

        if local_player_table["Blut"] < 7000 and local_player_table["Blut"] > 6500 then
            local_player_table["Blutverlust"] = "Light"
        elseif local_player_table["Blut"] < 6500 and local_player_table["Blut"] > 5500 then
            local_player_table["Blutverlust"] = "Medium"
        elseif local_player_table["Blut"] < 5500 then
            local_player_table["Blutverlust"] = "Strong"
        elseif local_player_table["Blut"] >= 7000 then
            local_player_table["Blutverlust"] = "No"
        end

        local_player_table["iv"] = 0

        for _,i in pairs(behandlungen["Transfusion"]) do 
            if i["ist_aktiv"] then
                if i["zuletzt_gegeben"] + i["wirk_dauer"] >= currentTime then
                    local_player_table["Blut"] = local_player_table["Blut"] + i["Modifier"]
                    local_player_table["iv"] = math.floor(local_player_table["iv"] + ((i["zuletzt_gegeben"] - currentTime + i["wirk_dauer"]) * i["Modifier"]))
                end
            end
        end

        if local_player_table["Puls"] < 0   then
            local_player_table["Puls"] = 0
        end
        if local_player_table["Blood pressure"][2] < 0   then
            local_player_table["Blood pressure"][2] = 0
        end
        if local_player_table["Spo2"] < 0   then
            local_player_table["Spo2"] = 0
        end
    end
end)

net.Receive("AddWunde", function()
    local region = net.ReadString()
    local wunde = net.ReadString()
    local_player_table["Total_verletzungen"] = local_player_table["Total_verletzungen"] + 1

    if region == "Kopf" then
        table.insert(local_player_table["Kopf"], 1, wunde)
    elseif region == "Torso" then
        table.insert(local_player_table["Torso"], 1, wunde)
    elseif region == "Linker Arm" then
        table.insert(local_player_table["Linker Arm"], 1, wunde)
    elseif region == "Rechter Arm" then
        table.insert(local_player_table["Rechter Arm"], 1, wunde)
    elseif region == "Linkes Bein" then
        table.insert(local_player_table["Linkes Bein"], 1, wunde)
    elseif region == "Rechtes Bein" then
        table.insert(local_player_table["Rechtes Bein"], 1, wunde)
    end
end)
---------------------------------------------------------------------------------------------------

hook.Add("OnPlayerChat", "open_medical", function(ply, text, teamChat, isDead)
    if ply == LocalPlayer() and text == "!m" and ply:Alive() then
        if checkPlayerLookingAtPlayer(ply) ~= nil and heder_panel == nil then
            start_interaktion(checkPlayerLookingAtPlayer(ply))
        elseif heder_panel == nil then 
            start_interaktion(ply)
        end
    elseif ply == LocalPlayer() and splitString(text)[1] == "!m" and ply:Alive() then
        if DarkRP.findPlayer(splitString(text)[2]) ~= nil then
            if DarkRP.findPlayer(splitString(text)[2]):IsValid() and DarkRP.findPlayer(splitString(text)[2]):IsPlayer() then
                if ply:GetPos():Distance(DarkRP.findPlayer(splitString(text)[2]):GetPos()) <= 300 then 
                    start_interaktion(DarkRP.findPlayer(splitString(text)[2]))
            else
                    ply:ChatPrint("The player is too far away!")
                end
            end
        end
    elseif ply == LocalPlayer() and text == "!heal" then
        if checkPlayerLookingAtPlayer(ply) ~= nil then
            heal_player(checkPlayerLookingAtPlayer(ply))
        else
            heal_player(ply)
        end
    elseif ply == LocalPlayer() and splitString(text)[1] == "!heal" then
        if DarkRP.findPlayer(splitString(text)[2]) ~= nil then
            if DarkRP.findPlayer(splitString(text)[2]):IsValid() and DarkRP.findPlayer(splitString(text)[2]):IsPlayer() then
                heal_player(DarkRP.findPlayer(splitString(text)[2]))
            end
        end
    elseif ply == LocalPlayer() and splitString(text)[1] == "!injury" then
        if DarkRP.findPlayer(splitString(text)[2]) ~= nil then
            if DarkRP.findPlayer(splitString(text)[2]):IsValid() and DarkRP.findPlayer(splitString(text)[2]):IsPlayer() then
                if splitString(text)[3] ~= nil then
                    if splitString(text)[3] == "shot" then
                        verletzung(DarkRP.findPlayer(splitString(text)[2]), 2)
                    else
                        ply:ChatPrint(splitString(text)[3] .. " is not a valid violation. The following are possible: shot")
                    end
                else
                    ply:ChatPrint("Please indicate an injury. The following are possible: shot")
                end
            end
        end
    end
    return true
end)

function verletzung(ply, dmg_typ)
    net.Start("ReciveDamgePlayer")
    net.WriteEntity(LocalPlayer())
    net.WriteEntity(ply)
    net.WriteInt(dmg_typ, 32)
    net.SendToServer()
end

function heal_player(ply)
    net.Start("SendHealPlayer")
    net.WriteEntity(LocalPlayer())
    net.WriteEntity(ply)
    net.SendToServer()
end

function splitString(inputString)
    local result = {} -- Ein leeres Array, um die Teile des Strings zu speichern
    for word in string.gmatch(inputString, "%S+") do
        table.insert(result, word) -- Füge das Wort zum Array hinzu
    end
    return result
end

function checkPlayerLookingAtPlayer(ply)
    local trace = ply:GetEyeTrace()

    if trace.Hit and IsValid(trace.Entity) and trace.Entity:IsPlayer() then
        local lookedPlayer = trace.Entity
        local distance = ply:GetPos():Distance(lookedPlayer:GetPos())

        if distance <= 300 then -- 300 entspricht 3 Metern
            return lookedPlayer
        end
    end
    return nil
end

net.Receive("ReciveHealPlayer", function()
    local_player_table = {
        ["Kopf"] = {},
        ["Torso"] = {},
        ["Linker Arm"] = {},
        ["Rechter Arm"] = {},
        ["Linkes Bein"] = {},
        ["Rechtes Bein"] = {},
        ["Total_verletzungen"] = 0,
        ["Puls"] = 70,
        ["Spo2"] = 100,
        ["Blood pressure"] = {120, 80},
        ["Blut"] = 7000,
        ["Blutverlust"] = "Kein",
        ["IV"] = 0,
        ["Blutet"] = "Nein",
        ["schmerz"] = "Keine",
        ["Log"] = {},
        ["Quick view"] = {},
    }

    behandlungen["Medikamente"] = {
            [1] = {["display_name"] = "Epinephrine", ["ist_aktiv"] = false, ["zuletzt_gegeben"] = 0, ["wirk_dauer"] = 60, ["max"] = 180, ["min"] = 120, ["toModifi"] = "Puls", ["behandlungsdauer"] = 10, ["kategorie"] = 2, ["needs_medic"] = true},
        }
end)

hook.Add("Think", "PlayerInteraktion", function()
    local currentTime = CurTime()
    if interaktion["hat_begonnen"] and currentTime - interaktion["zuletzt_gesendet"] > interaktion["kadenz"] then
        interaktion["zuletzt_gesendet"] = currentTime
        net.Start("SendeTable")
        net.WriteTable(local_player_table)
        net.WriteEntity(interaktion["player"])
        net.WriteEntity(LocalPlayer())
        net.SendToServer()
    end
end)

net.Receive("ReciveStartInteraktion", function()
    interaktion["player"] = net.ReadEntity()
    interaktion["hat_begonnen"] = true
end)

net.Receive("ReciveInteraktion", function()
    local str = net.ReadString()
    local ply = net.ReadEntity()
    local index = net.ReadInt(32)

    for u, i in pairs(behandlungen) do
        for _, entry in ipairs(i) do 
            if u == "Aktionen" then
                if entry["display_name"] == str then
                    if entry["display_name"] == "Check Blood pressure" then
                        table.insert(local_player_table["Quick view"], 1, os.date("%X") .. ": " .. entry["quick_view_name"] .. " was checked by " .. ply:Nick() .. ". " .. entry["quick_view_name"] .. " = ".. local_player_table[entry["quick_view_name"]][1] .. " / " .. local_player_table[entry["quick_view_name"]][2])
                    else
                        table.insert(local_player_table["Quick view"], 1, os.date("%X") .. ": " .. entry["quick_view_name"] .. " was checked by " .. ply:Nick() .. ". " .. entry["quick_view_name"] .. " = ".. local_player_table[entry["quick_view_name"]])
                    end
                end
            elseif u == "Medikamente" then
                if entry["display_name"] == str then
                    entry["ist_aktiv"] = true
                    entry["zuletzt_gegeben"] = CurTime()

                    table.insert(local_player_table["Log"], 1, os.date("%X") .. ": " .. entry["display_name"] .. " was administered by " .. ply:Nick() .. ".")
                end
            elseif u == "Transfusion" then
                if entry["display_name"] == str then
                    entry["ist_aktiv"] = true
                    entry["zuletzt_gegeben"] = CurTime()

                    table.insert(local_player_table["Log"], 1, os.date("%X") .. ": " .. entry["display_name"] .. " was administered by " .. ply:Nick() .. ".")
                end
            elseif u == "Verletzungen" then
                if entry["display_name"] == str then
                    if index == 1 then
                        for _, i in ipairs(local_player_table["Kopf"]) do 
                            if local_player_table["Kopf"][_] == entry["verletzungs_name"] then
                                table.remove(local_player_table["Kopf"], _)
                                if entry["wird_zu"] ~= nil then
                                    table.insert(local_player_table["Kopf"], 1, entry["wird_zu"])
                                else
                                    if local_player_table["Total_verletzungen"] > 0 then
                                        net.Start("VerletzungBehandelt")
                                        net.WriteEntity(LocalPlayer())
                                        net.WriteInt(local_player_table["Total_verletzungen"], 32)
                                        net.SendToServer()
                                        local_player_table["Total_verletzungen"] = local_player_table["Total_verletzungen"] - 1
                                    end
                                end
                            return end
                        end
                    elseif index == 2 then
                        for _, i in ipairs(local_player_table["Torso"]) do 
                            if local_player_table["Torso"][_] == entry["verletzungs_name"] then
                                table.remove(local_player_table["Torso"], _)
                                
                                if entry["wird_zu"] ~= nil then
                                    table.insert(local_player_table["Torso"], 1, entry["wird_zu"])
                                else
                                    if local_player_table["Total_verletzungen"] > 0 then
                                        net.Start("VerletzungBehandelt")
                                        net.WriteEntity(LocalPlayer())
                                        net.WriteInt(local_player_table["Total_verletzungen"], 32)
                                        net.SendToServer()
                                        local_player_table["Total_verletzungen"] = local_player_table["Total_verletzungen"] - 1
                                    end
                                end
                            return end
                        end
                    elseif index == 3 then
                        for _, i in ipairs(local_player_table["Linker Arm"]) do 
                            if local_player_table["Linker Arm"][_] == entry["verletzungs_name"] then
                                table.remove(local_player_table["Linker Arm"], _)
                                
                                if entry["wird_zu"] ~= nil then
                                    table.insert(local_player_table["Linker Arm"], 1, entry["wird_zu"])
                                else
                                    if local_player_table["Total_verletzungen"] > 0 then
                                        net.Start("VerletzungBehandelt")
                                        net.WriteEntity(LocalPlayer())
                                        net.WriteInt(local_player_table["Total_verletzungen"], 32)
                                        net.SendToServer()
                                        local_player_table["Total_verletzungen"] = local_player_table["Total_verletzungen"] - 1
                                    end
                                end
                            return end
                        end
                    elseif index == 4 then
                        for _, i in ipairs(local_player_table["Rechter Arm"]) do 
                            if local_player_table["Rechter Arm"][_] == entry["verletzungs_name"] then
                                table.remove(local_player_table["Rechter Arm"], _)
                                
                                if entry["wird_zu"] ~= nil then
                                    table.insert(local_player_table["Rechter Arm"], 1, entry["wird_zu"])
                                else
                                    if local_player_table["Total_verletzungen"] > 0 then
                                        net.Start("VerletzungBehandelt")
                                        net.WriteEntity(LocalPlayer())
                                        net.WriteInt(local_player_table["Total_verletzungen"], 32)
                                        net.SendToServer()
                                        local_player_table["Total_verletzungen"] = local_player_table["Total_verletzungen"] - 1
                                    end
                                end
                            return end
                        end
                    elseif index == 5 then
                        for _, i in ipairs(local_player_table["Linkes Bein"]) do 
                            if local_player_table["Linkes Bein"][_] == entry["verletzungs_name"] then
                                table.remove(local_player_table["Linkes Bein"], _)
                                
                                if entry["wird_zu"] ~= nil then
                                    table.insert(local_player_table["Linkes Bein"], 1, entry["wird_zu"])
                                else
                                    if local_player_table["Total_verletzungen"] > 0 then
                                        net.Start("VerletzungBehandelt")
                                        net.WriteEntity(LocalPlayer())
                                        net.WriteInt(local_player_table["Total_verletzungen"], 32)
                                        net.SendToServer()
                                        local_player_table["Total_verletzungen"] = local_player_table["Total_verletzungen"] - 1
                                    end
                                end
                            return end
                        end
                    elseif index == 6 then
                        for _, i in ipairs(local_player_table["Rechtes Bein"]) do 
                            if local_player_table["Rechtes Bein"][_] == entry["verletzungs_name"] then
                                table.remove(local_player_table["Rechtes Bein"], _)
                                
                                if entry["wird_zu"] ~= nil then
                                    table.insert(local_player_table["Rechtes Bein"], 1, entry["wird_zu"])
                                else
                                    if local_player_table["Total_verletzungen"] > 0 then
                                        net.Start("VerletzungBehandelt")
                                        net.WriteEntity(LocalPlayer())
                                        net.WriteInt(local_player_table["Total_verletzungen"], 32)
                                        net.SendToServer()
                                        local_player_table["Total_verletzungen"] = local_player_table["Total_verletzungen"] - 1
                                    end
                                end
                            return end
                        end
                    end
                end
            end
        end
    end
end)

function FormatTimeString(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

net.Receive("ReciveTable", function()
    secon_player_table = net.ReadTable()
    local ply = net.ReadEntity()
    open_menu(ply)
end)

net.Receive("ReciveEndInteraktion", function()
    interaktion["player"] = nil
    interaktion["hat_begonnen"] = false
end)

function start_interaktion(ply)
    net.Start("SendStartInteraktion")
    net.WriteEntity(LocalPlayer())
    net.WriteEntity(ply)
    net.SendToServer()
end

function end_interaktion(ply)
    net.Start("SendEndInteraktion")
    net.WriteEntity(ply)
    net.SendToServer()
end

function open_menu(ply)
    create_heder(ply)
    create_body(ply) 
    create_buttons(ply)
    create_sub()
end

function close_menu(ply)
    end_interaktion(ply)

    heder_panel:Remove()
    heder_panel = nil
    heder_label_1 = nil
    heder_label_2 = nil
    heder_button_1 = nil

    body_panel:Remove()
    body_panel = nil
    body_action_panel = nil
    body_overview_panel = nil
    body_action_label = nil
    body_name_label = nil
    body_overview_label = nil
    body_icon_button = nil
    body_bleding_label = nil
    body_blood_loss_label = nil
    body_iv_label = nil
    body_pain_label = nil
    body_indikater_label = nil
    body_injuri_label = nil
    treatment_buttons = nil

    sub_panel:Remove()
    sub_panel = nil
    sub_line_1 = nil
    sub_line_1 = nil
    sub_log_headline_label = nil
    sub_view_headline_label = nil
    sub_log_label = nil
    sub_view_label = nil
end

function create_heder(ply)
    if heder_panel == nil then
        heder_panel = vgui.Create("DPanel")
        heder_label_1 = vgui.Create("DLabel", heder_panel)
        heder_label_2 = vgui.Create("DLabel", heder_panel)
        heder_button_1 = vgui.Create("DButton", heder_panel)
    end

    heder_panel:SetSize(1000, 30)
    heder_panel:Center()
    heder_panel:SetPos(heder_panel:GetX(), (heder_panel:GetY() / 2) - 105)
    heder_panel:SetBackgroundColor(Color(193, 146, 64, 255))
    heder_panel:MakePopup()

    heder_label_1:SetPos(0, 0)
    heder_label_1:SetSize(180, 30)
    heder_label_1:SetFont("DermaLarge")
    heder_label_1:SetTextColor(Color( 255, 255, 255))
    heder_label_1:SetText("Medical Menu")

    heder_label_2:SetPos(170, 12)
    heder_label_2:SetSize(100, 15)
    heder_label_2:SetFont("DermaDefault")
    heder_label_2:SetTextColor(Color( 255, 255, 255))
    heder_label_2:SetText("©Deadshot")

    heder_button_1:SetSize(100 , 30)
    heder_button_1:SetPos(900, 0)
    heder_button_1:SetText("Close")
    function heder_button_1:Paint(w,h)
        surface.SetDrawColor(193, 146, 64, 255)
    end
    heder_button_1.DoClick = function()
        close_menu(ply)
    end
end

function create_body(ply)
    if body_injuri_label ~= nil or treatment_buttons ~= nil then
        body_panel:Remove()
        body_panel = nil
        body_action_panel = nil
        body_overview_panel = nil
        body_action_label = nil
        body_name_label = nil
        body_overview_label = nil
        body_icon_button = nil
        body_bleding_label = nil
        body_blood_loss_label = nil
        body_iv_label = nil
        body_pain_label = nil
        body_indikater_label = nil
        body_injuri_label = nil
        treatment_buttons = nil
    end

    if body_panel == nil then
        body_panel = vgui.Create("DPanel")
        body_line = vgui.Create("DPanel", body_panel)
        body_action_panel = vgui.Create("DPanel", body_panel)
        body_overview_panel = vgui.Create("DPanel", body_panel)
        body_action_label = vgui.Create("DLabel", body_panel)
        body_name_label = vgui.Create("DLabel", body_panel)
        body_overview_label = vgui.Create("DLabel", body_panel)

        body_bleding_label = vgui.Create("DLabel", body_overview_panel)
        body_blood_loss_label = vgui.Create("DLabel", body_overview_panel)
        body_iv_label = vgui.Create("DLabel", body_overview_panel)
        body_pain_label = vgui.Create("DLabel", body_overview_panel)
        body_indikater_label = vgui.Create("DLabel", body_overview_panel)
    end

    body_panel:SetSize(1000, 500)
    body_panel:Center()
    body_panel:SetPos(body_panel:GetX(), (body_panel:GetY() / 2) + 50)
    body_panel:SetBackgroundColor(Color(35, 35, 35, 200))

    body_action_panel:SetSize(300, 400)
    body_action_panel:Center()
    body_action_panel:SetContentAlignment(5)
    body_action_panel:SetPos(body_action_panel:GetX()  - 340, body_action_panel:GetY() + 40)
    body_action_panel:SetBackgroundColor(Color(35, 35, 35, 150))

    body_overview_panel:SetSize(300, 450)
    body_overview_panel:Center()
    body_overview_panel:SetContentAlignment(5)
    body_overview_panel:SetPos(body_overview_panel:GetX() + 340, body_overview_panel:GetY() + 15)
    body_overview_panel:SetBackgroundColor(Color(35, 35, 35, 150))

    body_line:SetSize(1000, 500)
    body_line:Center()
    function body_line:Paint(w,h)
        surface.SetDrawColor( 255, 255, 255, 255 )
        surface.DrawLine( body_action_panel:GetX() , 30, body_overview_panel:GetX() + 300, 30)
    end

    body_action_label:SetSize(200, 50)
    body_action_label:Center()
    body_action_label:SetContentAlignment(5)
    body_action_label:SetFont("DermaLarge")
    body_action_label:SetPos(body_action_label:GetX() - 340, body_action_label:GetY() - 235)
    body_action_label:SetText("Treatments")

    body_name_label:SetSize(400, 50)
    body_name_label:Center()
    body_name_label:SetContentAlignment(5)
    body_name_label:SetFont("DermaLarge")
    body_name_label:SetPos(body_name_label:GetX(), body_name_label:GetY() - 235)
    body_name_label:SetText(ply:Nick())

    body_overview_label:SetSize(200, 50)
    body_overview_label:Center()
    body_overview_label:SetContentAlignment(5)
    body_overview_label:SetFont("DermaLarge")
    body_overview_label:SetPos(body_overview_label:GetX() + 340, body_overview_label:GetY() - 235)
    body_overview_label:SetText("Overview")

    body_bleding_label:SetSize(300, 20)
    body_bleding_label:SetFont("DermaDefault")
    body_bleding_label:SetPos(2, 0)
    body_bleding_label:SetText("Bleeds: " .. secon_player_table["Blutet"])

    body_blood_loss_label:SetSize(300, 20)
    body_blood_loss_label:SetFont("DermaDefault")
    body_blood_loss_label:SetPos(2, 20)
    body_blood_loss_label:SetText(secon_player_table["Blutverlust"] .. " Blood loss")

    body_iv_label:SetSize(300, 20)
    body_iv_label:SetFont("DermaDefault")
    body_iv_label:SetPos(2, 40)
    body_iv_label:SetText(secon_player_table["iv"] .. " ml IV")

    body_pain_label:SetSize(300, 20)
    body_pain_label:SetFont("DermaDefault")
    body_pain_label:SetPos(2, 60)
    body_pain_label:SetText("Pain: " .. secon_player_table["schmerz"])

    body_indikater_label:SetSize(300, 35)
    body_indikater_label:SetFont("DermaLarge")
    body_indikater_label:SetPos(2, 105)
    if dummy_index == 1 then 
        body_indikater_label:SetText("Kopf")
        create_injury("Kopf")
    elseif dummy_index == 2 then 
        body_indikater_label:SetText("Torso")
        create_injury("Torso")
    elseif dummy_index == 3 then 
        body_indikater_label:SetText("Linker Arm")
        create_injury("Linker Arm")
    elseif dummy_index == 4 then 
        body_indikater_label:SetText("Rechter Arm")
        create_injury("Rechter Arm")
    elseif dummy_index == 5 then 
        body_indikater_label:SetText("Linkes Bein")
        create_injury("Linkes Bein")
    elseif dummy_index == 6 then 
        body_indikater_label:SetText("Rechtes Bein")
        create_injury("Rechtes Bein")
    end

    for _, i in ipairs(body_icon_paths) do
        body_icon_button = vgui.Create("DImageButton", body_panel)
        body_icon_button:SetPos(10 + (50 * _ - 50), 36)
        body_icon_button:SetSize(50, 50)
        body_icon_button:SetImage(body_icon_paths[_])
        body_icon_button:SetMouseInputEnabled(true)
        if DProgress ~= nil then 
            body_icon_button:SetEnabled(false)
        else
            body_icon_button:SetEnabled(true)
        end
        body_icon_button.DoClick = function()
            icon_index = _
            open_menu(ply)
        end
    end

    for _, i in ipairs(body_dummy_paths) do
        body_dummy_button = vgui.Create("DImageButton", body_panel)
        if _ == 1 then
            body_dummy_button:SetPos(462, 47)
            body_dummy_button:SetSize(74, 77)
            if secon_player_table["Kopf"][1] == nil then
                body_dummy_button:SetImage(body_dummy_paths[_])
            else
                body_dummy_button:SetImage(body_dummy_v_paths[_])
            end
        elseif _ == 2 then 
            body_dummy_button:SetPos(451, 124)
            body_dummy_button:SetSize(96, 134)
            if secon_player_table["Torso"][1] == nil then
                body_dummy_button:SetImage(body_dummy_paths[_])
            else
                body_dummy_button:SetImage(body_dummy_v_paths[_])
            end
        elseif _ == 3 then 
            body_dummy_button:SetPos(408, 114)
            body_dummy_button:SetSize(44, 177)
            if secon_player_table["Linker Arm"][1] == nil then
                body_dummy_button:SetImage(body_dummy_paths[_])
            else
                body_dummy_button:SetImage(body_dummy_v_paths[_])
            end
        elseif _ == 4 then 
            body_dummy_button:SetPos(547, 114)
            body_dummy_button:SetSize(44, 177)
            if secon_player_table["Rechter Arm"][1] == nil then
                body_dummy_button:SetImage(body_dummy_paths[_])
            else
                body_dummy_button:SetImage(body_dummy_v_paths[_])
            end
        elseif _ == 5 then
            body_dummy_button:SetPos(423, 258)
            body_dummy_button:SetSize(77, 236)
            if secon_player_table["Linkes Bein"][1] == nil then
                body_dummy_button:SetImage(body_dummy_paths[_])
            else
                body_dummy_button:SetImage(body_dummy_v_paths[_])
            end
        elseif _ == 6 then
            body_dummy_button:SetPos(500, 258)
            body_dummy_button:SetSize(77, 236)
            if secon_player_table["Rechtes Bein"][1] == nil then
                body_dummy_button:SetImage(body_dummy_paths[_])
            else
                body_dummy_button:SetImage(body_dummy_v_paths[_])
            end
        end
        body_dummy_button:SetMouseInputEnabled(true)
        if DProgress ~= nil then 
            body_dummy_button:SetEnabled(false)
        else
            body_dummy_button:SetEnabled(true)
        end
        body_dummy_button.DoClick = function()
            dummy_index = _
            open_menu(ply)
        end
    end
end

function create_injury(str)
    if secon_player_table[str][1] == nil then
        body_injuri_label = vgui.Create("DLabel", body_overview_panel)
        body_injuri_label:SetSize(300, 20)
        body_injuri_label:SetFont("DermaDefault")
        body_injuri_label:SetPos(2, 135)
        body_injuri_label:SetText("No injuries to this part of the body ...")
    else
        for _, i in ipairs(secon_player_table[str]) do 
            body_injuri_label = vgui.Create("DLabel", body_overview_panel)
            body_injuri_label:SetSize(300, 20)
            body_injuri_label:SetFont("DermaDefault")
            body_injuri_label:SetPos(2, 135 + (15 * _))
            body_injuri_label:SetText(secon_player_table[str][_])
        end
    end 
end

function create_sub()
    if sub_view_label ~= nil or sub_log_label ~= nil then
        sub_panel:Remove()
        sub_panel = nil
        sub_line_1 = nil
        sub_line_1 = nil
        sub_log_headline_label = nil
        sub_view_headline_label = nil
        sub_log_label = nil
        sub_view_label = nil
    end

    if  sub_panel == nil then
        sub_panel = vgui.Create("DPanel")
        sub_line_1 = vgui.Create("DPanel", sub_panel)
        sub_line_2 = vgui.Create("DPanel", sub_panel)
        sub_log_headline_label = vgui.Create("DLabel", sub_panel)
        sub_view_headline_label = vgui.Create("DLabel", sub_panel)
    end

    sub_panel:SetSize(1000, 250)
    sub_panel:Center()
    sub_panel:SetPos(sub_panel:GetX(), (sub_panel:GetY() / 2) + 500)
    sub_panel:SetBackgroundColor(Color(35, 35, 35, 200))

    sub_line_1:SetSize(1000, 250)
    sub_line_1:Center()
    function sub_line_1:Paint(w,h)
        surface.SetDrawColor( 255, 255, 255, 255 )
        surface.DrawLine( 5 , 30, 995, 30)
    end
    sub_line_2:SetSize(1000, 250)
    sub_line_2:Center()
    sub_line_2:SetContentAlignment(5)
    function sub_line_2:Paint(w,h)
        surface.SetDrawColor( 255, 255, 255, 255 )
        surface.DrawLine( 500, 40, 500, 250)
    end

    sub_log_headline_label:SetSize(200, 50)
    sub_log_headline_label:Center()
    sub_log_headline_label:SetContentAlignment(5)
    sub_log_headline_label:SetFont("DermaLarge")
    sub_log_headline_label:SetPos(sub_log_headline_label:GetX() - 250, sub_log_headline_label:GetY() - 110)
    sub_log_headline_label:SetText("Activity log")

    sub_view_headline_label:SetSize(400, 50)
    sub_view_headline_label:Center()
    sub_view_headline_label:SetContentAlignment(5)
    sub_view_headline_label:SetFont("DermaLarge")
    sub_view_headline_label:SetPos(sub_view_headline_label:GetX() + 250, sub_view_headline_label:GetY() - 110)
    sub_view_headline_label:SetText("Quick overview")

    create_log()
end

function create_log()
    if secon_player_table["Log"][1] ~= nil then
        for _, i in ipairs(secon_player_table["Log"]) do 
            sub_log_label = vgui.Create("DLabel", sub_panel)
            sub_log_label:SetSize(500, 20)
            sub_log_label:SetFont("DermaDefault")
            sub_log_label:SetPos(5, 20 + (15 * _))
            sub_log_label:SetText(secon_player_table["Log"][_])
        end
    end 
    if secon_player_table["Quick view"][1] ~= nil then
        for _, i in ipairs(secon_player_table["Quick view"]) do 
            sub_view_label = vgui.Create("DLabel", sub_panel)
            sub_view_label:SetSize(500, 20)
            sub_view_label:SetFont("DermaDefault")
            sub_view_label:SetPos(505, 20 + (15 * _))
            sub_view_label:SetText(secon_player_table["Quick view"][_])
        end
    end 
end

function create_buttons(ply)
    local z = 1
    for u, i in pairs(behandlungen) do
        for _, entry in ipairs(i) do
            if entry["kategorie"] == icon_index then
                if u == "Verletzungen" then
                    if dummy_index == 1 then
                        if check_player_verletzungen(entry["verletzungs_name"], "Kopf") then
                            create_tretment_buttons(entry, z, ply)
                            z = z + 1
                        end
                    elseif dummy_index == 2 then
                        if check_player_verletzungen(entry["verletzungs_name"], "Torso") then
                            create_tretment_buttons(entry, z, ply)
                            z = z + 1
                        end 
                    elseif dummy_index == 3 then
                        if check_player_verletzungen(entry["verletzungs_name"], "Linker Arm") then
                            create_tretment_buttons(entry, z, ply)
                            z = z + 1
                        end
                    elseif dummy_index == 4 then
                        if check_player_verletzungen(entry["verletzungs_name"], "Rechter Arm") then
                            create_tretment_buttons(entry, z, ply)
                            z = z + 1
                        end
                    elseif dummy_index == 5 then
                        if check_player_verletzungen(entry["verletzungs_name"], "Linkes Bein") then
                            create_tretment_buttons(entry, z, ply)
                            z = z + 1
                        end
                    elseif dummy_index == 6 then
                        if check_player_verletzungen(entry["verletzungs_name"], "Rechtes Bein") then
                            create_tretment_buttons(entry, z, ply)
                            z = z + 1
                        end
                    end
                else
                    create_tretment_buttons(entry, z, ply)
                    z = z + 1
                end
            end
        end
    end
end

function check_player_verletzungen(str1, str2)
    for _, i in ipairs(secon_player_table[str2]) do 
        if i == str1 then 
            return true
        end
    end
    return false
end

function create_tretment_buttons(entry, z, ply)
    if entry["needs_medic"] then
        if ply:isMedic() then
            treatment_buttons = vgui.Create("DButton", body_panel)
            treatment_buttons:SetSize(300, 30)
            treatment_buttons:SetFont("DermaDefault")
            treatment_buttons:SetPos(10, 60 + (30 * z))
            treatment_buttons:SetText(entry["display_name"])
            if DProgress ~= nil then 
                treatment_buttons:SetEnabled(false)
            else
                treatment_buttons:SetEnabled(true)
            end
            treatment_buttons.DoClick = function()
                if ply:isMedic() or ply:GetActiveWeapon():GetClass() == "medic_scanner" then
                    aktion["zeit"] = 1 / (entry["behandlungsdauer"] / 2)
                else
                    aktion["zeit"] = 1 / entry["behandlungsdauer"]
                end
                aktion["name"] = entry["display_name"]
                aktion["player"] = ply
                create_progress_bar()
            end
        end
    else
        treatment_buttons = vgui.Create("DButton", body_panel)
            treatment_buttons:SetSize(300, 30)
            treatment_buttons:SetFont("DermaDefault")
            treatment_buttons:SetPos(10, 60 + (30 * z))
            treatment_buttons:SetText(entry["display_name"])
            if DProgress ~= nil then 
                treatment_buttons:SetEnabled(false)
            else
                treatment_buttons:SetEnabled(true)
            end
            treatment_buttons.DoClick = function()
                if ply:isMedic() or ply:GetActiveWeapon():GetClass() == "medic_scanner" then
                    aktion["zeit"] = 1 / (entry["behandlungsdauer"] / 2)
                else
                    aktion["zeit"] = 1 / entry["behandlungsdauer"]
                end
                aktion["name"] = entry["display_name"]
                aktion["player"] = ply
                create_progress_bar()
            end
    end
end

function create_progress_bar(ply)
    if  DProgress == nil then
        DProgress = vgui.Create( "DProgress" )
        DProgress:Center()
        DProgress:SetPos( ScrW() / 2 - 100, ScrH() / 2 - 10)
        DProgress:SetSize( 200, 20 )
        DProgress:MakePopup()
    end

    if body_panel ~= nil then 
        if DProgress:GetFraction() >= 1 then
            DProgress:Remove()
            DProgress = nil
            net.Start("SendInteraktion")
            net.WriteEntity(aktion["player"])
            net.WriteEntity(LocalPlayer())
            net.WriteString(aktion["name"])
            net.WriteInt(dummy_index, 32)
            net.SendToServer()
        else 
            DProgress:SetFraction( DProgress:GetFraction() +  aktion["zeit"])
            timer.Simple(1, create_progress_bar)
        end
    else
        DProgress:Remove()
        DProgress = nil
    end 
end
