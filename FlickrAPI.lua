--[[----------------------------------------------------------------------------

FlickrAPI.lua
Common code to initiate Flickr API requests

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

local logger = import 'LrLogger'( 'FlickrAPI' )


--============================================================================--

--------------------------------------------------------------------------------

function FlickrAPI.uploadPhoto( propertyTable, params )

	-- Prepare to upload.
	
	assert( type( params ) == 'table', 'FlickrAPI.uploadPhoto: params must be a table' )
	
	local postUrl = params.photo_id and 'http://flickr.com/services/replace/' or 'http://flickr.com/services/upload/'
	local originalParams = params.photo_id and table.shallowcopy( params )

	logger:info( 'uploading photo', params.filePath )

	local filePath = assert( params.filePath )
	params.filePath = nil
	
	local fileName = LrPathUtils.leafName( filePath )
	
	params.auth_token = params.auth_token or propertyTable.auth_token
	
	params.tags = string.gsub( params.tags, ",", " " )
	
	params.api_sig = FlickrAPI.makeApiSignature( params )
	
	local mimeChunks = {}
	
	for argName, argValue in pairs( params ) do
		if argName ~= 'api_sig' then
			mimeChunks[ #mimeChunks + 1 ] = { name = argName, value = argValue }
		end
	end

	mimeChunks[ #mimeChunks + 1 ] = { name = 'api_sig', value = params.api_sig }
	mimeChunks[ #mimeChunks + 1 ] = { name = 'photo', fileName = fileName, filePath = filePath, contentType = 'application/octet-stream' }
	
	-- Post it and wait for confirmation.
	
	local result, hdrs = LrHttp.postMultipart( postUrl, mimeChunks )
	
	if not result then
	
		if hdrs and hdrs.error then
			LrErrors.throwUserError( formatError( hdrs.error.nativeCode ) )
		end
		
	end
	
	-- Parse Flickr response for photo ID.

	local simpleXml = xmlElementToSimpleTable( result )
	if simpleXml.stat == 'ok' then

		return simpleXml.photoid._value
	
	elseif params.photo_id and simpleXml.err and tonumber( simpleXml.err.code ) == 7 then
	
		-- Photo is missing. Most likely, the user deleted it outside of Lightroom. Just repost it.
		
		originalParams.photo_id = nil
		return FlickrAPI.uploadPhoto( propertyTable, originalParams )
	
	else

		LrErrors.throwUserError( LOC( "$$$/Flickr/Error/API/Upload=Flickr API returned an error message (function upload, message ^1)",
							tostring( simpleXml.err and simpleXml.err.msg ) ) )

	end

end

--------------------------------------------------------------------------------

local function getPhotoInfo( propertyTable, params )

	local data, response
	
	if params.is_public == 1 then
	
		data, response = FlickrAPI.callRestMethod( nil, {
									method = 'flickr.photos.getInfo',
									photo_id = params.photo_id,
									skipAuthToken = true,
								} )
	else
	
		-- http://flickr.com/services/api/flickr.photos.getFavorites.html
		
		data = FlickrAPI.callRestMethod( propertyTable, {
							method = 'flickr.photos.getFavorites',
							photo_id = params.photo_id,
							per_page = 1,
							suppressError = true,
						} )
						
		if data.stat ~= "ok" then
		
			return
			
		else
			
			local secret = data.photo.secret
		
			data,response = FlickrAPI.callRestMethod( nil, {
									method = 'flickr.photos.getInfo',
									photo_id = params.photo_id,
									skipAuthToken = true,
									secret = secret,
								} )
		end
		
	end
	
	return data, response

end

--------------------------------------------------------------------------------

function FlickrAPI.constructPhotoURL( propertyTable, params )

	local data = getPhotoInfo( propertyTable, params )
							
	local photoUrl = data and data.photo and data.photo.urls and data.photo.urls.url and data.photo.urls.url._value
	
	if params.photosetId then

		if photoUrl:sub( -1 ) ~= '/' then
			photoUrl = photoUrl .. "/"
		end
	
		return photoUrl .. "in/set-" .. params.photosetId
		
	else
	
		return photoUrl
		
	end
	
end

--------------------------------------------------------------------------------

function FlickrAPI.constructPhotosetURL( propertyTable, photosetId )

	return "http://www.flickr.com/photos/" .. propertyTable.nsid .. "/sets/" .. photosetId

end


--------------------------------------------------------------------------------

function FlickrAPI.constructPhotostreamURL( propertyTable )

	return "http://www.flickr.com/photos/" .. propertyTable.nsid .. "/"

end

-------------------------------------------------------------------------------

local function traversePhotosetsForTitle( node, title )

	local nodeType = string.lower( node:type() )

	if nodeType == 'element' then
		
		if node:name() == 'photoset' then
		
			local _, photoset = traverse( node )
			
			local psTitle = photoset.title
			if type( psTitle ) == 'table' then
				psTitle = psTitle._value
			end
			
			if psTitle == title then
				return photoset.id
			end
		
		else
		
			local count = node:childCount()
			for i = 1, count do
				local photosetId = traversePhotosetsForTitle( node:childAtIndex( i ), title )
				if photosetId then
					return photosetId
				end
			end
			
		end

	end

end

--------------------------------------------------------------------------------

function FlickrAPI.createOrUpdatePhotoset( propertyTable, params )
	
	local needToCreatePhotoset = true
	local data, response
	
	if params.photosetId then

		data, response = FlickrAPI.callRestMethod( propertyTable, {
								method = 'flickr.photosets.getInfo',
								photoset_id = params.photosetId,
								suppressError = true,
							} )
							
		if data and data.photoset then
			needToCreatePhotoset = false
			params.primary_photo_id = params.primary_photo_id or data.photoset.primary
		end

	else

		data, response = FlickrAPI.callRestMethod( propertyTable, {
								method = 'flickr.photosets.getList',
							} )

		local photosetsNode = LrXml.parseXml( response )
		
		local photosetId = traversePhotosetsForTitle( photosetsNode, params.title )
		
		if photosetId then
			params.photosetId = photosetId
			needToCreatePhotoset = false
		end
	
	end
	
	if needToCreatePhotoset then
		data, response = FlickrAPI.callRestMethod( propertyTable, { 
								method = 'flickr.photosets.create', 
								title = params.title, 
								description = params.description,
								primary_photo_id = params.primary_photo_id,
							} )
	else
		data, response = FlickrAPI.callRestMethod( propertyTable, { 
								method = 'flickr.photosets.editMeta', 
								photoset_id = params.photosetId,
								title = params.title, 
								description = params.description,
							} )
	end
	
	if not needToCreatePhotoset then
		return params.photosetId, FlickrAPI.constructPhotosetURL( propertyTable, params.photosetId )
	else
		return data.photoset.id, data.photoset.url
	end
end

--------------------------------------------------------------------------------

function FlickrAPI.listPhotosFromPhotoset( propertyTable, params )
	
	local results = {}
	local data, response
	local numPages, curPage = 1, 0
	
	while curPage < numPages do

		curPage = curPage + 1
		
		data, response = FlickrAPI.callRestMethod( propertyTable, {
								method = 'flickr.photosets.getPhotos',
								photoset_id = params.photosetId,
								page = curPage,
								suppressError = true,
							} )

		if data.stat ~= "ok" then
			return
		end

		-- Break out the XSLT here, as the simple parser isn't going to work for us.
		-- (since we're getting multiple items back).

		local xslt = [[
					<xsl:stylesheet
						version="1.0"
						xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
					>
					<xsl:output method="text"/>
					<xsl:template match="*">
						return {<xsl:apply-templates />
						}
					</xsl:template>
					<xsl:template match="photoset">
							photoset = {
								id = "<xsl:value-of select="@id"/>",
								primary = "<xsl:value-of select="@primary"/>",
								owner = "<xsl:value-of select="@owner"/>",
								ownername = "<xsl:value-of select="@ownername"/>",
								page = "<xsl:value-of select="@page"/>",
								per_page = "<xsl:value-of select="@per_page"/>",
								pages = "<xsl:value-of select="@pages"/>",
								total = "<xsl:value-of select="@total"/>",
								
								photos = { 
									<xsl:for-each select="photo">
										{ id = "<xsl:value-of select="@id"/>", 
											title = "<xsl:value-of select="@title"/>", 
											isprimary = "<xsl:value-of select="@isprimary"/>", },
									</xsl:for-each>
								},
							},
					</xsl:template>
					</xsl:stylesheet>
				]]
				
		local resultElement = LrXml.parseXml( response )
		local luaTableString = resultElement and resultElement:transform( xslt )

		local luaTableFunction = luaTableString and loadstring( luaTableString )

		if luaTableFunction then

			local photoListTable = LrFunctionContext.callWithEmptyEnvironment( luaTableFunction )

			if photoListTable then

				for i, v in ipairs( photoListTable.photoset.photos ) do
					table.insert( results, v.id )
				end
				
				numPages = tonumber( photoListTable.photoset.pages ) or 1
				
				results.primary = photoListTable.photoset.primary

			end

		end
		
	end
	
	return results

end

--------------------------------------------------------------------------------

function FlickrAPI.setPhotosetSequence( propertyTable, params )

	local photosetId = assert( params.photosetId )
	local primary = assert( params.primary )
	local photoIds = table.concat( params.photoIds, ',' )
	
	FlickrAPI.callRestMethod( propertyTable, {
								method = 'flickr.photosets.editPhotos',
								photoset_id = photosetId,
								primary_photo_id = primary,
								photo_ids = photoIds,
							} )

end		

--------------------------------------------------------------------------------

function FlickrAPI.addPhotosToSet( propertyTable, params )
	
	local data, response
			
	-- http://flickr.com/services/api/flickr.photosets.addPhoto.html

	data, response = FlickrAPI.callRestMethod( propertyTable, {
								method = 'flickr.photosets.addPhoto',
								photoset_id = params.photosetId,
								photo_id = params.photoId,
								suppressError = true,
							} )
							
	-- If there was an error, only stop if the error was not #2 or #3 (those aren't critical).

	if data.stat ~= "ok" then

		if data.err then

			local code = tonumber( data.err.code )

			if code ~= 2 and code ~= 3 then
	
				LrErrors.throwUserError( LOC( "$$$/Flickr/Error/API=Flickr API returned an error message (function ^1, message ^2)",
										'flickr.photosets.addPhoto',
										tostring( response.err and response.err.msg ) ) )

			end

		else

			return false

		end

	end
	
	return true

end	

