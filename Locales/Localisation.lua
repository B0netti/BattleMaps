local _, BattleMaps = ...
BattleMaps.Locales = BattleMaps.Locales or {}

-- Keep English as the canonical key so missing translations fall back safely.
-- Language overrides affect display only; objective matching uses stable IDs
-- and its original canonical names.
function BattleMaps.GetLanguage(kind)
    local db = _G.BattleMapsDB
    local setting = kind == "chat" and "chatLanguage" or "language"
    local override = type(db) == "table" and db[setting] or nil
    if override == "enUS" or override == "koKR" then return override end
    return type(GetLocale) == "function" and GetLocale() == "koKR" and "koKR" or "enUS"
end

function BattleMaps.L(english, language)
    if type(english) ~= "string" then return english end
    local dictionary = BattleMaps.Locales[language or BattleMaps.GetLanguage()]
    return (dictionary and dictionary[english]) or english
end

-- Use the stable internal node key rather than trying to parse localized UI
-- text back into an objective. The original display/chat fields are untouched.
function BattleMaps.LocalizedNodeName(node, full, language)
    if not node then return "" end
    local canonical = full and (node.display or node.chat) or (node.chat or node.display)
    language = language or BattleMaps.GetLanguage("chat")
    local names = BattleMaps.LocalizedNodes and BattleMaps.LocalizedNodes[language]
    local localized = names and names[node.key]
    if localized then return (full and localized.full) or localized.short or localized.full end
    return tostring(canonical or "")
end
