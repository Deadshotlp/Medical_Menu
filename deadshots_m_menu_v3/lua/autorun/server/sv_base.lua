
util.AddNetworkString("NidrigeVitalwerte")
util.AddNetworkString("NormaleVitalwerte")
util.AddNetworkString("AddWunde")
util.AddNetworkString("SendStartInteraktion")
util.AddNetworkString("ReciveStartInteraktion")
util.AddNetworkString("SendInteraktion")
util.AddNetworkString("ReciveInteraktion")
util.AddNetworkString("SendeTable")
util.AddNetworkString("ReciveTable")
util.AddNetworkString("SendEndInteraktion")
util.AddNetworkString("ReciveEndInteraktion")
util.AddNetworkString("VerletzungBehandelt")

util.AddNetworkString("SendHealPlayer")
util.AddNetworkString("ReciveHealPlayer")
util.AddNetworkString("ReciveDamgePlayer")
util.AddNetworkString("SendOpenConfig")
util.AddNetworkString("ReciveOpenConfig")

local behandlungen = {
    ["Verletzungen"] = {
        [1] = {["display_name"] = "Bandage the Blaster Wound",["behandlungsdauer"] = 10, ["kategorie"] = 3, ["verletzungs_name"] = "Blaster Wound", ["wird_zu"] = nil, ["kann_erlitten_werden"] = true, ["warscheinlichkeit"] = 50, ["DMG_Typ"] = {2}, ["needs_medic"] = false},
    },
}

net.Receive("SendHealPlayer", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()
    if ply1:IsSuperAdmin() then 
        if ply1 == ply2 then
            print(ply1:Nick() .. " healed himself")
        else
            print(ply1:Nick() .. " healed " .. ply2:Nick() .. ".")
        end

        net.Start("ReciveHealPlayer")
        net.Send(ply2)

        ply2:SetHealth(ply2:GetMaxHealth())
    end
end)

net.Receive("ReciveDamgePlayer", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()
    local dmg_typ = net.ReadInt(32)

    if ply1:IsSuperAdmin() then 
        if ply1 == ply2 then
            print(ply1:Nick() .. " injured himself.")
        else
            print(ply1:Nick() .. " injured " .. ply2:Nick() .. ".")
        end

        local hitgroup
        local random
        local dmg_name

        random = math.random(1, 6)
        if random == 1 then
            hitgroup = "Kopf"
        elseif random == 2 then
            hitgroup = "Torso"
        elseif random == 3 then
            hitgroup = "Linker Arm"
        elseif random == 4 then
            hitgroup = "Rechter Arm"
        elseif random == 5 then
            hitgroup = "Linkes Bein"
        elseif random == 6 then
            hitgroup = "Rechtes Bein"
        end

        if dmg_typ ~= -1 then
            for _,i in ipairs(behandlungen["Verletzungen"]) do
                for x,y in ipairs(i["DMG_Typ"]) do
                    if y == dmg_typ and i["kann_erlitten_werden"] then
                        random = math.random(0, 100)
                        if random <= i["warscheinlichkeit"] then
                            dmg_name = i["verletzungs_name"]
                        end
                    end
                end
            end
        else
            dmg_name = "Debug"
        end

        if dmg_name ~= nil and dmg_name ~= "" then
            send_wunde(ply2, hitgroup, dmg_name)
        end
    end
end)

net.Receive("SendOpenConfig", function()
    local ply = net.ReadEntity()

    if ply:IsSuperAdmin() then 
        net.Start("ReciveOpenConfig")
        net.Send(ply)
    end 
end)

hook.Add( "PlayerSpawn", "some_unique_name", function(ply)
    net.Start("ReciveHealPlayer")
    net.Send(ply)

    ply:SetHealth(ply:GetMaxHealth())
end)
--

hook.Add("EntityTakeDamage", "AddInjury", function(target, dmg)
    local hitgroup = ""
    local dmg_name = ""
    local random
    if target:IsPlayer() then
        if target:LastHitGroup() == 1 then
            hitgroup = "Kopf"
        elseif target:LastHitGroup() == 2 or target:LastHitGroup() == 3 then
            hitgroup = "Torso"
        elseif target:LastHitGroup() == 4 then
            hitgroup = "Linker Arm"
        elseif target:LastHitGroup() == 5 then
            hitgroup = "Rechter Arm"
        elseif target:LastHitGroup() == 6 then
            hitgroup = "Linkes Bein"
        elseif target:LastHitGroup() == 7 then
            hitgroup = "Rechtes Bein"
        else
            random = math.random(1, 6)
            if random == 1 then
                hitgroup = "Kopf"
            elseif random == 2 then
                hitgroup = "Torso"
            elseif random == 3 then
                hitgroup = "Linker Arm"
            elseif random == 4 then
                hitgroup = "Rechter Arm"
            elseif random == 5 then
                hitgroup = "Linkes Bein"
            elseif random == 6 then
                hitgroup = "Rechtes Bein"
            end
        end

        for _,i in ipairs(behandlungen["Verletzungen"]) do
            for x,y in ipairs(i["DMG_Typ"]) do
                if y == dmg:GetDamageType() and i["kann_erlitten_werden"] then
                    random = math.random(0, 100)
                    if random <= i["warscheinlichkeit"] then
                        dmg_name = i["verletzungs_name"]
                    end
                end
            end
        end

        if dmg_name ~= nil and dmg_name ~= "" then
            send_wunde(target, hitgroup, dmg_name)
        end
    end
end)

function select_dmg(dmg_typ)
    local random = 0
    for _,i in ipairs(behandlungen["Verletzungen"]) do
        for x,y in ipairs(i["DMG_Typ"]) do
            if y == dmg_typ and i["kann_erlitten_werden"] then
                random = math.random(0, 100)
                if random <= i["warscheinlichkeit"] then
                   return(i["verletzungs_name"] )
                end
            end
        end
    end
end

function send_wunde(ply, region, wunde)
    net.Start("AddWunde")
    net.WriteString(region)
    net.WriteString(wunde)
    net.Send(ply)
end

net.Receive("NidrigeVitalwerte", function()
    local ply = net.ReadEntity()
    ply:Kill()
end)

net.Receive("NormaleVitalwerte", function()
    local ply = net.ReadEntity()
    
    local currentPosition = ply:GetPos()
    
    local weapons = {}
    for _, weapon in pairs(ply:GetWeapons()) do
        weapons[weapon:GetClass()] = {
            ammo1 = ply:GetAmmoCount(weapon:GetPrimaryAmmoType()),
            ammo2 = ply:GetAmmoCount(weapon:GetSecondaryAmmoType())
        }
    end
    
    ply:Spawn()
    
    for class, data in pairs(weapons) do
        local weapon = ply:GetWeapon(class)
        if IsValid(weapon) then
            ply:SetAmmo(data.ammo1, weapon:GetPrimaryAmmoType())
            ply:SetAmmo(data.ammo2, weapon:GetSecondaryAmmoType())
        end
    end
    
    ply:SetPos(currentPosition)
end)

net.Receive("SendStartInteraktion", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()

    net.Start("ReciveStartInteraktion")
    net.WriteEntity(ply1)
    net.Send(ply2)
end)

net.Receive("SendeTable", function()
    local table = net.ReadTable()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()

    net.Start("ReciveTable")
    net.WriteTable(table)
    net.WriteEntity(ply2)
    net.Send(ply1)
end)

net.Receive("SendEndInteraktion", function()
    local ply = net.ReadEntity()

    net.Start("ReciveEndInteraktion")
    net.Send(ply)
end)

net.Receive("SendInteraktion", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()
    local str = net.ReadString()
    local int = net.ReadInt(32)

    net.Start("ReciveInteraktion")
    net.WriteString(str)
    net.WriteEntity(ply2)
    net.WriteInt(int, 32)
    net.Send(ply1)
end)

net.Receive("VerletzungBehandelt", function()
    local ply = net.ReadEntity()
    local int = net.ReadInt(32)

    ply:SetHealth(ply:Health() + ((ply:GetMaxHealth() - ply:Health()) / int))
end)
