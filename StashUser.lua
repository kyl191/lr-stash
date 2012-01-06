--[[----------------------------------------------------------------------------

StashUser.lua
Stash user account management

------------------------------------------------------------------------------]]

	-- Lightroom SDK
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'
local LrDate = import 'LrDate'
local LrStringUtils = import 'LrStringUtils'

local logger = import 'LrLogger'( 'StashAPI' )
local prefs = import 'LrPrefs'.prefsForPlugin()

require 'StashAPI'

--============================================================================--

StashUser = {}

--------------------------------------------------------------------------------

local function storedCredentialsAreValid()

	return prefs.access_token and string.len( prefs.access_token ) > 0
			and prefs.refresh_token and string.len( prefs.refresh_token ) > 0
			and prefs.expire and (tonumber(prefs.expire) > LrDate.currentTime())

end

--------------------------------------------------------------------------------

local function notLoggedIn( propertyTable )

	prefs.access_token = nil
	prefs.refresh_token = nil
	prefs.expire = nil
	prefs.username = nil

	propertyTable.accountStatus = LOC "$$$/Stash/AccountStatus/NotLoggedIn=Not logged in"
	propertyTable.loginButtonTitle = LOC "$$$/Stash/LoginButton/NotLoggedIn=Log In"
	propertyTable.loginButtonEnabled = true
	propertyTable.validAccount = false

end

--------------------------------------------------------------------------------

local doingLogin = false

function StashUser.login( propertyTable )

	if doingLogin then return end
	doingLogin = true

	LrFunctionContext.postAsyncTaskWithContext( 'Stash login',
	function( context )

		-- Clear any existing login info, we're getting a new set of tokens.

		notLoggedIn( propertyTable )

		propertyTable.accountStatus = LOC "$$$/Stash/AccountStatus/LoggingIn=Logging in..."
		propertyTable.loginButtonEnabled = false
		
		LrDialogs.attachErrorDialogToFunctionContext( context )
		
		-- Make sure login is valid when done, or is marked as invalid.
		
		context:addCleanupHandler( function()

			doingLogin = false

			if not storedCredentialsAreValid() then
				notLoggedIn( propertyTable )
			end
			
			-- Hrm. New API doesn't make it easy to show what operation failed.
			-- LrDialogs.message( LOC "$$$/Stash/LoginFailed=Failed to log in." )

		end )
		
		-- auth_code is one-time use, don't bother storing it in the propertyTable
		local auth_code = StashAPI.showAuthDialog(propertyTable, '')

		-- Wipe out the code that was stored in the table
		propertyTable.code = nil

		-- json token is similarly one-time use
		local token = StashAPI.getToken(auth_code)

		StashAPI.processToken(token, context)

		-- User has OK'd authentication. Get the user info.
		
		propertyTable.accountStatus = LOC "$$$/Stash/AccountStatus/WaitingForStash=Waiting for response from Sta.sh..."

		
		-- Get the username from the StashAPI rather than StashUser because this is a new login
		prefs.username = StashAPI.getUsername( propertyTable )

		StashUser.verifyLogin( propertyTable )
		
	end )

end

--------------------------------------------------------------------------------

function StashUser.verifyLogin( propertyTable )

	-- Observe changes to prefs and update status message accordingly.

	local function updateStatus()
	
		logger:trace( "verifyLogin: updateStatus() was triggered." )
		
		LrTasks.startAsyncTask( function()
			logger:trace( "verifyLogin: updateStatus() is executing." )
			
			propertyTable.loginButtonTitle = LOC "$$$/Stash/LoginButton/LogInAgain=Sign In?"
			propertyTable.loginButtonEnabled = true
			propertyTable.LR_cantExportBecause = "Waiting for you to log into Sta.sh..." 


			if not (prefs.expire == nil) and (tonumber(prefs.expire) < LrDate.currentTime()) then
				StashAPI.refreshAuth()
			end

			if storedCredentialsAreValid( propertyTable ) then
				propertyTable.loginButtonTitle = LOC "$$$/Stash/LoginButton/LogInAgain=Logging In..."
				propertyTable.loginButtonEnabled = false
			    propertyTable.LR_cantExportBecause = "Still logging into Sta.sh..." 

				local username = StashAPI.getUsername()
				local space = StashAPI.getRemainingSpace()
				propertyTable.space = space
				if space ~= nil then
					space = "(" .. LrStringUtils.byteString(space) .. " of space remaining.)"
				end

				propertyTable.accountStatus = LOC( "$$$/Stash/AccountStatus/LoggedIn=Logged in as ^1 ^2", username, space )
				--LrDialogs.message('Username: ' .. username)
			
				if propertyTable.LR_editingExistingPublishConnection then
					propertyTable.loginButtonTitle = LOC "$$$/Stash/LoginButton/LogInAgain=Logged In"
					propertyTable.loginButtonEnabled = false
					propertyTable.validAccount = true
				else
					propertyTable.loginButtonTitle = LOC "$$$/Stash/LoginButton/LoggedIn=Switch User?"
					propertyTable.loginButtonEnabled = true
					propertyTable.validAccount = true
				end
			else
				LrDialogs.message("Login failed.")
				notLoggedIn( propertyTable )
			end
	
		end )
		
	end

	propertyTable:addObserver( 'access_token', updateStatus )
	updateStatus()
	
end

--------------------------------------------------------------------------------