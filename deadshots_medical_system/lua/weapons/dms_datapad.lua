--[[
    DMS - Medizinisches Datapad. Linksklick: Patient unter dem Fadenkreuz
    (Spieler oder Koerper), Rechtsklick: eigener Zustand.
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

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
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
