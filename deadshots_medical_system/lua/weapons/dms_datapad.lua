--[[
    DMS - Medizinisches Datapad. Linksklick: Patient unter dem Fadenkreuz
    (Spieler oder Koerper), Rechtsklick: eigener Zustand. Modelle aus den
    Einstellungen (datapad_viewmodel/_worldmodel/_usehands, Konfiguration
    "Steuerung und Datapad").
]]

AddCSLuaFile()

SWEP.PrintName = "Medical Datapad"
SWEP.Author = "Deadshot"
SWEP.Category = "Deadshot's Medical System"
SWEP.Instructions = "LMB: examine patient, RMB: examine yourself"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.ViewModel = "models/weapons/c_medkit.mdl"
SWEP.WorldModel = "models/weapons/w_medkit.mdl"
SWEP.UseHands = true
SWEP.HoldType = "slam"
SWEP.Slot = 5
SWEP.SlotPos = 3
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

-- Modelle aus den Einstellungen (beim Erzeugen und beim Ziehen)
function SWEP:DMSApplyModels()
    if not DMS or not DMS.Get then return end
    local vm, wm = DMS.Get("datapad_viewmodel"), DMS.Get("datapad_worldmodel")
    if isstring(vm) and vm ~= "" then self.ViewModel = vm end
    if isstring(wm) and wm ~= "" and self.WorldModel ~= wm then
        self.WorldModel = wm
        self:SetModel(wm)
    end
    self.UseHands = DMS.Get("datapad_usehands") ~= false
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:DMSApplyModels()
end

-- Beim Ziehen: Modelle aus den Einstellungen und die Zieh-Animation (ohne
-- Animation steht das View-Modell in der Grundpose - nur ein Arm im Bild)
function SWEP:Deploy()
    self:DMSApplyModels()
    self:SendWeaponAnim(ACT_VM_DRAW)
    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.5)
    if CLIENT and IsFirstTimePredicted() then DMS.OpenLookedAt() end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
    if CLIENT and IsFirstTimePredicted() then DMS.OpenPatient(self:GetOwner()) end
end

function SWEP:Reload() end
