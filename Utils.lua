--[[----------------------------------------------------------------------------

Utils.lua
Common code for Lightroom plugins

------------------------------------------------------------------------------]]
local Info = require 'Info'
local logger = import 'LrLogger'( 'Stash' )
local LrApplication = import 'LrApplication'
local LrErrors = import 'LrErrors'
local LrFileUtils = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrHttp = import 'LrHttp'
local LrMD5 = import 'LrMD5'
local LrPathUtils = import 'LrPathUtils'
local LrPathUtils = import 'LrPathUtils'
local LrStringUtils = import 'LrStringUtils'
local LrSystemInfo = import 'LrSystemInfo'
local LrTasks = import 'LrTasks'

local prefs = import 'LrPrefs'.prefsForPlugin()
local JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

--------------------------------------------------------------------------------

Utils = {}
--------------------------------------------------------------------------------
-- variation of http://forums.adobe.com/message/3146133#3146133
function Utils.logTable(x, label)
    local function dump1 (x, indent, visited)
        if type (x) ~= "table" then
            if type(x) == "number" then
                logger:info (string.rep (" ", indent) ..  LrStringUtils.numberToString(x))
            else
                logger:info (string.rep (" ", indent) .. tostring (x))
            end
            return
        end

        visited [x] = true
        if indent == 0 then
            logger:info (string.rep (" ", indent) .. tostring (x))
        end
        for k, v in pairs (x) do
            if type(v) == "number" then
                logger:info (string.rep (" ", indent + 4) .. tostring (k) .. " = " .. LrStringUtils.numberToString(v))
            else
                logger:info (string.rep (" ", indent + 4) .. tostring (k) .. " = " .. tostring (v))
            end
            if type (v) == "table" and not visited [v] then
                dump1 (v, indent + 4, visited)
            end
        end
    end

    if label ~= nil then
        logger:info (label .. ":")
    end

    dump1 (x, 0, {})
end

--------------------------------------------------------------------------------

function Utils.md5Files(path)

    local digests = {}
    for filePath in LrFileUtils.recursiveFiles( path ) do
        local file = assert(io.open(filePath, "rb"))
        local data = file:read("*all")
        assert(file:close())

        local md5sum = LrMD5.digest(data)
        digests[LrPathUtils.makeRelative(filePath, path)] = md5sum
    end

    return digests
end

--------------------------------------------------------------------------------

function Utils.getJSON(url)
    data, headers = Utils.postUrl(url)

    -- We're assuming that the remote system has returned JSON - this is getJSON after all.
    local validJSON, decode = LrTasks.pcall(function() return JSON:decode(data) end)

    -- If the JSON parsing failed, check if the server returned an error, or it's a problem with the encoding.
    if not validJSON then
        local error_message = nil
        if Utils.isServerError(headers) then
            error_message = string.format("Encountered error %d downloading %s, no valid JSON recieved, terminating",
                                                headers.status,
                                                url)
        else
            error_message = string.format("JSON decoding error encountered from URL %s, terminating", url)
        end
        logger:error(error_message)
        Utils.logTable(headers)
        if data ~= nil then
            logger:info(string.format("Data recieved: %s", data))
        end
        error(error_message)

    else
        return decode
    end

end

--------------------------------------------------------------------------------
function Utils.getUrl(url)
    data, headers = LrHttp.get(url)
    if Utils.isLightroomError(headers) then
        logger:error(string.format("Lightroom had a problem GETing %s", url))
        local error_headers = Utils.getLightroomError(headers)
        Utils.logTable(error_headers)
        error(error_headers.message)
    else
        return data, headers
    end
end

function Utils.postUrl(url)
    data, headers = LrHttp.post(url, "")
    if Utils.isLightroomError(headers) then
        logger:error(string.format("Lightroom had a problem POSTing to %s", url))
        local error_headers = Utils.getLightroomError(headers)
        Utils.logTable(error_headers)
        error(error_headers.message)
    else
        return data, headers
    end
end


function Utils.getFile(url, path)
    data, headers = Utils.getUrl(url)

    if Utils.isServerError(headers) then
        local error_message = string.format("Encountered error %d downloading %s, terminating", headers.status, url)
        logger:error(error_message)
        Utils.logTable(headers)
        if data ~= nil then
            logger:info(string.format("Data recieved: %s", data))
        end
        error(error_message)
        end
    end

    local path = LrPathUtils.standardizePath(path)

    if LrPathUtils.isRelative(path) then
        path = LrPathUtils.makeAbsolute(path, _PLUGIN.path)
    end

    if LrFileUtils.exists(path) then
        path = LrFileUtils.chooseUniqueFileName(path)
    end

    if LrFileUtils.isWritable(path) or (not LrFileUtils.exists(path))then
        local out = assert(io.open(path, "wb"))
        out:write(data)
        assert(out:close())
        return path

    else
        logger:info(string.format("Path %s isn't writable.", path))
        return nil
    end

end

--------------------------------------------------------------------------------

-- Takes a particular file, and moves it to file.backup.1.
-- If file.backup.1 exists, move the existing file.backup.1 to file.backup.2
-- and move file.backup.1 to file.backup.2
-- Same for 2.
-- Recursive!
function Utils.makeBackups(file, iteration)
    local srcPath = nil
    if LrPathUtils.isRelative(file) then
        srcPath = LrPathUtils.makeAbsolute(file, _PLUGIN.path)
    else
        srcPath = file
    end

    local destPath = LrPathUtils.replaceExtension(srcPath, "backup" .. (iteration + 1))

    if iteration > 2 then
        logger:info("Terminating at iteration 3. Deleting file " .. file)
        LrFileUtils.moveToTrash(srcPath)
        return nil
    end

    if LrFileUtils.exists(destPath) then
        logger:info("Moving to iteration " .. (iteration + 1) .. " for file " .. destPath)
        Utils.makeBackups(destPath,(iteration + 1))
    end

    logger:info("Moving " .. srcPath .. " to " .. destPath)
    local ok, message = LrFileUtils.move(srcPath, destPath)
    if not ok then
        logger:error(message)
    end

end

--------------------------------------------------------------------------------

function Utils.networkComms( action, url )

    logger:info("Utils.networkComms: Called for " .. url)
    local payload, headers = nil
    -- Do the request
    if action == "post" then
        payload, headers = LrHttp.post(url, "")
    else
        payload, headers = LrHttp.get(url)
    end

    return Utils.checkResponse( payload, headers, url )

end
--------------------------------------------------------------------------------

function Utils.isLightroomError(headers)
    -- Lightroom errors are signified by having .error set to true
    if headers and headers.error then
        return true
    else
        return false
    end
end

function Utils.getLightroomError(headers)
    if Utils.isLightroomError(headers) then
        local error_message = string.format("There was a problem getting %s. \nLightroom had a problem:\n %s - %s",
                                    url,
                                    headers.error.errorCode,
                                    headers.error.name or "")
        return {code = headers.error.errorCode,
                description = headers.error.name or "",
                message = error_message}
    else
        return nil
    end
end

function Utils.isServerError(headers)
    -- Anything greater than a 399 is a HTTP error
    if headers and tonumber(headers.status) > 399 then
        return true
    else
        return false
    end
end

function Utils.checkResponse( data, headers, url )

    -- If headers.error is set, that means Lightroom had an error.
    if headers and headers.error then
        logger:error("checkResponse: Lightroom network error for url: " .. url)
        Utils.logTable(headers, "checkResponse headers")
        return { status = "error", from = "lightroom", code = headers.error.errorCode, description = headers.error.name or ""}

    -- Alternatively, the server could throw back an error.
    -- Only return data if we're sure
    elseif headers and tonumber(headers.status) > 299 then
        logger:error("checkResponse: Server error " .. headers.status .. " for url: " .. url)
        Utils.logTable(headers)
        logger:info(data)
        return { status = "error", from = "server", code = tonumber(headers.status), payload = data }

    -- Finally we can test to make sure the response actually has data.
    else
        if data ~= nil then
            return data
        else
            logger:error("checkResponse: Response for " .. url .. " was empty.")
            return { status = "error", from = "server", code = "empty", payload = data }
        end
    end
end

--------------------------------------------------------------------------------

function Utils.updatePlugin()
    LrFunctionContext.postAsyncTaskWithContext( 'Auto-updating!', function(context)

        context:addCleanupHandler(function(result,message)
            logger:error("Updating: Cleanup: " .. message)
        end)

        context:addFailureHandler(function(result,message)
            logger:error("Updating: Error message: " .. message)
        end)

        local data = {}
        data.pluginVersion = Info.VERSION
        data.lightroomVersion = LrApplication.versionTable()
        data.hash = LrApplication.serialNumberHash()
        data.arch = LrSystemInfo.architecture()
        data.os = LrSystemInfo.osVersion()
        if prefs.submitData then
            data.username = prefs.username
            data.uploadCount = prefs.uploadCount
        end

        local checksumUrl = string.format("http://code.kyl191.net/update.php?plugin=%s&data=%s",
                                            _PLUGIN.id,
                                            Utils.urlEncode(JSON:encode(data)))
        local remoteFiles = Utils.getJSON(checksumUrl)
        local localFiles = Utils.md5Files(_PLUGIN.path)

        for filename, hash in pairs (remoteFiles) do
            if localFiles[filename] == hash then
                -- correct version & no corruption!
            else
                local url = string.format("http://code.kyl191.net/%s/head/%s", _PLUGIN.id, filename)
                local file = Utils.getFile(url, "tempupdatefile", false)

                local path = LrPathUtils.makeAbsolute(file, _PLUGIN.path)
                LrFileUtils.makeFileWritable(path)
                if LrFileUtils.exists(path) then
                    logger:info(string.format("Going to move %s to %s", file, path))
                    Utils.makeBackups(file, 0)
                end

                local ok, message = LrFileUtils.move(file, path)
                if not ok then
                    logger:error(message)
                end

            end


        end

    end)

end
--------------------------------------------------------------------------------

function Utils.getVersion()
    return string.format("%i.%i.%07x", Info.VERSION.major, Info.VERSION.minor, Info.VERSION.revision)
end
--------------------------------------------------------------------------------

-- URLEncode function from http://lua-users.org/wiki/StringRecipes
function Utils.urlEncode(str)
    if (str) then
        str = string.gsub (str, "\n", "\r\n")
        str = string.gsub (str, "([^%w ])",
            function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = string.gsub (str, " ", "+")
        end
    return str
end

return Utils
