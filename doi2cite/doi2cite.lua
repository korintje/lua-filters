--------------------------------------------------------------------------------
-- Copyright © 2021 Takuro Hosomi
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- Global variables --
--------------------------------------------------------------------------------
base_url = "http://api.crossref.org"
bibpath = nil
mailto = nil
key_list = {};
doi_key_map = {};
doi_entry_map = {};
error_strs = {};
error_strs["Resource not found."] = 404
error_strs["No acceptable resource available."] = 406
error_strs["<html><body><h1>503 Service Unavailable</h1>\n"..
    "No server is available to handle this request.\n"..
    "</body></html>"] = 503


--------------------------------------------------------------------------------
-- Pandoc Functions --
--------------------------------------------------------------------------------
-- Get bibliography filepath and user mail info from yaml metadata
function Meta(m)   
    local metainfo = m.doi2cite
    if metainfo then
        -- Get bibliography path for this filter from the metadata
        local _bp = metainfo.bibliography
        if _bp then
            if _bp[1] then
                bibpath = _bp[1].text
            end
        end
        if bibpath == nil then
            error("Bibliography path for doi2cite is not given.")
        end
        -- Get bibliography paths for pandoc citeproc from the metadata
        local _cps = m.bibliography
        local citeproc_bibs = {};
        if _cps then
            if _cps[1].text ~= nil then
                citeproc_bibs[_cps[1].text] = true
            elseif type(_cps) == "table" then
                for _, _cp in pairs(_cps) do
                    citeproc_bibs[_cp[1].text] = true
                end
            end
        end
        if citeproc_bibs[bibpath] == nil then
            print("[doi2cite WARNING]: "
                .."bibliography from DOI may not be processed by citeproc. "
                .."Include '"..bibpath.."' in the citeproc biography list"
            )
        end
        -- Get mail address from the metadata
        local _mt = metainfo.mailto
        if _mt then
            if _mt[1] then
                mailto = _mt[1].text
            end
        end
        if mailto == nil then
            error("Your mail address is not given. "
                .."Set an accessible mail address to the metadata.\n\n"
                .."************Why your mail address is required?************\n"
                .."doi2cite use Crossref REST API provided by http://api.cros\n"
                .."sref.org. The server admins strongly recommend users to pr\n"
                .."ovide an accessible mail address. They may use the mail ad\n"
                .."dress to contact you in case your access causes some probl\n"
                .."ems on the server. If you overload the server (even uninte\n"
                .."ntionally) and the server admin has no way to contact you,\n"
                .." your access to the API may be revoked without notice. Ple\n"
                .."ase keep 'Polite' access to maitain open API. See http://a\n"
                .."pi.crossref.org for the details.\n"
                .."**********************************************************\n"
            )
        end
    else
        error("[doi2cite] Metadata for doi2cite is not given.")    
    end
    -- Open .bib file and collect exsiting bibtex data
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
            if doi_key_map[doi] then
                local entry_key = doi_key_map[doi]
                citation.id = entry_key
            else
                local entry_str = get_bibentry(doi)
                if entry_str == nil or error_strs[entry_str] then
                    print("Failed to get ref from DOI: " .. doi)
                else
                    entry_str = tex2raw(entry_str)
                    local entry_key = get_entrykey(entry_str)
                    if key_list[entry_key] then
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
        print("[doi2cite] Request DOI: " .. doi)
        local url = base_url.."/works/"
            ..doi.."/transform/application/x-bibtex"
            .."?mailto="..mailto
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
