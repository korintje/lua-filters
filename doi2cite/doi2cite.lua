--------------------------------------------------------------------------------
-- Copyright © 2021 Takuro Hosomi
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Global variables --
--------------------------------------------------------------------------------
base_url = "http://api.crossref.org"
bibpath = "./from_doi.bib"
str_404 = "Resource not found."
str_503 = "<html><body><h1>503 Service Unavailable</h1>\n"..
        "No server is available to handle this request.\n"..
        "</body></html>"
key_list = {};
doi_key_map = {};
doi_entry_map = {};

--------------------------------------------------------------------------------
-- Pandoc Functions --
--------------------------------------------------------------------------------
-- Get bibliography filepath from yaml metadata
function Meta(m)
    local bp = m.bib_from_doi
    if bp ~= nil then
        if bp[1].text ~= nil then
            bibpath = bp[1].text
        elseif bp[1][1] ~= nil then
            bibpath = bp[1][1].text
        else end
    end
    local f = io.open(bibpath, "r")
    if f then
        entries_str = f:read('*all')
        if entries_str then
            doi_entry_map = get_doi_entry_map(entries_str)
            doi_key_map = get_doi_key_map(entries_str)
            for doi,key in pairs(doi_key_map) do
                key_list[key] = true
            end
        end
        f:close()
    end
end

-- Get bibtex data of doi-based citation.id and make bibliography.
-- Then, replace "citation.id"
function Cite(c)
    for _, citation in pairs(c.citations) do
        local id = citation.id:gsub('%s+', ''):gsub('%%2F', '/')
        if id:sub(1,16) == "https://doi.org/" then
            doi = id:sub(17):lower()
        elseif id:sub(1,8) == "doi.org/" then
            doi = id:sub(9):lower()
        elseif id:sub(1,4) == "DOI:" or id:sub(1,4) == "doi:" then
            doi = id:sub(5):lower()
        else
            doi = nil
        end
        if doi then
            if doi_key_map[doi] ~= nil then
                local entry_key = doi_key_map[doi]
                citation.id = entry_key
            else
                local entry_str = get_bibentry(doi)
                if entry_str == nil or entry_str == str_404 or entry_str == str_503 then
                    print("Failed to get ref from DOI: " .. doi)
                else
                    entry_str = tex2raw(entry_str)
                    local entry_key = get_entrykey(entry_str)
                    if key_list[entry_key] ~= nil then
                        entry_key = entry_key.."_"..doi
                        entry_str = replace_entrykey(entry_str, entry_key)
                    end
                    key_list[entry_key] = true
                    doi_key_map[doi] = entry_key
                    citation.id = entry_key
                    local f = io.open(bibpath, "a+")
                    if f then
                        f:write(entry_str .. "\n")
                        f:close()
                    else
                        error("Unable to open file: "..bibpath)
                    end
                end                
            end
        end
    end
    return c
end


--------------------------------------------------------------------------------
-- Common Functions --
--------------------------------------------------------------------------------
-- Get bib of DOI from http://api.crossref.org
function get_bibentry(doi)
    local entry_str = doi_entry_map[doi]
    if entry_str == nil then
        print("Request DOI: " .. doi)
        local url = base_url.."/works/"..doi.."/transform/application/x-bibtex"
        mt, entry_str = pandoc.mediabag.fetch(url)
    end
    return entry_str
end

-- Make some TeX descriptions processable by citeproc
function tex2raw(string)
    local symbols = {};
    symbols["{\textendash}"] = "–"
    symbols["{\textemdash}"] = "—"
    symbols["{\textquoteright}"] = "’"
    symbols["{\textquoteleft}"] = "‘"
    for tex, raw in pairs(symbols) do
        local string = string:gsub(tex, raw)
    end
    return string
end

-- get bibtex entry key from bibtex entry string
function get_entrykey(entry_string)
    local key = entry_string:match('@%w+{(.-),') or ''
    return key
end

-- get bibtex entry doi from bibtex entry string
function get_entrydoi(entry_string)
    local doi = entry_string:match('doi%s*=%s*["{]*(.-)["}],?') or ''
    return doi
end

-- Replace entry key of "entry_string" to newkey
function replace_entrykey(entry_string, newkey)
    entry_string = entry_string:gsub('(@%w+{).-(,)', '%1'..newkey..'%2')
    return entry_string    
end 

-- Make hashmap which key = DOI, value = bibtex entry string
function get_doi_entry_map(bibtex_string)
    local entries = {};
    for entry_str in bibtex_string:gmatch('@.-\n}\n') do
      local doi = get_entrydoi(entry_str)
      entries[doi] = entry_str
    end
    return entries
end

-- Make hashmap which key = DOI, value = bibtex key string
function get_doi_key_map(bibtex_string)
    local keys = {};
    for entry_str in bibtex_string:gmatch('@.-\n}\n') do
      local doi = get_entrydoi(entry_str)
      local key = get_entrykey(entry_str)
      keys[doi] = key
    end
    return keys
end


--------------------------------------------------------------------------------
-- The main function --
--------------------------------------------------------------------------------
return {
    { Meta = Meta },
    { Cite = Cite }
}