--[[
    SoundConfig - Sound effect IDs for Brainrot Goal Kick Simulator
    All Roblox audio asset IDs for game sounds
]]
local SoundConfig = {}

-- ═══════════════════════════════════════════
-- KICK SOUNDS
-- ═══════════════════════════════════════════
SoundConfig.Kick = {
    kickHit = 1377524158,       -- Ball kick sound
    powerCharge = 6803456370,   -- Power charging up
    powerRelease = 262417082,   -- Power release
}

-- ═══════════════════════════════════════════
-- GOAL / RESULT SOUNDS
-- ═══════════════════════════════════════════
SoundConfig.Result = {
    goal = 5800233480,         -- Goal celebration
    goalFanfare = 1840754568,   -- Big goal fanfare
    saved = 138092513,         -- Keeper saves
    miss = 268243523,          -- Ball goes wide
    bossAppear = 294239089,    -- Boss dramatic entrance
}

-- ═══════════════════════════════════════════
-- UI SOUNDS
-- ═══════════════════════════════════════════
SoundConfig.UI = {
    buttonClick = 876918880,   -- Button click
    buttonHover = 876918880,   -- Button hover (same as click, lighter)
    panelOpen = 6895079853,   -- Panel open swoosh
    panelClose = 6895079853,   -- Panel close
    purchase = 5800233480,     -- Purchase success
    purchaseFail = 138092513,  -- Purchase fail
    coinsClaim = 6803456370,  -- Coins claimed
}

-- ═══════════════════════════════════════════
-- AMBIENT SOUNDS
-- ═══════════════════════════════════════════
SoundConfig.Ambient = {
    zone1 = 1840706998,       -- Calm field ambient
    zone2 = 1840706998,       -- Stadium ambient
    zone3 = 1840706998,       -- Nuclear arena ambient
}

-- ═══════════════════════════════════════════
-- REBIRTH SOUNDS
-- ═══════════════════════════════════════════
SoundConfig.Rebirth = {
    rebirthActivate = 5800233480,  -- Rebirth dramatic sound
}

-- ═══════════════════════════════════════════
-- HELPER: Play a sound at a position or on an object
-- ═══════════════════════════════════════════
function SoundConfig.CreateSound(soundId, parent, volume, playbackSpeed)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. tostring(soundId)
    sound.Volume = volume or 0.5
    sound.PlaybackSpeed = playbackSpeed or 1
    sound.Parent = parent or workspace
    return sound
end

function SoundConfig.PlaySoundId(soundId, parent, volume, playbackSpeed)
    local sound = SoundConfig.CreateSound(soundId, parent, volume, playbackSpeed)
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
    return sound
end

return SoundConfig