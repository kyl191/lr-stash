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
local LrMD5 = import 'LrMD5'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'
local LrXml = import 'LrXml'

local prefs = import 'LrPrefs'.prefsForPlugin()

local bind = LrView.bind
local share = LrView.share

local logger = import 'LrLogger'( 'StashAPI' )

JSON = (loadfile (LrPathUtils.child(_PLUGIN.path, "json.lua")))()

--============================================================================--

StashAPI = {}

if prefs then
	propertyTable = prefs
end

--------------------------------------------------------------------------------


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

function StashAPI.getToken(code)

	local postUrl = "https://www.deviantart.com/oauth2/draft15/token?grant_type=authorization_code&client_id=114&client_secret=6ac9aa67308019e9f8a307480dadf5f4&redirect_uri=http://oauth2.kyl191.net/&code=" .. code

	local token = LrHttp.post(postUrl, "")

	-- error checking?
	return token

end

--------------------------------------------------------------------------------

function StashAPI.processToken( propertyTable, token_json, context )

	--LrDialogs.message('Access token: ' .. token_json)

	local token = JSON:decode(token_json)

	if token.status ~= "success" then
		LrDialogs.attachErrorDialogToFunctionContext(context)
		LrErrors.throwUserError( "Unable to authenticate" )
	elseif token.status == "success" then 
		propertyTable.access_token = token.access_token
		propertyTable.refresh_token = token.refresh_token
		propertyTable.expire = LrDate.currentTime() + token.expires_in
		--LrDialogs.message('Token expires at ' .. LrDate.timeToW3CDate( propertyTable.expire ) )
		prefs.access_token = propertyTable.access_token
		prefs.refresh_token = propertyTable.refresh_token
		prefs.expire = propertyTable.expire
	else
		--Error'd, network layer
		LrDialogs.attachErrorDialogToFunctionContext(context)
		LrErrors.throwUserError( "Network Problems" )
	end

end

--------------------------------------------------------------------------------

function StashAPI.uploadPhoto( propertyTable, params )

	-- Prepare to upload.
	
	assert( type( params ) == 'table', 'StashAPI.uploadPhoto: params must be a table' )
	
	local postUrl = 'https://www.deviantart.com/api/draft15/submit?token='.. propertyTable.access_token 
	logger:info( 'uploading photo', params.filePath )

	local filePath = assert( params.filePath )
	params.filePath = nil
	
	local fileName = LrPathUtils.leafName( filePath )
	
	params.tags = string.gsub( params.tags, ",", " " )

	postUrl = postUrl .. '&keywords=' .. params.tags
	
	local mimeChunks = {}

	-- Wait, where do the tags go?

	mimeChunks[ #mimeChunks + 1 ] = { name = 'photo', fileName = fileName, filePath = filePath, contentType = 'application/octet-stream' }
	
	-- Post it and wait for confirmation.
	
	local result, hdrs = LrHttp.postMultipart( postUrl, mimeChunks )
	
	if not result then
	
		if hdrs and hdrs.error then
			LrErrors.throwUserError( hdrs.error.nativeCode )
		end
		
	else
		json = JSON:decode(result)
		LrDialogs.message(result)
	end
	
end

--------------------------------------------------------------------------------

function StashAPI.openAuthUrl()

	LrHttp.openUrlInBrowser( "https://www.deviantart.com/oauth2/draft15/authorize?client_id=114&redirect_uri=http://oauth2.kyl191.net/&response_type=code" )

	return nil

end

--------------------------------------------------------------------------------

function StashAPI.getUsername( propertyTable )

	local username = nil

	local postUrl = "https://www.deviantart.com/api/draft15/user/whoami?token=" .. propertyTable.access_token

	local token_json = LrHttp.post(postUrl, "")

	local token = JSON:decode(token_json)
	
	if token.status then
		LrDialogs.attachErrorDialogToFunctionContext(context)
		LrErrors.throwUserError( "Unable to retrieve username: " .. token.error .. token.error_description )
	elseif token.username then 
		username = token.symbol .. token.username
		prefs.username = username
		propertyTable.username = username
	else
		--Error'd, network layer
		LrDialogs.attachErrorDialogToFunctionContext(context)
		LrErrors.throwUserError( "Network Problems" )
	end
	return username

end

--------------------------------------------------------------------------------

function StashAPI.refreshAuth( propertyTable )

	local postUrl = "https://www.deviantart.com/oauth2/draft15/token?grant_type=refresh_token&client_id=114&client_secret=6ac9aa67308019e9f8a307480dadf5f4&refresh_token=" .. propertyTable.refresh_token

	local token = LrHttp.post(postUrl, "")

	StashAPI.processToken(propertyTable, token, nil)

end