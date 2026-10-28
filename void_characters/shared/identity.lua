VoidIdentity = {}

local function trim(value)
    if type(value) ~= 'string' then return nil end
    return (value:match('^%s*(.-)%s*$'):gsub('’', "'"))
end

local function validName(value)
    local count = utf8.len(value)
    if not count or count < Config.Identity.MinNameLength or count > Config.Identity.MaxNameLength then return false end
    -- Latin names, including accents. Reject markup, control chars and other scripts.
    local letters = 0
    for _, cp in utf8.codes(value) do
        local letter = (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122)
            or (cp >= 192 and cp <= 214) or (cp >= 216 and cp <= 246)
            or (cp >= 248 and cp <= 591)
        if letter then
            letters = letters + 1
        elseif cp ~= 32 and cp ~= 39 and cp ~= 45 then
            return false
        end
    end
    return letters >= 2 and not value:match('^[%s%-%\']') and not value:match('[%s%-%\']$')
end

local function leap(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

function VoidIdentity.validate(data, now)
    if type(data) ~= 'table' then return nil, 'Dati identità non validi.' end
    local first, last = trim(data.firstname), trim(data.lastname)
    if not first or #first > 96 or not validName(first) then return nil, 'Nome non valido: usa lettere, spazi, apostrofi o trattini.' end
    if not last or #last > 96 or not validName(last) then return nil, 'Cognome non valido: usa lettere, spazi, apostrofi o trattini.' end
    if type(data.dateofbirth) ~= 'string' then return nil, 'Inserisci la data di nascita.' end
    local y, m, d = data.dateofbirth:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or not m or not d or y < 1900 or m < 1 or m > 12 then return nil, 'Data di nascita non valida.' end
    local days = { 31, leap(y) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if d < 1 or d > days[m] then return nil, 'Data di nascita non valida.' end
    now = now or os.date('!*t')
    local age = now.year - y
    if now.month < m or (now.month == m and now.day < d) then age = age - 1 end
    if age < Config.Identity.MinAge or age > Config.Identity.MaxAge then
        return nil, ('L’età deve essere compresa tra %d e %d anni.'):format(Config.Identity.MinAge, Config.Identity.MaxAge)
    end
    if data.sex ~= 'm' and data.sex ~= 'f' then return nil, 'Seleziona il sesso del personaggio.' end
    local height = tonumber(data.height)
    if not height or height ~= math.floor(height) or height < Config.Identity.MinHeight or height > Config.Identity.MaxHeight then
        return nil, 'Altezza non valida.'
    end
    local nationality = trim(data.nationality)
    local allowed = false
    for _, value in ipairs(Config.Identity.Nationalities) do
        if nationality == value then allowed = true break end
    end
    if not allowed then return nil, 'Seleziona una nazionalità disponibile.' end
    return {
        firstname = first, lastname = last, dateofbirth = data.dateofbirth,
        sex = data.sex, height = height, nationality = nationality
    }
end
