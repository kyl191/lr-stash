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

function StashUser.storedCredentialsAreValid()

	return prefs.access_token and string.len( prefs.access_token ) > 0
			and prefs.refresh_token and string.len( prefs.refresh_token ) > 0
			and prefs.expire and (tonumber(prefs.expire) > LrDate.currentTime())

end

--------------------------------------------------------------------------------

local function notLoggedIn( propertyTable )

	-- Reset all the user auth information

	prefs.access_token = nil
	prefs.refresh_token = nil
	prefs.expire = nil
	prefs.username = nil

	-- Show the user a 'Log In' button in the Export/Publish menu

	propertyTable.accountStatus = LOC "$$$/Stash/AccountStatus/NotLoggedIn=Not logged in"
	propertyTable.loginButtonTitle = LOC "$$$/Stash/LoginButton/NotLoggedIn=Log In"
	propertyTable.loginButtonEnabled = true
	propertyTable.validAccount = false

end

--------------------------------------------------------------------------------

local doingLogin = false

function StashUser.login( propertyTable )

	-- Prevent race conditions where we're already logging in
	if doingLogin then return end
	doingLogin = true

	LrFunctionContext.postAsyncTaskWithContext( 'Stash login',
	function( context )

		-- Clear any existing login info, we're getting a new set of tokens.

		notLoggedIn( propertyTable )

		-- Give the user a status message and disable the login button

		propertyTable.accountStatus = LOC "$$$/Stash/AccountStatus/LoggingIn=Logging in..."
		propertyTable.loginButtonEnabled = false
		
		LrDialogs.attachErrorDialogToFunctionContext( context )
		
		-- Make sure login is valid when done, or if it's invalid, reset the status
		
		context:addCleanupHandler( function()

			doingLogin = false

			if not StashUser.storedCredentialsAreValid() then
				notLoggedIn( propertyTable )
			end

		end )
		
		-- auth_code is one-time use, don't bother storing it in the propertyTable
		local auth_code = StashAPI.showAuthDialog(propertyTable, '')

		-- But, the UI wants to be attached to a table, and I gave it propertyTable
		-- So, wipe out the code that was stored in the table
		propertyTable.code = nil

		-- json token is similarly one-time use
		local token = StashAPI.getToken(auth_code)

		StashAPI.processToken(token, context)

		-- User has OK'd authentication. Get the user info.
		
		propertyTable.accountStatus = LOC "$$$/Stash/AccountStatus/WaitingForStash=Waiting for response from Sta.sh..."

		
		-- Verify that the login was successful, and update the menus.
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
			
			-- Start off assuming the user hasn't logged in before
			propertyTable.loginButtonTitle = LOC "$$$/Stash/LoginButton/LogInAgain=Sign In?"
			propertyTable.loginButtonEnabled = true
			propertyTable.LR_cantExportBecause = "Waiting for you to log into Sta.sh..." 


			-- If there's a record of a past login, check if the credentials have expired
			-- If so, refresh them
			if not (prefs.expire == nil) and (tonumber(prefs.expire) < LrDate.currentTime()) then
				StashAPI.refreshAuth()
			end

			if StashUser.storedCredentialsAreValid( propertyTable ) then
				
				-- We think the user is a valid one, so try accessing a protected resource
				-- Activate the login button because if the authenticated call fails, the entire process bombs out,
				-- and we can't login because the login button is disabled.
				propertyTable.accountStatus = "Logging into Sta.sh, please wait..."
				propertyTable.loginButtonTitle = LOC "$$$/Stash/LoginButton/LogInAgain=Re-Login?"
				propertyTable.loginButtonEnabled = true
			    propertyTable.LR_cantExportBecause = "Still logging into Sta.sh..." 

				prefs.username = StashAPI.getUsername()
				propertyTable.accountStatus = LOC( "$$$/Stash/AccountStatus/LoggedIn=Logged in as ^1", prefs.username)

				-- Be nice and try to show the user how much space he has left.
				local space = StashAPI.getRemainingSpace()
				if space ~= nil then
					space = "(" .. LrStringUtils.byteString(space) .. " of space remaining.)"
				end
				propertyTable.accountStatus = LOC( "$$$/Stash/AccountStatus/LoggedIn=Logged in as ^1 ^2", username, space )
			
				-- If the user's editing an existing connection, we can't allow him to switch users, 
				-- otherwise we'll get an error when trying to republish under a different user.
				-- Todo: Find a way to track which account the user's published through before?
				-- Because he can still change which user he wants in the export section...
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
				LrDialogs.message("Existing credentials are invalid, please login again.")
				notLoggedIn( propertyTable )
			end
	
		end )
		
	end

	propertyTable:addObserver( 'access_token', updateStatus )
	updateStatus()
	
end

--------------------------------------------------------------------------------