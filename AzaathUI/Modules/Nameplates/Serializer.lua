--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Serializer.lua
    Exportação e importação de perfis comprimidos em string (!AZNP:1!...).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local type, pcall = type, pcall

local PREFIX = "!AZNP:1!"
NP.EXPORT_PREFIX = PREFIX

local function Encode(tbl)
    local E = _G.C_EncodingUtil
    if not (E and E.SerializeCBOR and E.CompressString and E.EncodeBase64) then
        return nil, "API de codificação indisponível neste cliente."
    end
    local ok, str = pcall(function()
        local cbor = E.SerializeCBOR(tbl)
        local comp = E.CompressString(cbor, _G.Enum.CompressionMethod.Deflate, _G.Enum.CompressionLevel.OptimizeForSize)
        return PREFIX .. E.EncodeBase64(comp)
    end)
    if not ok then return nil, "Falha ao codificar o perfil." end
    return str
end

local function Decode(str)
    if type(str) ~= "string" then return nil, "Nada para importar." end
    str = str:gsub("%s+", "")
    if str:sub(1, #PREFIX) ~= PREFIX then
        return nil, "Esta string não pertence a um perfil de Nameplates do AzaathUI."
    end
    local E = _G.C_EncodingUtil
    if not (E and E.DecodeBase64 and E.DecompressString and E.DeserializeCBOR) then
        return nil, "API de decodificação indisponível neste cliente."
    end
    local ok, data = pcall(function()
        local packed = E.DecodeBase64(str:sub(#PREFIX + 1))
        local cbor = E.DecompressString(packed, _G.Enum.CompressionMethod.Deflate)
        return E.DeserializeCBOR(cbor)
    end)
    if not ok or type(data) ~= "table" then
        return nil, "String corrompida ou incompleta."
    end
    return data
end

function NP.ExportProfile(profileTable, name)
    return Encode({
        kind = "AzaathNameplatesProfile",
        version = 1,
        name = name or "Default",
        addonVersion = Azaath.version,
        profile = profileTable,
    })
end

function NP.ImportProfileString(str)
    local data, err = Decode(str)
    if not data then return nil, err end
    if data.kind ~= "AzaathNameplatesProfile" or type(data.profile) ~= "table" then
        return nil, "A string não contém um perfil válido."
    end
    return data.profile, data.name
end
