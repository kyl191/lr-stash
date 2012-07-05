--[[----------------------------------------------------------------------------

Utils.lua
Common code for Lightroom plugins

------------------------------------------------------------------------------]]
local LrMD5 = import 'LrMD5'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrFunctionContext = import 'LrFunctionContext'
local logger = import 'LrLogger'( 'Stash' )
local Info = require 'Info'
local prefs = import 'LrPrefs'.prefsForPlugin()

local LrPathUtils = import 'LrPathUtils'

local LrHttp = import 'LrHttp'
local LrErrors = import 'LrErrors'
local LrApplication = import 'LrApplication'
local LrSystemInfo = import 'LrSystemInfo'

--------------------------------------------------------------------------------
JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

--------------------------------------------------------------------------------

Utils = {}
--------------------------------------------------------------------------------
-- variation of http://forums.adobe.com/message/3146133#3146133
function Utils.logTable(x, label)
    local function dump1 (x, indent, visited)
        if type (x) ~= "table" then
            logger:info (string.rep (" ", indent) .. tostring (x))
            return
        end

        visited [x] = true
        if indent == 0 then
            logger:info (string.rep (" ", indent) .. tostring (x))
        end
        for k, v in pairs (x) do
            logger:info (string.rep (" ", indent + 4) .. tostring (k) .. " = " ..
                    tostring (v))
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

function Utils.getJSON( postUrl, errorMessage )

    data = Utils.networkComms( "post", postUrl )

    -- We can't do anything about a Lightroom transport error!
    if data.status and data.status == "error" and data.from == "lightroom" then
        logger:error(postUrl .. " was supposed to return JSON, but didn't.")
        LrErrors.throwUserError("Oh dear. There was a problem " .. errorMessage .. ". \nWe were supposed to get JSON back from the server, but Lightroom had a problem:\n" .. data.description)
    end

    -- Other problem is a server error. Sta.sh tries to return errors in JSON, so try parsing it.
    -- Other systems should *also* return JSON - this is getJSON after all.
    local ok, decode = LrFunctionContext.pcallWithContext("parsing json", function(context, data)
        context:addFailureHandler( function(status,message)
            logger:error("Error parsing JSON: " )
        end)
        context:addOperationTitleForError( "Error parsing a JSON response" )

        return JSON:decode(data)
    end,
        data)

    -- If the JSON parsing failed, throw an error.
    if ok ~= true then
        logger.error("getJSON: JSON error for url : ".. postUrl .. "\n" .. decode)
        LrErrors.throwUserError("Oh dear. We were supposed to get JSON back from the server when " .. errorMessage .. ", but got some garbage instead. Wait a while, and try again.")
    else
        -- Otherwise, try parsing the error.
        -- Admittedly, this is skewed towards Sta.sh, with the checking of status == error, but this is the primary target right now...
        logger:info("Apparently, we parsed the JSON successfully.")
        if decode.status and decode.status == "error" then
            logger:error("getJSON: JSON error from " .. postUrl)
            Utils.logTable(decode, "Result from JSON decode")
            LrErrors.throwUserError("Oh dear. The server didn't like us " .. errorMessage .. ", it said " .. decode.error .. ", which apparently means \"".. decode.error_description .. "\". \nThis might be a permanent error if you repeatedly get this message.")
        else
            logger:info("Assuming getJSON was a success for " .. postUrl)
            return decode
        end
    end

end

--------------------------------------------------------------------------------

function Utils.getFile(url, path, errorMessage)
    data = Utils.networkComms( "get", url)

    -- We can't do anything about a Lightroom transport error!
    if data.status and data.status == "error" and data.from == "lightroom" then
        logger:error(url .. " had a problem.")
        LrErrors.throwUserError("Oh dear. There was a problem getting " .. errorMessage .. ". \nLightroom had a problem:\n" .. data.description)
    end

    path = LrPathUtils.standardizePath(path)

    if LrPathUtils.isRelative(path) then
        path = LrPathUtils.makeAbsolute(path, _PLUGIN.path)
    end

    if LrFileUtils.exists(path) then
        path = LrFileUtils.chooseUniqueFileName(path)
    end

    if LrFileUtils.isWritable(path) or (not LrFileUtils.exists(path) )then

        local out = assert(io.open(path, "wb"))
        out:write(data)
        assert(out:close())
        return path

    else
        logger:info("Path " .. path .. " isn't writable.")
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

function Utils.checkResponse( data, headers, url )

    -- If headers.error is set, that means Lightroom had an error.
    if headers and headers.error then
        logger:error("checkResponse: Lightroom network error for url: " .. url)
        Utils.logTable(headers, "checkResponse headers")
        return { status = "error", from = "lightroom", code = headers.error.errorCode, description = headers.error.name }
    
    -- Alternatively, the server could throw back an error.
    -- Only return data if we're sure
    elseif headers and tonumber(headers.status) > 299 then
        logger:error("checkResponse: Server error " .. headers.status .. " for url: " .. url)
        Utils.logTable(headers)
        logger:info(data)
        return { status = "error", from = "server", code = headers.status, payload = data }
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
            data.userSymbol = prefs.userSymbol
            data.uploadCount = prefs.uploadCount
        end

        local remoteFiles = Utils.getJSON("http://code.kyl191.net/update.php?plugin=" .. _PLUGIN.id .. "&data=" .. JSON:encode(data))
        local localFiles = Utils.md5Files(_PLUGIN.path)

        for k, v in pairs (remoteFiles) do
            if localFiles[k] == v then
                -- do nothing
            else
                local file = Utils.getFile("http://code.kyl191.net/" .. _PLUGIN.id .. "/head/" .. k, "tempupdatefile", nil)
                local path = LrPathUtils.makeAbsolute(k, _PLUGIN.path)
                LrFileUtils.makeFileWritable(path)
                if LrFileUtils.exists(path) then
                    logger:info("Going to move " .. file .. "to " .. path)
                    Utils.makeBackups(k, 0)
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

return Utils