--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Defaults.lua
    Esquema completo de configurações padrão das placas de nome e perfis.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local pairs, ipairs, type = pairs, ipairs, type

local function UnitDefaults(o)
    local d = {
        mode = "full", -- "full" | "nameOnly" | "blizzard"
        healthWidth = 160, healthHeight = 14, healthOffsetX = 0, healthOffsetY = 0,
        castWidth = 164, castHeight = 11, castOffsetX = 0, castOffsetY = 0,
        useClassColor = false,
        name = {
            enabled = true, font = "Noto Sans SemiBold", size = 12, outline = "OUTLINE", shadow = true,
            color = { 1, 1, 1, 1 }, useClassColor = false,
            anchor = { side = 10, x = 0, y = 2 }, maxWidth = 0, wrap = false, tracked = false,
            playerNames = "both", -- "both" | "first" | "second"
            healthFill = false, fillFollowBar = false, lostColor = { 0.42, 0.42, 0.42, 1 },
            reactionColor = false, reactionTint = false, reputationTint = false,
            attackColor = { 0.92, 0.13, 0.07, 1 },
        },
        guild = {
            enabled = false, font = "Noto Sans", size = 10, outline = "OUTLINE", shadow = true,
            color = { 0.80, 0.80, 0.80, 1 }, anchor = { side = 8, x = 0, y = 2 }, maxWidth = 0,
            hideWhileCasting = false,
            myGuildColorOn = false, myGuildColor = { 0.25, 1, 0.25, 1 },
        },
        healthText = {
            enabled = true, showPercent = true, showValue = false, decimals = false, fullNumbers = false,
            font = "Noto Sans SemiBold", size = 11, outline = "OUTLINE", shadow = true,
            color = { 0.92, 0.92, 0.92, 1 }, anchor = { side = 11, x = -2, y = 0 },
        },
        level = {
            enabled = false, font = "Noto Sans SemiBold", size = 9, outline = "OUTLINE", shadow = true,
            color = { 1, 1, 1, 1 }, anchor = { side = 7, x = 0, y = -1 },
            box = false, boxWidth = 22, boxShape = "square", boxColors = "bar",
            boxBgColor = { 0.10, 0.10, 0.10, 0.90 }, boxBorderColor = { 0, 0, 0, 1 },
            boxBorderSize = 1, boxHeight = 0, boxX = 0, boxY = 0,
            onName = false, nameAnchor = { side = 2, x = -2, y = 0 },
            plainColor = false,
            boxClassBorder = false, boxClassFill = false,
        },
        castName = {
            enabled = true, font = "Noto Sans SemiBold", size = 10, outline = "OUTLINE", shadow = true,
            color = { 1, 1, 1, 1 }, anchor = { side = 3, x = 2, y = 0 },
        },
        castTimer = {
            enabled = true, font = "Noto Sans SemiBold", size = 9, outline = "OUTLINE", shadow = true,
            color = { 1, 1, 1, 1 }, anchor = { side = 11, x = -2, y = 0 },
        },
        castTarget = {
            enabled = true, font = "Noto Sans SemiBold", size = 10, outline = "OUTLINE", shadow = true,
            color = { 0.97, 0.99, 1, 1 }, useClassColor = true, anchor = { side = 5, x = 4, y = 0 },
        },
        castOnYou = {
            enabled = false, text = "onyou", font = "Noto Sans SemiBold", size = 11, outline = "OUTLINE", shadow = true,
            color = { 1, 0.18, 0.12, 1 }, sameAsTarget = true, replaceTarget = true, pulse = true,
            anchor = { side = 5, x = 4, y = 0 },
            glow = { enabled = true, style = "glow", color = { 1, 0.15, 0.10, 1 }, size = 5, alpha = 1, padding = 1, speed = 1 },
        },
        lastSpell = {
            enabled = false, size = 24, gcd = 1.5, linger = 0.5, showName = true, nameSize = 10,
            borderColor = { 0.95, 0.76, 0.31, 1 }, borderSize = 1.5,
            anchor = { side = 6, x = 22, y = 0 },
        },
        unitTarget = {
            enabled = false, font = "Noto Sans", size = 10, outline = "OUTLINE", shadow = true,
            color = { 1, 1, 1, 1 }, useClassColor = true, hideWhileCasting = true, maxWidth = 0,
            anchor = { side = 4, x = 0, y = -3 },
        },
        raidMark    = { enabled = true, size = 20, scale = 1.2, anchor = { side = 8, x = 0, y = 16 } },
        eliteIcon   = { enabled = true, size = 16, showRare = true, flip = false, anchor = { side = 2, x = -2, y = 0 } },
        factionIcon = { enabled = false, size = 18, style = "az", anchor = { side = 2, x = -2, y = 0 } },
        classIcon   = {
            enabled = false, size = 18, anchor = { side = 6, x = 2, y = 0 },
            border = "none", borderSize = 1.5, borderColor = { 0, 0, 0, 1 }, borderClassColor = false,
        },
    }
    if o then
        NP.MergeInto(d, o)
    end
    return d
end

NP.DEFAULTS = {
    debug = false,

    general = {
        enabled = true,
        rpNames = true,
        rpTitle = true,
        utilityNPCs = true,
        hideWorldNames = true,
        hideBlizzardPlates = true,

        nonTargetAlphaEnabled = true,
        nonTargetAlpha = 0.50,
        targetAlpha = 1.0,
        noTargetAlpha = 1.0,
        friendlyNpcNameAlpha = 1.0,
        fadeInstancesOnly = false,
        friendlyNonTargetAlpha = 1.0,
        mouseoverFullAlpha = true,
        softTarget = false,

        combatOnly = false,

        friendlyOnlyFocused = false,
        friendlyOnlyGroup = false,
        friendlyGroupOrHurt = false,
        friendlyNpcImportant = false,
        friendlyNpcHidePets = false,
        friendlyNpcOnlyFocused = false,
        plainTitles = false,
        hideInstanceNPCs = true,
        hideInstancePets = false,
        hideFriendlyResting = false,
        questieSource = false,

        fadeOccluded = false,
        occludedAlpha = 0.40,
        occludedRest = false,
        occludedAlphaRest = 0,

        smallPlates = { enabled = false, scale = 0.72, minor = true, minions = true, dungeonNormal = false, friendlyMinions = false },
        restoreFriendlyPlates = true,
        setClickSize = true,
        clickWidth = 172, clickHeight = 26,
        clickOffsetY = 0, stackOffsetY = 0,
        friendlyClickWidth = 110, friendlyClickHeight = 28,
        stackEnemies = true,
        enemiesOnTop = true,
        debugBoxes = false,
        overlapV = 1.2,
        overlapH = 1.1,
        stackFriendlies = false,
        topInset = 3, bottomInset = 4, motionSpeed = 25,
        autoTopInset = true,
        instanceFriendlies = { azFont = true, outline = "OUTLINE", nameSize = "2", hideRealm = true, classColor = true },
        stackWidthScale = 0.90, stackHeightScale = 1.25,
        stackAuto = false, stackSpacing = 100,
        gameMovement = false,
        friendlyStackWidthScale = 0.87, friendlyStackHeightScale = 1.07,
        globalScale = 1.0,
        targetScale = 1.20,
        distanceScale = { enabled = false, min = 0.80, max = 1.0, fullDist = 10 },
        rangeFade = { enabled = false, alpha = 0.35, target = false, targetAlpha = 0.60, notAttackers = false },
        hideDead = true,
        pixelSnap = true,
        subpixel = true,
        friendlyOnlyHurt = false,
        friendlyFullOnTarget = false,
        friendlyFullWhenHurt = false,
        friendlyHurtNotResting = true,
        friendlyFullInCombat = false,
        friendlyFullGroup = false,
        showOffscreen = false,
        viewDistance = 60,
        screenEdges = "pin",

        applyCVars = true,
        cvars = {
            nameplateMaxDistance = "60",
            nameplatePlayerMaxDistance = "60",
            nameplateTargetBehindMaxDistance = "30",
            nameplateMotion = "1",
            nameplateMotionSpeed = "0.025",
            nameplateOverlapH = "1.1",
            nameplateOverlapV = "1.2",
            nameplateSelectedScale = "1.2",
            nameplateMinScale = "1",
            nameplateMaxScale = "1",
            nameplateLargerScale = "1",
            nameplatePlayerLargerScale = "1",
            nameplateGlobalScale = "1",
            NamePlateHorizontalScale = "1",
            NamePlateVerticalScale = "1",
            NamePlateClassificationScale = "1",
            nameplateOccludedAlphaMult = "0.4",
            nameplateShowAll = "1",
            nameplateShowOffscreen = "0",
            nameplateShowEnemies = "1",
            nameplateShowFriends = "1",
            nameplateShowFriendlyPlayers = "1",
            nameplateShowFriendlyNPCs = "1",
            nameplateShowFriendlyMinions = "1",
            nameplateShowOnlyNameForFriendlyPlayerUnits = "1",
        },
    },

    style = {
        barStyle = "modern", -- "modern" | "azaath" | "azaath_ink" | "bdo" | "bdo_pill"
        font = "Noto Sans SemiBold",
        allFontOn = false, allFont = "Noto Sans SemiBold",
        healthTexture = "AzNP Smooth",
        healthBgTexture = "AzNP Solid",
        healthBgColor = { 0.14, 0.14, 0.16, 0.90 },
        healthBgTextureAlpha = 1,
        healthTextureAlpha = 1,
        smoothText = true, textShadowAlpha = 1, textShadowOffset = 1,
        borderColor = { 0, 0, 0, 1 },
        borderSize = 1.5,
        borderStyle = "pixel", -- "pixel" | "classic"
        corners = { health = "off", cast = "off" }, -- "off" | "slight" | "medium" | "round"
        gradient = { enabled = true, alpha = 0.35 },
        animateHealth = true,
        absorbs = { enabled = false, color = { 1, 1, 1, 0.70 }, texture = "AzNP Smooth", position = "smart" },
        healPrediction = { enabled = false, color = { 0.3, 1, 0.4, 0.55 }, position = "after" },
        execute = {
            enabled = true, auto = true, percent = 20, onlyWithExecute = true,
            width = 2, soft = true,
            color = { 1, 1, 1, 0.55 },
            executeColor = { 1, 0.25, 0.25, 1 },
            zone = false, zoneColor = { 1, 0.25, 0.25, 0.30 },
            killRange = false, killEdgeColor = { 1, 0.25, 0.25, 1 }, killEdgeWidth = 1,
            icon = false, iconSize = 20, iconAnchor = { side = 6, x = 4, y = 0 },
            iconCooldown = false, iconAlways = false, iconCooldownStyle = "both",
            iconSpell = true, iconPulse = true, iconPauseOnCD = false,
            iconGlowStyle = "soft", iconGlowColor = { 1, 0.3, 0.15, 1 },
            onlyEnemies = true,
        },
    },

    units = {
        enemynpc = UnitDefaults(),
        enemyplayer = UnitDefaults({
            healthWidth = 160, healthHeight = 14, castWidth = 164, castHeight = 11,
            useClassColor = true,
            name = { font = "Noto Sans SemiBold", useClassColor = false },
            healthText = { size = 11, showValue = false },
            level = { enabled = false },
            classIcon = { enabled = true, anchor = { side = 2, x = -2, y = 0 }, border = "solid", borderColor = { 1, 0.78, 0, 1 }, borderSize = 1 },
        }),
        friendlyplayer = UnitDefaults({
            mode = "nameOnly",
            castWidth = 160, castHeight = 12, castOnName = false,
            useClassColor = true,
            name = { size = 14, useClassColor = true, anchor = { side = 4, x = 0, y = 0 } },
            healthText = { size = 9, showValue = true, anchor = { side = 9, x = 0, y = 0 } },
            level = { enabled = false, size = 8, anchor = { side = 7, x = 0, y = 1 } },
            classIcon = { enabled = false, size = 18, border = "solid", borderSize = 1 },
        }),
        friendlyplate = UnitDefaults({
            mode = "full",
            castWidth = 160, castHeight = 12,
            useClassColor = true,
            name = { size = 13, useClassColor = true, anchor = { side = 8, x = 0, y = 2 } },
            healthText = { size = 9, showValue = true, anchor = { side = 9, x = 0, y = 0 } },
            level = { enabled = false, size = 8 },
        }),
        friendlynpc = UnitDefaults({
            mode = "nameOnly",
            guild = { enabled = true, color = { 0.90, 0.82, 0.56, 1 }, size = 10 },
            serviceIcon = { enabled = true, size = 20, anchor = { side = 2, x = -4, y = 0 } },
            eliteIcon = { enabled = false, size = 16, showRare = true, anchor = { side = 6, x = 2, y = 0 } },
            castWidth = 160, castHeight = 10,
            name = { size = 12, color = { 0.85, 0.96, 0.82, 1 } },
            healthText = { size = 9, showValue = false },
            level = { enabled = false },
        }),
    },

    colors = {
        debuffColors = { enabled = false, list = {} },
        classColors = NP.GameClassColors(),
        reaction = {
            hostile = { 0.86, 0.16, 0.12, 1 },
            neutral = { 0.93, 0.80, 0.27, 1 },
            friendly = { 0.14, 0.78, 0.22, 1 },
            friendlyPlayerOn = false,
            friendlyPlayer = { 0.20, 0.55, 1, 1 },
        },
        tapped = { 0.62, 0.62, 0.62, 1 },
        reputation = {
            r1 = { 0.80, 0.13, 0.13, 1 }, r2 = { 1, 0.25, 0.20, 1 }, r3 = { 1, 0.50, 0.15, 1 }, r4 = { 0.93, 0.80, 0.27, 1 },
            r5 = { 0.10, 0.82, 0.10, 1 }, r6 = { 0.10, 0.85, 0.60, 1 }, r7 = { 0.20, 0.60, 1, 1 }, r8 = { 0.75, 0.40, 1, 1 },
        },
        nameReaction = {
            enabled = false,
            hostile = { 0.92, 0.13, 0.07, 1 },
            neutral = { 0.93, 0.80, 0.27, 1 },
            friendly = { 0.14, 0.82, 0.14, 1 },
            tapped = { 0.70, 0.70, 0.70, 1 },
        },
        quest = { enabled = true, hostile = { 1, 0.45, 0.05, 1 }, neutral = { 1, 0.70, 0.10, 1 } },
        idle = { enabled = false, mode = "dim", strength = 0.5, color = { 0.42, 0.47, 0.55, 1 }, instancesOnly = true },
        world = {
            enabled = false,
            rare = { enabled = false, color = { 0.82, 0.50, 1, 1 } },
            rareElite = { enabled = false, color = { 0.62, 0.25, 1, 1 } },
            worldBoss = { enabled = false, color = { 1, 0.84, 0, 1 } },
            prey = { enabled = false, color = { 0.10, 1, 0.75, 1 } },
            elite = { enabled = false, color = { 0.35, 0.55, 1, 1 } },
            highLevel = { enabled = false, levels = 3, color = { 0.55, 0.05, 0.05, 1 } },
            battlePet = { enabled = false, color = { 0.55, 0.85, 0.30, 1 } },
            custom = { enabled = false, newColor = { 0, 1, 1, 1 } },
            npcs = {},
        },
        unitType = {
            enabled = true,
            instancesOnly = true,
            boss = { 0.15, 0.25, 1, 1 },
            miniboss = { 0.45, 0.15, 1, 1 },
            elite = { 0.05, 0.80, 0.95, 1 },
            trivial = { 0.50, 0.50, 0.50, 1 },
            enableElite = true,
            enableTrivial = true,
            normalAsTrivial = false,
        },
        caster = {
            enabled = true,
            color = { 0.96, 0.15, 0.80, 1 },
            detectByMana = true,
            detectByCast = false,
            instancesOnly = true,
        },
        threat = {
            enabled = true,
            role = "auto",
            petsAsTanks = true,
            showOn = "border", -- "border" | "halo" | "bar" | "name"
            borderSize = 1.5,
            haloShape = "round",
            haloSize = 3,
            haloAlpha = 0.85,
            instancesOnly = false,
            dps = {
                aggro = { 0.95, 0.16, 0.14, 0.92 },
                pulling = { 1, 0.65, 0.15, 0.85 },
                useTankColor = false,
                tank = { 0.20, 0.85, 0.35, 1 },
                tankKeepSpecial = true,
            },
            tank = {
                noaggro = { 1, 0, 0, 1 },
                pulling = { 1, 1, 0, 1 },
                anothertank = { 1, 0.38, 0.42, 1 },
                useAggroColor = false,
                aggro = { 0.20, 0.85, 0.35, 1 },
                aggroKeepSpecial = false,
            },
        },
    },

    cast = {
        borderSize = 1.0,
        borderColor = { 0, 0, 0, 1 },
        enabled = true,
        hideFriendly = true,
        texture = "AzNP Smooth",
        bgColor = { 0.14, 0.14, 0.16, 0.95 },
        colors = {
            cast = { 0.95, 0.65, 0.12, 1 },
            channel = { 0.18, 0.55, 1, 1 },
            important = { 1, 0.24, 0.05, 1 },
            nointerrupt = { 0.55, 0.55, 0.60, 0.85 },
            interrupted = { 0.92, 0.15, 0.12, 1 },
            finished = { 0.20, 0.90, 0.30, 1 },
        },
        useImportantColor = true,
        showInterrupter = false,
        interrupterClassColor = true,
        spark = { enabled = true, style = "soft", width = 10, height = 2.0, color = { 1, 1, 0.96, 1 }, alpha = 1, offsetX = 0 },
        fadeOutTime = 0.28,
        interruptedHold = 0.38,
        showIcon = true,
        icon = { side = "LEFT", size = 0, offsetX = 0, offsetY = 0, tall = false, border = true, borderColor = { 0, 0, 0, 1 } },
        importantDots = { enabled = true, style = "ants", color = { 1, 0.92, 0.45, 1 }, size = 2, alpha = 1, padding = 2.5, speed = 1, dash = 6, gap = 4 },
        kick = {
            enabled = true,
            mode = "border", -- "border" | "bar" | "both"
            borderMode = true,
            fullBarMode = false,
            readyColor = { 0.15, 1, 0.15, 1 },
            cooldownColor = { 1, 0.10, 0.10, 0.65 },
            cooldownColorEnabled = false,
            noInterruptColor = { 0, 0, 0, 1 },
            baseBorderColor = { 1, 1, 1, 1 },
            borderSize = 1.8,
            tick = { enabled = true, color = { 0.15, 1, 0.20, 1 }, width = 2.5 },
            healthBar = false,
            customSpellID = 0,
        },
    },

    playerPower = {
        enabled = false, onlyAttackable = true, onlyInCombat = false,
        width = 0, height = 6,
        anchor = { side = 4, x = 0, y = -2 },
        texture = "AzNP Smooth",
        bgColor = { 0.05, 0.05, 0.05, 0.85 },
        border = true, borderSize = 1, borderColor = { 0, 0, 0, 1 },
        typeColor = true, color = { 0.18, 0.48, 1, 1 },
        text = "none", textSize = 8, textColor = { 1, 1, 1, 1 },
    },

    playerHealth = {
        enabled = false, onlyAttackable = true, onlyInCombat = false,
        attach = "cast",
        width = 0, height = 10,
        anchor = { side = 4, x = 0, y = -12 },
        texture = "AzNP Ridge",
        bgColor = { 0.10, 0.10, 0.10, 0.90 },
        border = true, borderSize = 1, borderColor = { 0, 0, 0, 1 },
        colorMode = "custom", color = { 0.20, 0.85, 0.30, 1 },
        text = "none", textSize = 8, textColor = { 1, 1, 1, 1 },
    },

    classResources = {
        enabled = false, onlyAttackable = true, onlyInCombat = false,
        castInFront = false,
        anchor = { side = 4, x = 0, y = -18 },
        width = 18, height = 5, spacing = 2,
        matchHealthWidth = false,
        texture = "AzNP Solid",
        emptyColor = { 0.10, 0.10, 0.10, 0.80 },
        border = true, borderSize = 1, borderColor = { 0, 0, 0, 1 },
        rechargeAlpha = 0.50,
        style = "themed", -- "game" | "bars" | "classic" | "themed" | "gems" | "orbs" | ...
        gameSize = 14, gameSpacing = 2, gameTint = false,
        mfSize = 11, mfWidth = 1, mfSpacing = 2,
        mfSlotColor = { 1, 1, 1, 1 },
        mfShine = true, mfGlow = true, mfGlowStrength = 0.70, mfPop = true,
        shadow = true, shadowAlpha = 0.85, shadowSize = 1.8,
        colors = {
            holyPower = { 0.95, 0.90, 0.60, 1 },
            comboPoints = { 1, 0.96, 0.41, 1 },
            comboPointsDruid = { 1, 0.20, 0.10, 1 },
            charged = { 0.25, 0.65, 1, 1 },
            runesBlood = { 0.85, 0.15, 0.20, 1 },
            runesFrost = { 0.30, 0.65, 1, 1 },
            runesUnholy = { 0.40, 0.85, 0.25, 1 },
            runes = { 0.60, 0.60, 0.65, 1 },
            chi = { 0.71, 1, 0.92, 1 },
            arcaneCharges = { 0.45, 0.60, 1, 1 },
            soulShards = { 0.62, 0.45, 0.95, 1 },
            essence = { 0.35, 0.85, 0.85, 1 },
        },
    },

    auras = {
        enabled = true,
        hideForFriendly = true,
        custom = { include = {}, exclude = {}, includeFromAnyone = false },
        font = "Noto Sans SemiBold",
        debuffs = {
            enabled = true, onlyMine = false, onlyImportant = false,
            pandemic = {
                enabled = true, style = "glow", color = { 1, 0.08, 0.05, 1 },
                thickness = 1.5, speed = 1, padding = 0.5, size = 3, colorTimer = true,
            },
            width = 20, height = 18, perRow = 6, max = 10, spacing = 1,
            anchor = { side = 8, x = 0, y = 18 },
            grow = "CENTER", sort = "duration",
        },
        buffs = {
            enabled = true, showDispellable = true, showEnrage = true, showImportant = true, showAll = false,
            maxDuration = 0,
            highlight = {
                style = "ants",
                purge = { enabled = true, color = { 0.20, 0.70, 1, 1 } },
                enrage = { enabled = true, color = { 1, 0.15, 0.05, 1 } },
                size = 2, strength = 1, pulse = false,
                antsThickness = 1.5, antsSpeed = 1, antsPadding = 0.5,
            },
            width = 20, height = 18, perRow = 3, max = 6, spacing = 1,
            anchor = { side = 8, x = 0, y = 38 },
            grow = "CENTER", sort = "default",
            stacks = {
                enabled = true, sameAsDebuffs = true,
                font = "Noto Sans SemiBold", size = 14, outline = "OUTLINE", color = { 1, 0.80, 0.10, 1 },
                anchor = { side = 8, x = -6, y = -6 },
            },
        },
        friendDebuffs = {
            enabled = false, onlyDispellable = true,
            width = 18, height = 16, perRow = 4, max = 4, spacing = 1,
            anchor = { side = 1, x = 0, y = 2 },
            grow = "RIGHT", sort = "duration",
        },
        friendBuffs = {
            enabled = false,
            width = 18, height = 16, perRow = 5, max = 5, spacing = 1,
            anchor = { side = 2, x = -2, y = -4 },
            grow = "LEFT", sort = "duration",
        },
        cc = {
            enabled = true,
            width = 22, height = 18, max = 3, spacing = 1,
            anchor = { side = 6, x = 8, y = 0 },
            grow = "RIGHT", sort = "default",
            borderColor = { 0, 0.65, 1, 1 },
        },
        timer = {
            enabled = true, font = "Noto Sans SemiBold", size = 10, outline = "OUTLINE", color = { 1, 1, 1, 1 },
            anchor = { side = 9, x = 0, y = 0 }, external = false, externalTimers = false,
        },
        stacks = {
            enabled = true, font = "Noto Sans SemiBold", size = 12, outline = "OUTLINE", color = { 1, 0.82, 0.20, 1 },
            anchor = { side = 8, x = -5, y = -6 },
        },
        borderSize = 1,
        borderColor = { 0, 0, 0, 1 },
        borderByDispelType = true,
        swipe = true,
        reverseSwipe = true,
        tooltips = true,
    },

    indicators = {
        targetBorder  = { enabled = true, color = { 1, 0.82, 0.25, 1 }, size = 1.5, classColor = false, threatColor = false },
        focusBorder   = { enabled = true, color = { 0, 0.95, 0.90, 1 }, classColor = false },
        focusOverlay  = { enabled = false, texture = "edges", color = { 0.10, 0.85, 1, 0.35 }, size = 10, additive = false },
        targetGlow    = {
            enabled = true, glowOn = true, marksOn = true, style = "arrows", arrowMotion = false,
            color = { 1, 0.80, 0.20, 1 }, size = 4, alpha = 0.85, padding = 1, speed = 1, dash = 6, gap = 4,
            glowW = 0, glowH = 0, markW = 0, markH = 0, markOffset = 0,
            withGlow = true, glowSize = 2, glowColor = { 1, 0.78, 0.15, 1 }, glowShape = "square",
            classColor = false, glowClassColor = false, glowThreat = false,
        },
        targetOverlay = { enabled = false, color = { 1, 0.96, 0.82, 1 }, alpha = 0.14 },
        hover         = { enabled = true, alpha = 0.14, nameOnly = false },
        raidMark      = { enabled = true, size = 20, scale = 1.2, anchor = { side = 8, x = 0, y = 16 } },
        quest         = { enabled = true, byType = true, size = 16, anchor = { side = 2, x = -2, y = 0 } },
        questText     = { enabled = true, font = "Noto Sans SemiBold", size = 10, outline = "OUTLINE", shadow = true, color = { 1, 0.72, 0.15, 1 }, anchor = { side = 4, x = 0, y = -2 } },
        idleIcon      = { enabled = false, instancesOnly = true, size = 16, anchor = { side = 6, x = 2, y = 0 } },
        threatText    = { enabled = false, mode = "lead", font = "Noto Sans SemiBold", size = 10, outline = "OUTLINE", shadow = true, colorByThreat = true, colorStyle = "states", color = { 1, 1, 1, 1 }, anchor = { side = 7, x = 0, y = 2 } },
        typeIcon      = {
            enabled = false, instancesOnly = false, size = 18,
            boss = true, miniboss = true, caster = true, elite = true, ownColors = false,
            colors = { boss = { 1, 0.25, 0.20, 1 }, miniboss = { 0.65, 0.45, 1, 1 }, caster = { 1, 0.35, 0.90, 1 }, elite = { 1, 0.82, 0, 1 } },
            anchor = { side = 7, x = 4, y = -4 },
        },
    },

    extras = {
        castHighlight = { enabled = true, importantOnly = false },
        dotKill       = { enabled = true, color = { 1, 0.85, 0.20, 0.40 }, icon = true, iconSize = 16, iconPos = "right" },
        mplus         = { enabled = true, font = "Noto Sans SemiBold", size = 10, outline = "OUTLINE", color = { 1, 0.87, 0.10, 1 }, offsetX = 0, offsetY = -2, decimals = 2, mode = "percent", hideWhileCasting = true, preview = false },
        bossEnergy    = { enabled = true, height = 6, insetX = 20, offsetY = -3, fillColor = { 1, 0.78, 0, 1 }, bgColor = { 0.10, 0.10, 0.10, 0.75 }, borderColor = { 0, 0, 0, 1 }, borderSize = 1, texture = "AzNP Ridge", text = true, textSize = 9, textColor = { 1, 1, 1, 1 }, textFormat = "both", font = "Noto Sans SemiBold", textOutline = "OUTLINE", textOffsetX = 0, textOffsetY = 0, hideWhileCasting = true, miniboss = false, preview = false },
    },
}

do
    local u = NP.DEFAULTS.units
    u.friendlynpc.name.petColorOn = false
    u.friendlynpc.name.petColor = { 0.50, 0.78, 1, 1 }
    u.friendlynpc.guild.hidePets = false
    for _, k in ipairs({ "friendlyplayer", "friendlyplate" }) do
        u[k].name.friendColorOn = false
        u[k].name.friendColor = { 1, 0.82, 0.25, 1 }
        u[k].name.guildColorOn = false
        u[k].name.guildColor = { 0.25, 1, 0.45, 1 }
        u[k].name.partyColorOn = false
        u[k].name.socialOnBar = false
        u[k].name.partyColor = { 0.67, 0.67, 1, 1 }
    end
    u.npcplate = NP.CopyTable(u.friendlynpc)
    u.npcplate.mode = "full"

    u.enemynpc.nameOnlyUntilCombat = false
    u.enemynpc.nameOnlyHostileOnly = false
    u.enemyplayer.nameOnlyUntilCombat = false
    for _, k in ipairs({ "enemynpc", "enemyplayer" }) do
        u[k].castFullPlate = false
        u[k].castFullNotResting = true
        u[k].nameOnlyNotInstances = false
        u[k].combatName = {
            own = false, nameSize = 12, nameX = 0, nameY = 0, nameColorMode = "same", nameColor = { 1, 1, 1, 1 },
            eliteShow = true, eliteSize = 14, eliteAnchor = { side = 2, x = -2, y = 0 },
            levelShow = false, levelSize = 10, levelAnchor = { side = 6, x = 3, y = 0 },
        }
    end
    for base, ooc in pairs(NP.OOC_OF) do
        u[ooc] = NP.CopyTable(u[base])
        u[ooc].nameOnlyUntilCombat = nil
        u[ooc].castFullPlate, u[ooc].castFullNotResting = nil, nil
        u[ooc].nameOnlyNotInstances, u[ooc].nameOnlyHostileOnly = nil, nil
        if u[ooc].raidMark then u[ooc].raidMark.anchor = { side = 8, x = 0, y = 2 } end
        NP.DEFAULTS.unitOverrides = NP.DEFAULTS.unitOverrides or {}
        NP.DEFAULTS.unitOverrides[ooc] = { indicators = { quest = { anchor = { side = 6, x = 3, y = 0 } } } }
    end
    NP.DEFAULTS.unitOverrides = NP.DEFAULTS.unitOverrides or {}
    for _, kind in ipairs({ "friendlyplayer", "friendlyplate" }) do
        NP.DEFAULTS.unitOverrides[kind] = { auras = { cc = { enabled = false } } }
    end
end

-- Gerenciamento de perfis + migração segura a partir de AzaathUIDB.nameplates
function NP.InitDatabase()
    local root = AzaathUIDB
    if type(root) ~= "table" then return end
    root.npProfiles = root.npProfiles or {}
    if not root.npProfiles.Default then
        root.npProfiles.Default = NP.CopyTable(NP.DEFAULTS)
    else
        -- garante chaves novas em perfis antigos
        local function FillMissing(dst, src)
            for k, v in pairs(src) do
                if dst[k] == nil then
                    dst[k] = NP.CopyTable(v)
                elseif type(v) == "table" and type(dst[k]) == "table" then
                    FillMissing(dst[k], v)
                end
            end
        end
        FillMissing(root.npProfiles.Default, NP.DEFAULTS)
    end

    local charKey = (_G.UnitName and _G.UnitName("player") or "Player") .. "-" .. (_G.GetRealmName and _G.GetRealmName() or "Realm")
    root.npCharProfile = root.npCharProfile or {}
    local activeName = root.npCharProfile[charKey] or "Default"
    if not root.npProfiles[activeName] then activeName = "Default" end
    root.npCharProfile[charKey] = activeName

    NP.activeProfileName = activeName
    NP.charKey = charKey
    NP.db = root.npProfiles[activeName]

    -- Migra opções simples herdadas de Azaath.db.nameplates na 1ª execução
    local legacy = Azaath.db and Azaath.db.nameplates
    if legacy and not NP.db._migratedFromLegacy then
        NP.db._migratedFromLegacy = true
        NP.db.general.enabled = legacy.enabled ~= false
        NP.db.general.utilityNPCs = legacy.utilityNPCs ~= false
        NP.db.general.hideWorldNames = legacy.hideWorldNames ~= false
        if legacy.style == "azaath" then
            NP.ApplyBarStylePreset("azaath", true)
        elseif legacy.style == "zerker" then
            NP.ApplyBarStylePreset("bdo", true)
        elseif legacy.style == "minimal" then
            NP.ApplyBarStylePreset("bdo_pill", true)
        elseif legacy.style == "blizzard" then
            NP.db.style.barStyle = "modern"
        end
        if legacy.width and legacy.width >= 80 then
            NP.db.units.enemynpc.healthWidth = legacy.width
            NP.db.units.enemynpc.castWidth = legacy.width + 4
        end
        if legacy.castBar == false then
            NP.db.cast.enabled = false
        end
    end

    if not NP.db._v2TargetFix and NP.db.indicators then
        NP.db._v2TargetFix = true
        if NP.db.indicators.targetOverlay then
            NP.db.indicators.targetOverlay.enabled = false
            NP.db.indicators.targetOverlay.alpha = 0.14
        end
        if NP.db.indicators.targetGlow then
            NP.db.indicators.targetGlow.glowShape = "square"
            NP.db.indicators.targetGlow.glowSize = 2
        end
    end

    if not NP.db._v3SkinVisualsFix then
        NP.db._v3SkinVisualsFix = true
        if NP.db.style and NP.db.style.absorbs then
            NP.db.style.absorbs.enabled = false
        end
        if type(NP.db.unitOverrides) == "table" then
            for _, ov in pairs(NP.db.unitOverrides) do
                if type(ov) == "table" then ov.style = nil end
            end
        end
        if NP.db.auras then
            if NP.db.auras.debuffs then
                NP.db.auras.debuffs.anchor = { side = 8, x = 0, y = 18 }
                NP.db.auras.debuffs.grow = "CENTER"
            end
            if NP.db.auras.buffs then
                NP.db.auras.buffs.anchor = { side = 8, x = 0, y = 38 }
                NP.db.auras.buffs.grow = "CENTER"
            end
            if NP.db.auras.cc then
                NP.db.auras.cc.anchor = { side = 6, x = 22, y = 0 }
            end
        end
        NP.ApplyBarStylePreset(NP.db.style and NP.db.style.barStyle or "azaath_ink", true)
    end
    if not NP.db._v4HoverFix and NP.db.indicators and NP.db.indicators.hover then
        NP.db._v4HoverFix = true
        NP.db.indicators.hover.alpha = 0.14
    end
    if not NP.db._v5AggroBorderFix and NP.db.colors and NP.db.colors.threat then
        NP.db._v5AggroBorderFix = true
        NP.db.colors.threat.showOn = "border"
        NP.db.colors.threat.borderSize = 1.5
        if NP.db.colors.threat.dps then
            NP.db.colors.threat.dps.aggro = { 0.95, 0.16, 0.14, 0.92 }
        end
    end
    if not NP.db._v6NoStripesFix then
        NP.db._v6NoStripesFix = true
        if NP.db.indicators and NP.db.indicators.focusOverlay then
            NP.db.indicators.focusOverlay.enabled = false
            NP.db.indicators.focusOverlay.texture = "edges"
        end
        if NP.db.style then
            if NP.db.style.absorbs then NP.db.style.absorbs.texture = "AzNP Smooth" end
            if NP.db.style.healthBgTexture == "Azaath Hachurado" then NP.db.style.healthBgTexture = "Azaath Mancha" end
        end
    end
    -- Corrige qualquer cor que tenha ficado com alpha baixo (< 0.5) pelo ColorPicker
    local function FixColorAlpha(tbl)
        if type(tbl) ~= "table" then return end
        if type(tbl[1]) == "number" and type(tbl[2]) == "number" and type(tbl[3]) == "number" then
            if type(tbl[4]) == "number" and tbl[4] < 0.5 then tbl[4] = 1 end
            return
        end
        for k, v in pairs(tbl) do
            if k ~= "healthBgColor" and k ~= "bgColor" and type(v) == "table" then
                FixColorAlpha(v)
            end
        end
    end
    if NP.db.colors then FixColorAlpha(NP.db.colors) end
    if NP.db.indicators then FixColorAlpha(NP.db.indicators) end
    if NP.db.unitOverrides then FixColorAlpha(NP.db.unitOverrides) end
    if not NP.db._v7SoftTargetFix and NP.db.general then
        NP.db._v7SoftTargetFix = true
        NP.db.general.softTarget = false
    end

    NP.InvalidateUnitProfiles()
end

-- Predefinições de estilo de barra (integra as skins existentes do AzaathUI às novas regras)
NP.BAR_STYLES = {
    modern     = "Moderno (Padrão)",
    azaath     = "Azaath Clássico (Moldura + Losango)",
    azaath_ink = "Azaath Tinta (Pincel + Losango)",
    bdo        = "Zerker (Paralelogramo BDO)",
    bdo_pill   = "Minimalista (Pílula BDO)",
}
NP.BAR_STYLE_ORDER = { "modern", "azaath", "azaath_ink", "bdo", "bdo_pill" }

function NP.ApplyBarStylePreset(styleKey, silent)
    if not NP.db then return end
    if type(NP.db.unitOverrides) == "table" then
        for _, ov in pairs(NP.db.unitOverrides) do
            if type(ov) == "table" then ov.style = nil end
        end
    end
    local st = NP.db.style
    local ind = NP.db.indicators
    local en = NP.db.units.enemynpc
    local ep = NP.db.units.enemyplayer
    st.barStyle = styleKey
    en.name = en.name or {}
    ep.name = ep.name or {}
    if styleKey == "azaath" or styleKey == "azaath_ink" then
        st.healthTexture = (styleKey == "azaath_ink") and "Azaath Tinta" or "Azaath Clássico"
        st.healthBgTexture = "Azaath Mancha"
        st.healthBgColor = { 1, 1, 1, 0.92 }
        st.borderStyle = "pixel"
        st.borderSize = 0
        st.corners.health = "off"
        st.gradient.enabled = false
        st.font = "Cinzel Bold"
        ind.targetBorder.enabled = false
        ind.targetGlow.glowOn = false
        ind.targetGlow.marksOn = false
        en.healthWidth = 114
        en.healthHeight = (styleKey == "azaath_ink") and 6 or 7
        en.name.font = "Cinzel"
        en.name.size = 11
        en.name.tracked = true
        en.name.anchor = { side = 8, x = 0, y = 4 }
        en.healthText.enabled = false
        en.level.enabled = true
        en.level.box = false
        ep.name.font = "Cinzel"
        ep.name.tracked = true
    elseif styleKey == "bdo" then
        st.healthTexture = "BDO Barra"
        st.healthBgTexture = "BDO Fundo"
        st.healthBgColor = { 1, 1, 1, 0.95 }
        st.borderStyle = "pixel"
        st.borderSize = 0
        st.corners.health = "off"
        st.gradient.enabled = false
        st.font = "Noto Sans SemiBold"
        ind.targetBorder.enabled = false
        ind.targetGlow.glowOn = false
        ind.targetGlow.marksOn = false
        en.healthWidth = 114
        en.healthHeight = 10
        en.name.font = "Noto Sans SemiBold"
        en.name.size = 11
        en.name.tracked = false
        en.name.anchor = { side = 8, x = 0, y = 4 }
        en.healthText.enabled = false
        en.level.enabled = false
        ep.name.tracked = false
    elseif styleKey == "bdo_pill" then
        st.healthTexture = "BDO Pílula"
        st.healthBgTexture = "BDO Trilho"
        st.healthBgColor = { 1, 1, 1, 0.95 }
        st.borderStyle = "pixel"
        st.borderSize = 0
        st.corners.health = "off"
        st.gradient.enabled = false
        st.font = "Noto Sans SemiBold"
        ind.targetBorder.enabled = false
        ind.targetGlow.glowOn = false
        ind.targetGlow.marksOn = false
        en.healthWidth = 92
        en.healthHeight = 5
        en.name.font = "Noto Sans SemiBold"
        en.name.size = 12
        en.name.tracked = false
        en.name.anchor = { side = 8, x = 0, y = 3 }
        en.healthText.enabled = false
        en.level.enabled = false
        ep.name.tracked = false
    else -- "modern"
        st.healthTexture = "AzNP Smooth"
        st.healthBgTexture = "AzNP Solid"
        st.healthBgColor = { 0.14, 0.14, 0.16, 0.90 }
        st.borderStyle = "pixel"
        st.borderSize = 1.5
        st.corners.health = "off"
        st.gradient.enabled = true
        st.font = "Noto Sans SemiBold"
        ind.targetBorder.enabled = true
        ind.targetGlow.glowOn = true
        ind.targetGlow.glowShape = "square"
        ind.targetGlow.glowSize = 2
        ind.targetGlow.marksOn = true
        en.healthWidth = 160
        en.healthHeight = 14
        en.name.font = "Noto Sans SemiBold"
        en.name.size = 12
        en.name.tracked = false
        en.name.anchor = { side = 10, x = 0, y = 2 }
        en.healthText.enabled = true
        en.level.enabled = false
        ep.name.tracked = false
    end
    NP.InvalidateUnitProfiles()
    if not silent and NP.RefreshAll then
        NP.RefreshAll()
    end
end
