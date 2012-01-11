--[[----------------------------------------------------------------------------

StashAPI.lua
Common code to initiate Stash API requests

------------------------------------------------------------------------------]]

	-- Lightroom SDK
local LrBinding = import 'LrBinding'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrErrors = import 'LrErrors'
local LrFunctionContext = import 'LrFunctionContext'
local LrHttp = import 'LrHttp'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'
local LrStringUtils = import 'LrStringUtils'

local prefs = import 'LrPrefs'.prefsForPlugin()

local bind = LrView.bind
local share = LrView.share

local logger = import 'LrLogger'( 'StashAPI' )

JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

-- client secret is 6ac9aa67308019e9f8a307480dadf5f4
-- Breaking it up isn't intentional, but because the full 32 character string exceeds Lua's max value
-- And breaking it up into 2 16 character strings results in some strange truncation
-- So 4 8 character strings works
client_secret_pt1 = 0x6ac9aa67
client_secret_pt2 = 0x308019e9
client_secret_pt3 = 0xf8a30748
client_secret_pt4 = 0x0dadf5f4

client_id = 114

--============================================================================--

StashAPI = {}

--------------------------------------------------------------------------------


-- Isn't this replacable with LrStringUtils.trimWhitespace?
local function trim( s )

	return string.gsub( s, "^%s*(.-)%s*$", "%1" )

end

--------------------------------------------------------------------------------

function StashAPI.showAuthDialog( propertyTable, message )

	-- I'm not touching this thing till I know what it does!

	LrFunctionContext.callWithContext( 'StashAPI.showAuthDialog', function( context )

		local f = LrView.osFactory()
	
		local properties = propertyTable

		local contents = f:column {
			--bind_to_object = properties,
			spacing = f:control_spacing(),
			fill = 1,
	
			f:static_text {
				title = "In order to use this plug-in, you must authorize the plugin to access your Sta.sh account. Please click Authorize at Sta.sh to get the code.",
				fill_horizontal = 1,
				width_in_chars = 55,
				height_in_lines = 2,
				size = 'small',
			},
	
			message and f:static_text {
				title = message,
				fill_horizontal = 1,
				width_in_chars = 55,
				height_in_lines = 2,
				size = 'small',
				text_color = import 'LrColor'( 1, 0, 0 ),
			} or 'skipped item',
			
			f:row {
				spacing = f:label_spacing(),
				
				f:static_text {
					title = "Code:",
					alignment = 'right',
					width = share 'title_width',
				},
				
				f:edit_field { 
					fill_horizonal = 1,
					width_in_chars = 19, 
					value = bind { key = 'code', object = propertyTable },
				},
			},
		}
		
		local result = LrDialogs.presentModalDialog {
				title = LOC "$$$/Stash/ApiKeyDialog/Title=Enter Your Sta.sh Code", 
				contents = contents,
				accessoryView = f:push_button {
					title = LOC "$$$/Stash/ApiKeyDialog/GoToStash=Authorize at Sta.sh...",
					action = function()
						StashAPI.openAuthUrl()
					end
				},
			}
		
		if result == 'ok' then

			propertyTable.code = trim( propertyTable.code )

		else
		
			LrErrors.throwCanceled()
		
		end
	
	end )

	return propertyTable.code
	
end

--------------------------------------------------------------------------------

function StashAPI.openAuthUrl()

	-- Send the user to the dA approve application screen
	-- Called from StashAPI.showAuthDialog
	-- Which in turn should ONLY be called from StashUser.login
	-- Reasoning behind having a separate function?
	-- Will combine into showAuthDialog

	LrHttp.openUrlInBrowser( string.format("https://www.deviantart.com/oauth2/draft15/authorize?client_id=%i&redirect_uri=http://oauth2.kyl191.net/&response_type=code", client_id ))

	return nil

end

--------------------------------------------------------------------------------

function StashAPI.getToken(code)

	-- Get the initial authorization token.
	-- ONLY called by StashUser.login
	-- And, yes, redirect_uri appears to be needed, so don't remove it

	local token = StashAPI.getResult(string.format("https://www.deviantart.com/oauth2/draft15/token?grant_type=authorization_code&client_id=%i&client_secret=%08x%08x%08x%08x&redirect_uri=http://oauth2.kyl191.net/&code=%s",client_id, client_secret_pt1, client_secret_pt2, client_secret_pt3, client_secret_pt4,code))

	return token

end

--------------------------------------------------------------------------------

function StashAPI.refreshAuth()

	-- Refresh the auth token
	-- getToken needs the initial authorization code from the user, an has a different URL (specifically, the grant_type), so it's split off into a separate function

	local token = StashAPI.getResult(string.format("https://www.deviantart.com/oauth2/draft15/token?grant_type=refresh_token&client_id=%i&client_secret=%08x%08x%08x%08x&refresh_token=%s",client_id, client_secret_pt1, client_secret_pt2, client_secret_pt3, client_secret_pt4, prefs.refresh_token))

	StashAPI.processToken( token, nil)

end

--------------------------------------------------------------------------------

function StashAPI.processToken( token, context )

	-- Token gets to here after passing through getResult, with the attendant network error checking
	-- So no need for network errors
	-- Also, one of the checks was to see if the status was 'error', so the default case that we assume is that status == success
	
	-- Setup the various plugin preferences
	if token.status == "success" then
		prefs.access_token = token.access_token
		prefs.refresh_token = token.refresh_token
		prefs.expire = LrDate.currentTime() + token.expires_in
	
	-- If the token has anything other than status = success, oops, we've got a problem
	else 
		LrDialogs.attachErrorDialogToFunctionContext(context)
		LrErrors.throwUserError( "Unable to authenticate" )
	end

end

--------------------------------------------------------------------------------

function StashAPI.uploadPhoto( params )

	-- Prepare to upload.
	-- Make sure that we got a table of parameters
	assert( type( params ) == 'table', 'StashAPI.uploadPhoto: params must be a table' )
	
	local postUrl = 'https://www.deviantart.com/api/draft15/submit?token='.. prefs.access_token 
	logger:info( 'uploading photo', params.filePath )

	-- Identification on Sta.sh
	--- Since folder support is still buggy, if we've got the stash id, just use that.
	--- Otherwise, use the folderid if we're uploading a new photo to a known collection
	--- Last resort, new collection, send the foldername

	if not (params.stashid == nil) then
		postUrl = postUrl .. '&stashid=' .. params.stashid
	else

		if not (params.folderid == nil) then
			postUrl = postUrl .. '&folderid=' .. params.folderid
		else
			if not (params.foldername == nil) then
				postUrl = postUrl .. '&folder=' .. params.foldername
			end
		end
	end

	-- Overwriting info
	--- Currently, assume that the user is solely managing the dA gallery from Lightroom, so Lightroom has the master copy of the description, title and keywords.
	--- Overwrite the existing stuff each and every time.
	
	-- We definitely have a title, so append that
	postUrl = postUrl .. '&title=' .. params.title
	
	-- Append the tags if present
	if not (params.tags == nil or #params.tags == 0) then
		postUrl = postUrl .. '&keywords=' .. params.tags
	end
	
	-- Append the description
	-- Though it's short, so maybe a Memo/long description panel in Lightroom?
	if not (params.description == nil or #params.description == 0) then
		postUrl = postUrl .. '&artist_comments=' .. params.description
	end
	
	
	-- Add the photo itself
	local mimeChunks = {}

	local filePath = assert( params.filePath )
	
	local fileName = LrPathUtils.leafName( filePath )

	mimeChunks[ #mimeChunks + 1 ] = { name = 'photo', fileName = fileName, filePath = filePath, contentType = 'application/octet-stream' }
	
	-- Before uploading, check to make sure that there's enough space to upload
	local space = StashAPI.getRemainingSpace()
	local fileAttribs = LrFileUtils.fileAttributes(filePath)
	
	if tonumber(space) < tonumber(fileAttribs.fileSize) then
		LrErrors.throwUserError( "Not enough space in Sta.sh to upload the file!" )
	end

	-- Post it and wait for confirmation.
	local result, hdrs = LrHttp.postMultipart( postUrl, mimeChunks )
	
	if not result then
	
		if hdrs and hdrs.error then
			LrErrors.throwUserError( "Network error when uploading: " .. hdrs.error.nativeCode )
		end
		
	else
		json = JSON:decode(result)
		if json.error ~= nil and not params.retry then
			if json.error == ("internal_error_item" or "invalid_stashid") then
				-- internal_error_item seems to mean we tried uploading to a deleted stashid
				-- Checking invalid_stashid too, since that seems to be another likely one to do with stashid
				params.stashid = nil
				params.retry = json.error
				LrDialogs.message('Something wrong with the stashid, retrying with a blank id')
				return StashAPI.uploadPhoto(params)
			elseif json.error == ("internal_error_missing_folder" or "invalid_folderid") then
				-- internal_error_missing_folder seems to indicate something's gone awry with the folder, so reupload with a different folder id
				-- Same for invalid_folderid too
				params.folderid = nil
				params.retry = json.error
				LrDialogs.message('Something wrong with the folderid, retrying with a blank id')
				return StashAPI.uploadPhoto(params)
			else
				-- Haven't seen any other errors yet.
				-- Suppose we could try uploading again.
				LrErrors.throwUserError( "Error uploading to Sta.sh: " .. json.error .. " : " .. json.error_description)
			end
		elseif json.error ~= nil and params.retry then
			LrErrors.throwUserError( "Error uploading to Sta.sh, even after retrying. Last error was: \n" .. json.error .. " : \n" .. json.error_description)
		end
		return json
	end
	
end

--------------------------------------------------------------------------------

function StashAPI.getUsername()

	-- Get the user's dA username in the form of ~kyl191 (the dA symbol, and the actual name)

	local token = StashAPI.getResult( "https://www.deviantart.com/api/draft15/user/whoami?token=" .. prefs.access_token )
	
	return token.symbol .. token.username

end

--------------------------------------------------------------------------------

function StashAPI.getResult( postUrl )

	-- Do the request
	local json, headers = LrHttp.post(postUrl, "")

	-- If we didn't get a result back, that means there was a transport error
	-- So show that error to the user
	if not json then
	
		if headers and headers.error then
			LrErrors.throwUserError( "Network error: " .. hdrs.error.nativeCode )
		end
		
	else
		-- Now that we have valid JSON, decode it, and try to get the status of our request
		-- If the status is error, show the error to the user, and die.
		local decode = JSON:decode(json)
		if decode.status and decode.status == "error" then
			LrErrors.throwUserError ("Error with a JSON response! \n" .. decode.error .. "\n" ..decode.error_description)
		end
		return decode
	end

end	
--------------------------------------------------------------------------------

function StashAPI.getRemainingSpace()

	-- Get the amount of space left in the sta.sh quota for the user

	local token = StashAPI.getResult("https://www.deviantart.com/api/draft15/stash/space?token=" .. prefs.access_token)

	return token.available_space

end
