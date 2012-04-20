--[[----------------------------------------------------------------------------

StashExportServiceProvider.lua
Export service provider description for Lightroom Stash uploader

------------------------------------------------------------------------------]]

	-- Lightroom SDK
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrView = import 'LrView'
local LrStringUtils = import 'LrStringUtils'
local prefs = import 'LrPrefs'.prefsForPlugin()
local LrDate = import 'LrDate'
local logger = import 'LrLogger'( 'Stash' )

	-- Common shortcuts
local bind = LrView.bind
local share = LrView.share

	-- Stash plug-in
require 'StashAPI'
require 'StashUser'
require 'Utils'



--------------------------------------------------------------------------------

 -- NOTE to developers reading this sample code: This file is used to generate
 -- the documentation for the "export service provider" section of the API
 -- reference material. This means it's more verbose than it would otherwise
 -- be, but also means that you can match up the documentation with an actual
 -- working example. It is not necessary for you to preserve any of the
 -- documentation comments in your own code.


--===========================================================================--
--[[ @sdk
--- The <i>service definition script</i> for an export service provider defines the hooks 
 -- that your plug-in uses to extend the behavior of Lightroom's Export features.
 -- The plug-in's <code>Info.lua</code> file identifies this script in the 
 -- <code>LrExportServiceProvider</code> entry.
 -- <p>The service definition script should return a table that contains:
 --   <ul><li>A pair of functions that initialize and terminate your export service. </li>
 --	<li>Settings that you define for your export service.</li>
 --	<li>One or more items that define the desired customizations for the Export dialog. 
 --	    These can restrict the built-in services offered by the dialog,
 --	    or customize the dialog by defining new sections. </li>
 --	<li> A function that defines the export operation to be performed 
 --	     on rendered photos (required).</li> </ul>
 -- <p>The <code>StashExportServiceProvider.lua</code> file of the Stash sample plug-in provides 
 -- 	examples of and documentation for the hooks that a plug-in must provide in order to 
 -- 	define an export service. Lightroom expects your plug-in to define the needed callbacks
 --	and properties with the required names and syntax. </p>
 -- <p>Unless otherwise noted, all of the hooks in this section are available to
 -- both Export and Publish service provider plug-ins. If your plug-in supports
 -- Lightroom's Publish feature, you should also read the API reference section
 -- <a href="SDK%20-%20Publish%20service%20provider.html">publish service provider</a>.</p>
 -- @module_type Plug-in provided

	module 'SDK - Export service provider' -- not actually executed, but suffices to trick LuaDocs

--]]


--============================================================================--

local exportServiceProvider = {}

--------------------------------------------------------------------------------
--- (optional) Plug-in defined value declares whether this plug-in supports the Lightroom
 -- publish feature. If not present, this plug-in is available in Export only.
 -- When true, this plug-in can be used for both Export and Publish. When 
 -- set to the string "only", the plug-in is visible only in Publish.
	-- @name exportServiceProvider.supportsIncrementalPublish
	-- @class property

exportServiceProvider.supportsIncrementalPublish = 'true'

--------------------------------------------------------------------------------
--- (optional) Plug-in defined value declares which fields in your property table should
 -- be saved as part of an export preset or a publish service connection. If present,
 -- should contain an array of items with key and default values. For example:
	-- <pre>
		-- exportPresetFields = {<br/>
			-- &nbsp;&nbsp;&nbsp;&nbsp;{ key = 'username', default = "" },<br/>
			-- &nbsp;&nbsp;&nbsp;&nbsp;{ key = 'fullname', default = "" },<br/>
			-- &nbsp;&nbsp;&nbsp;&nbsp;{ key = 'nsid', default = "" },<br/>
			-- &nbsp;&nbsp;&nbsp;&nbsp;{ key = 'privacy', default = 'public' },<br/>
			-- &nbsp;&nbsp;&nbsp;&nbsp;{ key = 'privacy_family', default = false },<br/>
			-- &nbsp;&nbsp;&nbsp;&nbsp;{ key = 'privacy_friends', default = false },<br/>
		-- }<br/>
	-- </pre>
 -- <p>The <code>key</code> item should match the values used by your user interface
 -- controls.</p>
 -- <p>The <code>default</code> item is the value to the first time
 -- your plug-in is selected in the Export or Publish dialog. On second and subsequent
 -- activations, the values chosen by the user in the previous session are used.</p>
 -- <p>First supported in version 1.3 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.exportPresetFields
 	-- @class property

exportServiceProvider.exportPresetFields = {
	{ key = 'titleFirstChoice', default = 'title'},
	{ key = 'titleSecondChoice',  default = 'filename'},
    { key = 'overwriteMetadata', default = 'false'}

}

--------------------------------------------------------------------------------
--- (optional) Plug-in defined value suppresses the display of the named sections in
 -- the Export or Publish dialogs. You can use either <code>hideSections</code> or 
 -- <code>showSections</code>, but not both. If present, this should be an array 
 -- containing one or more of the following strings:
	-- <ul>
		-- <li>exportLocation</li>
		-- <li>fileNaming</li>
		-- <li>fileSettings</li>
		-- <li>imageSettings</li>
		-- <li>outputSharpening</li>
		-- <li>metadata</li>
		-- <li>watermarking</li>
	-- </ul>
 -- <p>You cannot suppress display of the "Connection Name" section in the Publish Manager dialog.</p>
 -- <p>If you suppress the "exportLocation" section, the files are rendered into
 -- a temporary folder which is deleted immediately after the Export operation
 -- completes.</p>
 -- <p>First supported in version 1.3 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.hideSections
	-- @class property

exportServiceProvider.hideSections = { 'exportLocation' }

--------------------------------------------------------------------------------

--- (optional) Plug-in defined value restricts the available file format choices in the
 -- Export or Publish dialogs to those named. You can use either <code>allowFileFormats</code> or 
 -- <code>disallowFileFormats</code>, but not both. If present, this should be an array
 -- containing one or more of the following strings:
	-- <ul>
		-- <li>JPEG</li>
		-- <li>PSD</li>
		-- <li>TIFF</li>
		-- <li>DNG</li>
		-- <li>ORIGINAL</li>
	-- </ul>
 -- <p>This property affects the output of still photo files only;
 -- it does not affect the output of video files.
 --  See <a href="#exportServiceProvider.canExportVideo"><code>canExportVideo</code></a>.)</p>
 -- <p>First supported in version 1.3 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.allowFileFormats
	-- @class property

exportServiceProvider.allowFileFormats = { 'JPEG' }

--------------------------------------------------------------------------------

--- (optional) Plug-in defined value restricts the available color space choices in the
 -- Export or Publish dialogs to those named.  You can use either <code>allowColorSpaces</code> or 
 -- <code>disallowColorSpaces</code>, but not both. If present, this should be an array
 -- containing one or more of the following strings:
	-- <ul>
		-- <li>sRGB</li>
		-- <li>AdobeRGB</li>
		-- <li>ProPhotoRGB</li>
	-- </ul>
 -- <p>Affects the output of still photo files only, not video files.
 -- See <a href="#exportServiceProvider.canExportVideo"><code>canExportVideo</code></a>.</p>
 -- <p>First supported in version 1.3 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.allowColorSpaces
	-- @class property

exportServiceProvider.allowColorSpaces = { 'sRGB' }

--------------------------------------------------------------------------------
--- (optional, Boolean) Plug-in defined value is true to hide print resolution controls
 -- in the Image Sizing section of the Export or Publish dialog.
 -- (Recommended when uploading to most web services.)
 -- <p>First supported in version 1.3 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.hidePrintResolution
	-- @class property

exportServiceProvider.hidePrintResolution = true

--------------------------------------------------------------------------------
--- (optional, Boolean)  When plug-in defined value istrue, both video and 
 -- still photos can be exported through this plug-in. If not present or set to false,
 --  video files cannot be exported through this plug-in. If set to the string "only",
 -- video files can be exported, but not still photos.
 -- <p>No conversions are available for video files. They are simply
 -- copied in the same format that was originally imported into Lightroom.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.canExportVideo
	-- @class property

exportServiceProvider.canExportVideo = false 

--------------------------------------------------------------------------------

 -- (string) Plug-in defined value is the filename of the icon to be displayed
 -- for this publish service provider, in the Publish Services panel, the Publish 
 -- Manager dialog, and in the header shown when a published collection is selected.
 -- The icon must be in PNG format and no more than 26 pixels wide or 19 pixels tall.
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.small_icon
	-- @class property

exportServiceProvider.small_icon = 'logo.png'

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the behavior of the
 -- Description entry in the Publish Manager dialog. If the user does not provide
 -- an explicit name choice, Lightroom can provide one based on another entry
 -- in the publishSettings property table. This entry contains the name of the
 -- property that should be used in this case.
	-- @name exportServiceProvider.publish_fallbackNameBinding
	-- @class property
	
exportServiceProvider.publish_fallbackNameBinding = 'fullname'

--------------------------------------------------------------------------------

--- When set to the string "disable", the "Go to Published Collection" context-menu item
 -- is disabled (dimmed) for this publish service.
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.titleForGoToPublishedCollection
	-- @class property

-- Sta.sh doesn't seem to allow going to a folder directly.

exportServiceProvider.titleForGoToPublishedCollection = "disable"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value overrides the label for the 
 -- "Go to Published Photo" context-menu item, allowing you to use something more appropriate to
 -- your service. Set to the special value "disable" to disable (dim) the menu item for this service. 
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.titleForGoToPublishedPhoto
	-- @class property

exportServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/Stash/TitleForGoToPublishedCollection=Show in Sta.sh"

--------------------------------------------------------------------------------
--- This plug-in defined callback function is called when the user attempts to change the name
 -- of a collection, to validate that the new name is acceptable for this service.
 -- <p>This is a blocking call. You should use it only to validate easily-verified
 -- characteristics of the name, such as illegal characters in the name. For
 -- characteristics that require validation against a server (such as duplicate
 -- names), you should accept the name here and reject the name when the server-side operation
 -- is attempted.</p>
	-- @name exportServiceProvider.validatePublishedCollectionName
	-- @class function
 	-- @param proposedName (string) The name as currently typed in the new/rename/edit
		-- collection dialog.
	-- @return (Boolean) True if the name is acceptable, false if not
	-- @return (string) If the name is not acceptable, a string that describes the reason, suitable for display.

-- Unknown what the Sta.sh API allows as a folder name. Assuming it's only ASCII
function exportServiceProvider.validatePublishedCollectionName( proposedName )
	return LrStringUtils.isOnlyAscii( proposedName )
end

-------------------------------------------------------------------------------

function exportServiceProvider.metadataThatTriggersRepublish( publishSettings )

	return {

		default = false,
		title = true,
		caption = true,
		keywords = true,
	}

end


-------------------------------------------------------------------------------
--- (Boolean) This plug-in defined value, when true, disables (dims) the Rename Published
 -- Collection command in the context menu of the Publish Services panel 
 -- for all published collections created by this service. 
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name exportServiceProvider.disableRenamePublishedCollection
	-- @class property

-- Sta.sh allows renames, but the API is currently broken.
exportServiceProvider.disableRenamePublishedCollection = true

-------------------------------------------------------------------------------
--- This plug-in callback function is called when the user has renamed a
 -- published collection via the Publish Services panel user interface. This is
 -- your plug-in's opportunity to make the corresponding change on the service.
 -- <p>If your plug-in is unable to update the remote service for any reason,
 -- you should throw a Lua error from this function; this causes Lightroom to revert the change.</p>
 -- <p>This is not a blocking call. It is called from within a task created
 -- using the <a href="LrTasks.html"><code>LrTasks</code></a> namespace. In most
 -- cases, you should not need to start your own task within this function.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.renamePublishedCollection
	-- @class function
	-- @param publishSettings (table) The settings for this publish service, as specified
		-- by the user in the Publish Manager dialog. Any changes that you make in
		-- this table do not persist beyond the scope of this function call.
	-- @param info (table) A table with these fields:
	 -- <ul>
	  -- <li><b>isDefaultCollection</b>: (Boolean) True if this is the default collection.</li>
	  -- <li><b>name</b>: (string) The new name being assigned to this collection.</li>
		-- <li><b>parents</b>: (table) An array of information about parents of this collection, in which each element contains:
			-- <ul>
				-- <li><b>localCollectionId</b>: (number) The local collection ID.</li>
				-- <li><b>name</b>: (string) Name of the collection set.</li>
				-- <li><b>remoteCollectionId</b>: (number or string) The remote collection ID assigned by the server.</li>
			-- </ul> </li>
 	  -- <li><b>publishService</b>: (<a href="LrPublishService.html"><code>LrPublishService</code></a>)
	  -- 	The publish service object.</li>
	  -- <li><b>publishedCollection</b>: (<a href="LrPublishedCollection.html"><code>LrPublishedCollection</code></a>
		-- or <a href="LrPublishedCollectionSet.html"><code>LrPublishedCollectionSet</code></a>)
	  -- 	The published collection object being renamed.</li>
	  -- <li><b>remoteId</b>: (string or number) The ID for this published collection
	  -- 	that was stored via <a href="LrExportSession.html#exportSession:recordRemoteCollectionId"><code>exportSession:recordRemoteCollectionId</code></a></li>
	  -- <li><b>remoteUrl</b>: (optional, string) The URL, if any, that was recorded for the published collection via
	  -- <a href="LrExportSession.html#exportSession:recordRemoteCollectionUrl"><code>exportSession:recordRemoteCollectionUrl</code></a>.</li>
	 -- </ul>

function exportServiceProvider.renamePublishedCollection( publishSettings, info )

	if info.remoteId then

		StashAPI.renameFolder( info.remoteId, info.name )

	end
		
end

-------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called whenever a
 -- published photo is selected in the Library module. Your implementation should
 -- return true if there is a viable connection to the publish service and
 -- comments can be added at this time. If this function is not implemented,
 -- the new comment section of the Comments panel in the Library is left enabled
 -- at all times for photos published by this service. If you implement this function,
 -- it allows you to disable the Comments panel temporarily if, for example,
 -- the connection to your server is down.
 -- <p>This is not a blocking call. It is called from within a task created
 -- using the <a href="LrTasks.html"><code>LrTasks</code></a> namespace. In most
 -- cases, you should not need to start your own task within this function.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @param publishSettings (table) The settings for this publish service, as specified
		-- by the user in the Publish Manager dialog. Any changes that you make in
		-- this table do not persist beyond the scope of this function call.
	-- @return (Boolean) True if comments can be added at this time.

-- Sta.sh doesn't support comments at this time
function exportServiceProvider.canAddCommentsToService( publishSettings )

	return false

end

--------------------------------------------------------------------------------

local function updateCantExportBecause( propertyTable )

	if not propertyTable.validAccount then
		propertyTable.LR_cantExportBecause = "You haven't logged in to Sta.sh yet."
		return
	end
	
	propertyTable.LR_cantExportBecause = nil

end

local displayNameForTitleChoice = {
	filename = LOC "$$$/Stash/ExportDialog/Title/Filename=Filename",
	title = LOC "$$$/Stash/ExportDialog/Title/Title=IPTC Title",
	empty = LOC "$$$/Stash/ExportDialog/Title/Empty=Leave Blank",
}

local function getStashTitle( photo, exportSettings, pathOrMessage )

	local title
			
	-- Get title according to the options in Stash Title section.

	if exportSettings.titleFirstChoice == 'filename' then
				
		title = LrPathUtils.leafName( pathOrMessage )
				
	elseif exportSettings.titleFirstChoice == 'title' then
				
		title = photo:getFormattedMetadata 'title'
				
		if ( not title or #title == 0 ) and exportSettings.titleSecondChoice == 'filename' then
			title = LrPathUtils.leafName( pathOrMessage )
		end

	end
				
	return title

end

--------------------------------------------------------------------------------

function exportServiceProvider.getCollectionBehaviorInfo( publishSettings )

	return {
		defaultCollectionName = LOC "$$$/Stash/DefaultCollectionName/Publish to Sta.sh=Publish to Sta.sh",
		defaultCollectionCanBeDeleted = false,
		canAddCollection = true,
		maxCollectionSetDepth = 0,
			-- Collection sets are not supported in Sta.sh.
	}
	
end

-----------------------------------------------------------------------------------
 -- (optional) This plug-in defined callback function is called when the
 -- user chooses this export service provider in the Export or Publish dialog, 
 -- or when the destination is already selected when the dialog is invoked, 
 -- (remembered from the previous export operation).
 -- <p>This is a blocking call. If you need to start a long-running task (such as
 -- network access), create a task using the <a href="LrTasks.html"><code>LrTasks</code></a>
 -- namespace.</p>
 -- <p>First supported in version 1.3 of the Lightroom SDK.</p>
	-- @param propertyTable (table) An observable table that contains the most
		-- recent settings for your export or publish plug-in, including both
		-- settings that you have defined and Lightroom-defined export settings
	-- @name exportServiceProvider.startDialog
	-- @class function

function exportServiceProvider.startDialog( propertyTable )

	-- Can't export until we've validated the login.

	propertyTable:addObserver( 'validAccount', function() updateCantExportBecause( propertyTable ) end )
	updateCantExportBecause( propertyTable )

	-- Make sure we're logged in.

	require 'StashUser'
	StashUser.verifyLogin( propertyTable )

end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user 
 -- chooses this export service provider in the Export or Publish dialog. 
 -- It can create new sections that appear above all of the built-in sections 
 -- in the dialog (except for the Publish Service section in the Publish dialog, 
 -- which always appears at the very top).
 -- <p>Your plug-in's <a href="#exportServiceProvider.startDialog"><code>startDialog</code></a>
 -- function, if any, is called before this function is called.</p>
 -- <p>This is a blocking call. If you need to start a long-running task (such as
 -- network access), create a task using the <a href="LrTasks.html"><code>LrTasks</code></a>
 -- namespace.</p>
 -- <p>First supported in version 1.3 of the Lightroom SDK.</p>
	-- @param f (<a href="LrView.html#LrView.osFactory"><code>LrView.osFactory</code> object)
		-- A view factory object.
	-- @param propertyTable (table) An observable table that contains the most
		-- recent settings for your export or publish plug-in, including both
		-- settings that you have defined and Lightroom-defined export settings
	-- @return (table) An array of dialog sections (see example code for details)
	-- @name exportServiceProvider.sectionsForTopOfDialog
	-- @class function

function exportServiceProvider.sectionsForTopOfDialog( f, propertyTable )

    return {
	
		{
			title = "Sta.sh account",
			
			synopsis = bind 'accountStatus',

			f:row {
				spacing = f:control_spacing(),

				f:static_text {
					title = bind 'accountStatus',
					alignment = 'right',
					fill_horizontal = 1,
				},

				f:push_button {
					width = 90,
					title = bind 'loginButtonTitle',
					enabled = bind 'loginButtonEnabled',
					action = function()
					require 'StashUser'
					StashUser.login( propertyTable )
					end,
				},

			},
		},
	
		{
			title = LOC "$$$/Stash/ExportDialog/Title=Sta.sh Options",
			
			synopsis = function( props )
				if props.titleFirstChoice == 'title' then
					return LOC( "$$$/Stash/ExportDialog/Synopsis/TitleWithFallback=IPTC Title or ^1", displayNameForTitleChoice[ props.titleSecondChoice ] )
				else
					return props.titleFirstChoice and displayNameForTitleChoice[ props.titleFirstChoice ] or ''
				end
			end,
			
			f:column {
				spacing = f:control_spacing(),

				f:row {
					spacing = f:label_spacing(),
	
					f:static_text {
						title = LOC "$$$/Stash/ExportDialog/ChooseTitleBy=Set Stash Title Using:",
						alignment = 'right',
						width = share 'StashTitleSectionLabel',
					},
					
					f:popup_menu {
						value = bind 'titleFirstChoice',
						width = share 'StashTitleLeftPopup',
						items = {
							{ value = 'filename', title = displayNameForTitleChoice.filename },
							{ value = 'title', title = displayNameForTitleChoice.title },
							{ value = 'empty', title = displayNameForTitleChoice.empty },
						},
					},

					f:spacer { width = 20 },
	
					f:static_text {
						title = LOC "$$$/Stash/ExportDialog/ChooseTitleBySecondChoice=If Empty, Use:",
						enabled = LrBinding.keyEquals( 'titleFirstChoice', 'title', propertyTable ),
					},
					
					f:popup_menu {
						value = bind 'titleSecondChoice',
						enabled = LrBinding.keyEquals( 'titleFirstChoice', 'title', propertyTable ),
						items = {
							{ value = 'filename', title = displayNameForTitleChoice.filename },
							{ value = 'empty', title = displayNameForTitleChoice.empty },
						},
					},
				},

                f:row {
                    spacing = f:label_spacing(),

                    f:static_text {
                        title = LOC "$$$/Stash/ExportDialog/OverwriteMetadata=When updating a published photo:",
                        alignment = 'right',
                        width = share 'StashOverwriteMetadata',
                    },

                    f:popup_menu {
                        value = bind 'overwriteMetadata',
                        width = share 'StashOverwriteMetadataPopup',
                        items = {
                            { value = true, title = "Overwrite existing title, keywords and description" },
                            { value = false, title = "Leave existing title, keywords and description" },
                        },
                    },
				}
			},
		},
	}

end

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called for each exported photo
 -- after it is rendered by Lightroom and after all post-process actions have been
 -- applied to it. This function is responsible for transferring the image file 
 -- to its destination, as defined by your plug-in. The function that
 -- you define is launched within a cooperative task that Lightroom provides. You
 -- do not need to start your own task to run this function; and in general, you
 -- should not need to start another task from within your processing function.
 -- <p>First supported in version 1.3 of the Lightroom SDK.</p>
	-- @param functionContext (<a href="LrFunctionContext.html"><code>LrFunctionContext</code></a>)
		-- function context that you can use to attach clean-up behaviors to this
		-- process; this function context terminates as soon as your function exits.
	-- @param exportContext (<a href="LrExportContext.html"><code>LrExportContext</code></a>)
		-- Information about your export settings and the photos to be published.

function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
	
	-- Ensure that the auth tokens are still good
	if not (prefs.expire == nil) and (tonumber(prefs.expire) < LrDate.currentTime()) then
		StashAPI.refreshAuth()
	end

	if not StashUser.storedCredentialsAreValid() == true then
		LrErrors.throwUserError( "Something's up with your login credentials, they're not valid!" )
	end

	-- Make a local reference to the export parameters.
	local exportSession = exportContext.exportSession
	local exportSettings = assert( exportContext.propertyTable )
		
	-- Get the # of photos.
	local nPhotos = exportSession:countRenditions()
	
	-- By default, use the foldername "Lightroom Exports" with there's more than 1 image uploaded.
	-- This is the case for exporting.
	-- For publishing, the name becomes "Uploaded by Lightroom"
	local folderName = "Lightroom Exports"


	-- Setup a variable to distinguish if we're trying to publish, or just exporting
	local publishing = nil

	if exportContext.publishService then
		publishing = true

		local publishedCollectionInfo = exportContext.publishedCollectionInfo
		local isDefaultCollection = publishedCollectionInfo.isDefaultCollection

		-- Look for a folder id for this collection - determines if we've previously published this collection
		folderId = publishedCollectionInfo.remoteId

		-- However, if we're uploading from the default collection, then just dump stuff into a folder labelled
		-- "Uploaded by Lightroom"
		-- The presumed use-case of this collection is piece-meal uploading, so in virtually all cases, this is fine.
		-- However, if the user creates a collection, we'll create a corresponding folder on Sta.sh.
		if isDefaultCollection then
			folderId = nil
			local folderName = "Uploaded by Lightroom"
		else 
			folderName = publishedCollectionInfo.name
		end
		--LrDialogs.message(folderName)

	end

	-- Set progress title depending on whether we're exporting or publishing,
	-- and if we're exporting/publishing more than one photo.

	local progressScope = nil
	
	if publishing then
		progressScope = exportContext:configureProgress {
						title = nPhotos > 1
									and string.format("Publishing %s photos to Sta.sh",  nPhotos)
									or "Publishing one photo to Sta.sh",
					}
	else
	
		progressScope = exportContext:configureProgress {
						title = nPhotos > 1
									and string.format("Exporting %s photos to Sta.sh",  nPhotos)
									or "Exporting one photo to Sta.sh",
					}
	end



	-- Iterate through photo renditions.

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do
	
		-- Update progress scope.
		
		progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
		
		-- Get next photo.

		local photo = rendition.photo
		
		if publishing and rendition.publishedPhotoId then
			stashId = rendition.publishedPhotoId	
		end
		
		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()
			
			-- Update progress scope again once we've got rendered photo.
			
			progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )

			
			-- Check for cancellation again after photo has been rendered.
			
			if progressScope:isCanceled() then break end
			
			if success then
	
				-- Build up common metadata for this photo.
				
				local title = getStashTitle( photo, exportSettings, pathOrMessage )
				
				local description = photo:getFormattedMetadata( 'caption' )
				local keywordTags = photo:getFormattedMetadata( 'keywordTagsForExport' )
				
				local tags
				
				if keywordTags then

					tags = {}

					local keywordIter = string.gfind( keywordTags, "[^,]+" )

					for keyword in keywordIter do

						-- Strip non-alphanumeric characters from keyword
						if string.find( keyword, "[^%w*]") ~= nil then
							keyword = string.gsub( keyword, "[^%w*]", "" )
						end

						tags[ #tags + 1 ] = keyword

					end

				end

				-- Upload or replace the photo.

				StashInfo = StashAPI.uploadPhoto( {
										filePath = pathOrMessage,
										title = title,
										description = description,
										tags = table.concat( tags, ' ' ),
										stashid = stashId or nil,
										folderid = folderId or nil,
										foldername = folderName or nil,
                                        overwriteMetadata = exportSettings.overwriteMetadata or nil,
									} )

				
				if publishing then 
					
					if type(StashInfo.stashid) == 'number' then
						logger:info("Stashid is a number")
						StashInfo.stashid = LrStringUtils.numberToString(StashInfo.stashid)
					end

					logger:info("Uploaded photo to " .. StashInfo.stashid)
					rendition:recordPublishedPhotoId(StashInfo.stashid)
					rendition:recordPublishedPhotoUrl("http://sta.sh/1" .. StashInfo.stashid)
					
				end
				
				folderId = LrStringUtils.numberToString(StashInfo.folderid)
				
				-- When done with photo, delete temp file. There is a cleanup step that happens later,
				-- but this will help manage space in the event of a large upload.
				LrFileUtils.delete( pathOrMessage )
                prefs.uploadCount = prefs.uploadCount + 1
			
			end
			
		end

	end

	if publishing then
		logger:info("Uploaded collection to folderid: " .. folderId)
		if folderId ~= nil then
			exportSession:recordRemoteCollectionId(folderId)
		end
	end

	progressScope:done()
	
end

--------------------------------------------------------------------------------

return exportServiceProvider
