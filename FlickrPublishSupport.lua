--[[----------------------------------------------------------------------------

FlickrPublishServiceProvider.lua
Publish-specific portions of Lightroom Flickr uploader

--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007-2010 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

	-- Lightroom SDK
local LrDialogs = import 'LrDialogs'

	-- Flickr plug-in
require 'FlickrAPI'


--------------------------------------------------------------------------------

 -- NOTE to developers reading this sample code: This file is used to generate
 -- the documentation for the "publish service provider" section of the API
 -- reference material. This means it's more verbose than it would otherwise
 -- be, but also means that you can match up the documentation with an actual
 -- working example. It is not necessary for you to preserve any of the
 -- documentation comments in your own code.


--===========================================================================--
--[[ @sdk
--- The <i>service definition script</i> for a publish service provider associates 
 -- the code and hooks that extend the behavior of Lightroom's Publish features
 -- with their implementation for your plug-in. The plug-in's <code>Info.lua</code> file 
 -- identifies this script in the <code>LrExportServiceProvider</code> entry. The script
 -- must define the needed callback functions and properties (with the required
 -- names and syntax) and assign them to members of the table that it returns. 
 -- <p>The <code>FlickrPublishSupport.lua</code> file of the Flickr sample plug-in provides 
 -- 	examples of and documentation for the hooks that a plug-in must provide in order to 
 -- 	define a publish service. Because much of the functionality of a publish service
 -- 	is the same as that of an export service, this example builds upon that defined in the
 -- 	<code>FlickrExportServiceProvider.lua</code> file.</p>
  -- <p>The service definition script for a publish service should return a table that contains:
 --   <ul><li>A pair of functions that initialize and terminate your publish service. </li>
 --	<li>Optional items that define the desired customizations for the Publish dialog. 
 --	    These can restrict the built-in services offered by the dialog,
 --	    or customize the dialog by defining new sections. </li>
 --	<li> A function that defines the publish operation to be performed 
 --	     on rendered photos (required).</li> 
 --	<li> Additional functions and/or properties to customize the publish operation.</li>
 --   </ul>
 -- <p>Most of these functions are the same as those defined for an export service provider.
 -- Publish services, unlike export services, cannot create presets. (You could think of the 
 -- publish service itself as an export preset.) The settings tables passed
 -- to these callback functions contain only Lightroom-defined settings, and settings that
 -- have been explicitly declared in the <code>exportPresetFields</code> list of the publish service.
 -- A callback function that you define for a publish service cannot make any changes to the
 -- settings table passed to it.</p>
 -- @module_type Plug-in provided

	module 'SDK - Publish service provider' -- not actually executed, but suffices to trick LuaDocs

--]]


--============================================================================--

local publishServiceProvider = {}

--------------------------------------------------------------------------------
--- (string) Plug-in defined value is the filename of the icon to be displayed
 -- for this publish service provider, in the Publish Services panel, the Publish 
 -- Manager dialog, and in the header shown when a published collection is selected.
 -- The icon must be in PNG format and no more than 26 pixels wide or 19 pixels tall.
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.small_icon
	-- @class property

publishServiceProvider.small_icon = 'small_flickr.png'

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the behavior of the
 -- Description entry in the Publish Manager dialog. If the user does not provide
 -- an explicit name choice, Lightroom can provide one based on another entry
 -- in the publishSettings property table. This entry contains the name of the
 -- property that should be used in this case.
	-- @name publishServiceProvider.publish_fallbackNameBinding
	-- @class property
	
publishServiceProvider.publish_fallbackNameBinding = 'fullname'

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published collection, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Collection." </p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.titleForPublishedCollection
	-- @class property
	
publishServiceProvider.titleForPublishedCollection = LOC "$$$/Flickr/TitleForPublishedCollection=Photoset"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- collection to match the terminology used on the service you are targeting.
 -- <p>Unlike <code>titleForPublishedCollection</code>, this string is typically
 -- used by itself. In English, these strings nay be the same, but in
 -- other languages (notably German), you may have to use a different form
 -- of the name to be gramatically correct. If you are localizing your plug-in,
 -- use a separate translation key to make this possible.</p>
 -- <p>If not provided, Lightroom uses the value of
 -- <code>titleForPublishedCollection</code> instead.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.titleForPublishedCollection_standalone
	-- @class property

publishServiceProvider.titleForPublishedCollection_standalone = LOC "$$$/Flickr/TitleForPublishedCollection/Standalone=Photoset"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- smart collection to match the terminology used on the service you are targeting.
 -- <p>This string is typically used in combination with verbs that take action on
 -- the published smart collection, such as "Create ^1" or "Rename ^1".</p>
 -- <p>If not provided, Lightroom uses the default name, "Published Smart Collection." </p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
 	-- @name publishServiceProvider.titleForPublishedSmartCollection
	-- @class property

publishServiceProvider.titleForPublishedSmartCollection = LOC "$$$/Flickr/TitleForPublishedSmartCollection=Smart Photoset"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value customizes the name of a published
 -- smart collection to match the terminology used on the service you are targeting.
 -- <p>Unlike <code>titleForPublishedSmartCollection</code>, this string is typically
 -- used by itself. In English, these strings may be the same, but in
 -- other languages (notably German), you may have to use a different form
 -- of the name to be gramatically correct. If you are localizing your plug-in,
 -- use a separate translation key to make this possible.</p>
 -- <p>If not provided, Lightroom uses the value of
 -- <code>titleForPublishedSmartCollectionSet</code> instead.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.titleForPublishedSmartCollection_standalone
	-- @class property

publishServiceProvider.titleForPublishedSmartCollection_standalone = LOC "$$$/Flickr/TitleForPublishedSmartCollection/Standalone=Smart Photoset"

--------------------------------------------------------------------------------
--- (optional) If you provide this plug-in defined callback function, Lightroom calls it to
 -- retrieve the default collection behavior for this publish service, then use that information to create
 -- a built-in <i>default collection</i> for this service (if one does not yet exist). 
 -- This special collection is marked in italics and always listed at the top of the list of published collections.
 -- <p>This callback should return a table that configures the default collection. The
 -- elements of the configuration table are optional, and default as shown.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @param publishSettings (table) The settings for this publish service, as specified
		-- by the user in the Publish Manager dialog. Any changes that you make in
		-- this table do not persist beyond the scope of this function call.
	-- @return (table) A table with the following fields:
	  -- <ul>
	   -- <li><b>defaultCollectionName</b>: (string) The name for the default
	   -- 	collection. If not specified, the name is "untitled" (or
	   --   a language-appropriate equivalent). </li>
	   -- <li><b>defaultCollectionCanBeDeleted</b>: (Boolean) True to allow the 
	   -- 	user to delete the default collection. Default is true. </li>
	   -- <li><b>canAddCollection</b>: (Boolean)  True to allow the 
	   -- 	user to add collections through the UI. Default is true. </li>
	   -- <li><b>maxCollectionSetDepth</b>: (number) A maximum depth to which 
	   --  collection sets can be nested, or zero to disallow collection sets. 
 	   --  If not specified, unlimited nesting is allowed. </li>
	  -- </ul>
	-- @name publishServiceProvider.getCollectionBehaviorInfo
	-- @class function

function publishServiceProvider.getCollectionBehaviorInfo( publishSettings )

	return {
		defaultCollectionName = LOC "$$$/Flickr/DefaultCollectionName/Photostream=Photostream",
		defaultCollectionCanBeDeleted = false,
		canAddCollection = true,
		maxCollectionSetDepth = 0,
			-- Collection sets are not supported through the Flickr sample plug-in.
	}
	
end

--------------------------------------------------------------------------------
--- When set to the string "disable", the "Go to Published Collection" context-menu item
 -- is disabled (dimmed) for this publish service.
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.titleForGoToPublishedCollection
	-- @class property

publishServiceProvider.titleForGoToPublishedCollection = LOC "$$$/Flickr/TitleForGoToPublishedCollection=Show in Flickr"

--------------------------------------------------------------------------------
--- (optional, string) Plug-in defined value overrides the label for the 
 -- "Go to Published Photo" context-menu item, allowing you to use something more appropriate to
 -- your service. Set to the special value "disable" to disable (dim) the menu item for this service. 
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.titleForGoToPublishedPhoto
	-- @class property

publishServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/Flickr/TitleForGoToPublishedCollection=Show in Flickr"

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user chooses the
 -- "Go to Published Photo" context-menu item.
 -- <p>If this function is not provided, Lightroom invokes the URL recorded for the published photo via
 -- <a href="LrExportRendition.html#exportRendition:recordPublishedPhotoUrl"><code>exportRendition:recordPublishedPhotoUrl</code></a>.</p>
 -- <p>This is not a blocking call. It is called from within a task created
 -- using the <a href="LrTasks.html"><code>LrTasks</code></a> namespace. In most
 -- cases, you should not need to start your own task within this function.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.goToPublishedPhoto
	-- @class function
	-- @param publishSettings (table) The settings for this publish service, as specified
		-- by the user in the Publish Manager dialog. Any changes that you make in
		-- this table do not persist beyond the scope of this function call.
	-- @param info (table) A table with these fields:
	 -- <ul>
	  -- <li><b>publishedCollectionInfo</b>: (<a href="LrPublishedCollectionInfo.html"><code>LrPublishedCollectionInfo</code></a>)
	  --  	An object containing  publication information for this published collection.</li>
	  -- <li><b>photo</b>: (<a href="LrPhoto.html"><code>LrPhoto</code></a>) The photo object. </li>
	  -- <li><b>publishedPhoto</b>: (<a href="LrPublishedPhoto.html"><code>LrPublishedPhoto</code></a>)
	  -- 	The object that contains information previously recorded about this photo's publication.</li>
	  -- <li><b>remoteId</b>: (string or number) The ID for this published photo
	  -- 	that was stored via <a href="LrExportRendition.html#exportRendition:recordPublishedPhotoId"><code>exportRendition:recordPublishedPhotoId</code></a></li>
	  -- <li><b>remoteUrl</b>: (optional, string) The URL, if any, that was recorded for the published photo via
	  -- <a href="LrExportRendition.html#exportRendition:recordPublishedPhotoUrl"><code>exportRendition:recordPublishedPhotoUrl</code></a>.</li>
	 -- </ul>

--[[ Not used for Flickr plug-in.

function publishServiceProvider.goToPublishedPhoto( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.
 -- <p>This is not a blocking call. It is called from within a task created
 -- using the <a href="LrTasks.html"><code>LrTasks</code></a> namespace. In most
 -- cases, you should not need to start your own task within this function.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.didCreateNewPublishService
	-- @class function
	-- @param publishSettings (table) The settings for this publish service, as specified
		-- by the user in the Publish Manager dialog. Any changes that you make in
		-- this table do not persist beyond the scope of this function call.
	-- @param info (table) A table with these fields:
	 -- <ul>
	  -- <li><b>connectionName</b>: (string) the name of the newly-created service</li>
	  -- <li><b>publishService</b>: (<a href="LrPublishService.html"><code>LrPublishService</code></a>)
	  -- 	The publish service object.</li>
	 -- </ul>

--[[ Not used for Flickr plug-in.

function publishServiceProvider.didCreateNewPublishService( publishSettings, info )
end

--]]

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called when the user creates
 -- a new publish service via the Publish Manager dialog. It allows your plug-in
 -- to perform additional initialization.
 -- <p>This is not a blocking call. It is called from within a task created
 -- using the <a href="LrTasks.html"><code>LrTasks</code></a> namespace. In most
 -- cases, you should not need to start your own task within this function.</p>
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.didUpdatePublishService
	-- @class function
	-- @param publishSettings (table) The settings for this publish service, as specified
		-- by the user in the Publish Manager dialog. Any changes that you make in
		-- this table do not persist beyond the scope of this function call.
	-- @param info (table) A table with these fields:
	 -- <ul>
	  -- <li><b>connectionName</b>: (string) the name of the newly-created service</li>
	  -- <li><b>nPublishedPhotos</b>: (number) how many photos are currently published on the service</li>
	  -- <li><b>publishService</b>: (<a href="LrPublishService.html"><code>LrPublishService</code></a>)
	  -- 	The publish service object.</li>
	  -- <li><b>changedMoreThanName</b>: (boolean) true if any setting other than the name
	  --  (description) has changed</li>
	 -- </ul>

--[[ Not used for Flickr plug-in.

function publishServiceProvider.didUpdatePublishService( publishSettings, info )
end

]]--

--------------------------------------------------------------------------------
--- (optional) This plug-in defined callback function is called whenever a new
 -- publish service is created and whenever the settings for a publish service
 -- are changed. It allows the plug-in to specify which metadata should be
 -- considered when Lightroom determines whether an existing photo should be
 -- moved to the "Modified Photos to Re-Publish" status.
 -- <p>This is a blocking call.</p>
	-- @name publishServiceProvider.metadataThatTriggersRepublish
	-- @class function
	-- @param publishSettings (table) The settings for this publish service, as specified
		-- by the user in the Publish Manager dialog. Any changes that you make in
		-- this table do not persist beyond the scope of this function call.
	-- @return (table) A table containing one or more of the following elements
		-- as key, Boolean true or false as a value, where true means that a change
		-- to the value does trigger republish status, and false means changes to the
		-- value are ignored:
		-- <ul>
		  -- <li><b>default</b>: All built-in metadata that appears in XMP for the file.
		  -- You can override this default behavior by explicitly naming any of these
		  -- specific fields:
		    -- <ul>
			-- <li><b>rating</b></li>
			-- <li><b>label</b></li>
			-- <li><b>title</b></li>
			-- <li><b>caption</b></li>
			-- <li><b>gps</b></li>
			-- <li><b>gpsAltitude</b></li>
			-- <li><b>creator</b></li>
			-- <li><b>creatorJobTitle</b></li>
			-- <li><b>creatorAddress</b></li>
			-- <li><b>creatorCity</b></li>
			-- <li><b>creatorStateProvince</b></li>
			-- <li><b>creatorPostalCode</b></li>
			-- <li><b>creatorCountry</b></li>
			-- <li><b>creatorPhone</b></li>
			-- <li><b>creatorEmail</b></li>
			-- <li><b>creatorUrl</b></li>
			-- <li><b>headline</b></li>
			-- <li><b>iptcSubjectCode</b></li>
			-- <li><b>descriptionWriter</b></li>
			-- <li><b>iptcCategory</b></li>
			-- <li><b>iptcOtherCategories</b></li>
			-- <li><b>dateCreated</b></li>
			-- <li><b>intellectualGenre</b></li>
			-- <li><b>scene</b></li>
			-- <li><b>location</b></li>
			-- <li><b>city</b></li>
			-- <li><b>stateProvince</b></li>
			-- <li><b>country</b></li>
			-- <li><b>isoCountryCode</b></li>
			-- <li><b>jobIdentifier</b></li>
			-- <li><b>instructions</b></li>
			-- <li><b>provider</b></li>
			-- <li><b>source</b></li>
			-- <li><b>copyright</b></li>
			-- <li><b>rightsUsageTerms</b></li>
			-- <li><b>copyrightInfoUrl</b></li>
			-- <li><b>copyrightStatus</b></li>
			-- <li><b>keywords</b></li>
		    -- </ul>
		  -- <li><b>customMetadata</b>: All plug-in defined custom metadata (defined by any plug-in).</li>
		  -- <li><b><i>(plug-in ID)</i>.*</b>: All custom metadata defined by the plug-in with the specified ID.</li>
		  -- <li><b><i>(plug-in ID).(field ID)</i></b>: One specific custom metadata field defined by the plug-in with the specified ID.</li>
		-- </ul>

function publishServiceProvider.metadataThatTriggersRepublish( publishSettings )

	return {

		default = false,
		title = true,
		caption = true,
		keywords = true,
		gps = true,
		dateCreated = true,

		-- also (not used by Flickr sample plug-in):
			-- customMetadata = true,
			-- com.whoever.plugin_name.* = true,
			-- com.whoever.plugin_name.field_name = true,

	}

end


-------------------------------------------------------------------------------
--- This plug-in defined callback function is called when the user attempts to change the name
 -- of a collection, to validate that the new name is acceptable for this service.
 -- <p>This is a blocking call. You should use it only to validate easily-verified
 -- characteristics of the name, such as illegal characters in the name. For
 -- characteristics that require validation against a server (such as duplicate
 -- names), you should accept the name here and reject the name when the server-side operation
 -- is attempted.</p>
	-- @name publishServiceProvider.validatePublishedCollectionName
	-- @class function
 	-- @param proposedName (string) The name as currently typed in the new/rename/edit
		-- collection dialog.
	-- @return (Boolean) True if the name is acceptable, false if not
	-- @return (string) If the name is not acceptable, a string that describes the reason, suitable for display.

--[[ Not used for Flickr plug-in. --]]

-- Unknown what the Sta.sh API allows as a folder name.
function publishServiceProvider.validatePublishedCollectionName( proposedName )
	return true
end


-------------------------------------------------------------------------------
--- (Boolean) This plug-in defined value, when true, disables (dims) the Rename Published
 -- Collection command in the context menu of the Publish Services panel 
 -- for all published collections created by this service. 
 -- <p>First supported in version 3.0 of the Lightroom SDK.</p>
	-- @name publishServiceProvider.disableRenamePublishedCollection
	-- @class property
-- Unknown if Sta.sh allows folders to be renamed from Lightroom.
-- Web service it's possible, so need to check the folder name & grab that?
publishServiceProvider.disableRenamePublishedCollection = true -- not used for Flickr sample plug-in

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
-- For now, ignore the possibility of renaming the Collection (or, folders on Sta.sh)
--[[
function publishServiceProvider.renamePublishedCollection( publishSettings, info )

	if info.remoteId then

		FlickrAPI.createOrUpdatePhotoset( publishSettings, {
							photosetId = info.remoteId,
							title = info.name,
						} )

	end
		
end
]]

--------------------------------------------------------------------------------
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
function publishServiceProvider.canAddCommentsToService( publishSettings )

	return false

end

--------------------------------------------------------------------------------

FlickrPublishSupport = publishServiceProvider
