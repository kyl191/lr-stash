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
local client_secret_pt1 = 0x6ac9aa67
local client_secret_pt2 = 0x308019e9
local client_secret_pt3 = 0xf8a30748
local client_secret_pt4 = 0x0dadf5f4

local client_id = 114

--============================================================================--

StashAPI = {}

--------------------------------------------------------------------------------


-- Isn't this replacable with LrStringUtils.trimWhitespace?
local function trim( s )

	return string.gsub( s, "^%s*(.-)%s*$", "%1" )

end

--------------------------------------------------------------------------------

function StashAPI.showAuthDialog( propertyTable, message )

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

	local token = StashAPI.getResult(string.format("https://www.deviantart.com/oauth2/draft15/token?grant_type=authorization_code&client_id=%i&client_secret=%08x%08x%08x%08x&redirect_uri=http://oauth2.kyl191.net/&code=%s",client_id, client_secret_pt1, client_secret_pt2, client_secret_pt3, client_secret_pt4,code))

	return token

end

--------------------------------------------------------------------------------

function StashAPI.refreshAuth()

	local token = StashAPI.getResult(string.format("https://www.deviantart.com/oauth2/draft15/token?grant_type=refresh_token&client_id=%i&client_secret=%08x%08x%08x%08x&refresh_token=%s",client_id, client_secret_pt1, client_secret_pt2, client_secret_pt3, client_secret_pt4, prefs.refresh_token))

	StashAPI.processToken( token, nil)

end

--------------------------------------------------------------------------------

function StashAPI.processToken( token, context )

	--LrDialogs.message('Access token: ' .. token_json)

	-- Token already decoded, no need for this.
	--local token = JSON:decode(token_json)

	if token.status ~= "success" then
		LrDialogs.attachErrorDialogToFunctionContext(context)
		LrErrors.throwUserError( "Unable to authenticate" )
	elseif token.status == "success" then 
		prefs.access_token = token.access_token
		prefs.refresh_token = token.refresh_token
		prefs.expire = LrDate.currentTime() + token.expires_in
		--LrDialogs.message('Token expires at ' .. LrDate.timeToW3CDate( prefs.expire ) )
	else
		--Error'd, network layer
		LrDialogs.attachErrorDialogToFunctionContext(context)
		LrErrors.throwUserError( "Network Problems" )
	end

end

--------------------------------------------------------------------------------

function StashAPI.uploadPhoto( params )

	-- Prepare to upload.
	
	assert( type( params ) == 'table', 'StashAPI.uploadPhoto: params must be a table' )
	
	local postUrl = 'http://www.deviantart.com/api/draft15/submit?token='.. prefs.access_token 
	logger:info( 'uploading photo', params.filePath )

	postUrl = postUrl .. '&title=' .. params.title

	local filePath = assert( params.filePath )
	
	local fileName = LrPathUtils.leafName( filePath )
	
	-- Append the tags if present
	if not (params.tags == nil) then
		postUrl = postUrl .. '&keywords=' .. params.tags
	end
	
	-- Append the description
	-- Though it's short, so maybe a Memo/long description panel in Lightroom?
	if not (params.description == nil) then
		postUrl = postUrl .. '&artist_comments=' .. params.description
	end
	
	-- Append the Sta.sh id if we're replacing it.
	if not (params.stashid == nil) then
		postUrl = postUrl .. '&stashid=' .. params.stashid
	end

	-- Append the folderid too if we've got it.
	if not (params.folderid == nil) then
		postUrl = postUrl .. '&folderid=' .. params.folderid
	end

	if not (params.foldername == nil) then
		postUrl = postUrl .. '&folder=' .. params.foldername
	end

	
	-- Add the photo itself
	local mimeChunks = {}

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
			LrErrors.throwUserError( hdrs.error.nativeCode )
		end
		
	else
		json = JSON:decode(result)
		if json.error ~= nil then
			LrErrors.throwUserError( "Error uploading to Sta.sh: " .. json.error .. " : " .. json.error_description)
		end
		return json
	end
	
end

--------------------------------------------------------------------------------

function StashAPI.getUsername()

	local token = StashAPI.getResult( "https://www.deviantart.com/api/draft15/user/whoami?token=" .. prefs.access_token )
	
	return token.symbol .. token.username

end

--------------------------------------------------------------------------------

function StashAPI.getResult( postUrl )

	local json, headers = LrHttp.post(postUrl, "")

	if not json then
	
		if hdrs and hdrs.error then
			LrErrors.throwUserError( hdrs.error.nativeCode )
		end
		
	else
		local decode = JSON:decode(json)
		if decode.status and decode.status == "error" then
			LrErrors.throwUserError ("Error with a JSON response! " .. decode.error .. decode.error_description)
		end
		return decode
	end

end	
--------------------------------------------------------------------------------

function StashAPI.getRemainingSpace()

	local token = StashAPI.getResult("https://www.deviantart.com/api/draft15/stash/space?token=" .. prefs.access_token)

	return token.available_space

end