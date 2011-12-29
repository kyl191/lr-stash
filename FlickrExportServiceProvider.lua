--[[----------------------------------------------------------------------------

FlickrExportServiceProvider.lua
Export service provider description for Lightroom Flickr uploader

--------------------------------------------------------------------------------

ADOBE SYSTEMS INCORPORATED
 Copyright 2007-2010 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

function exportServiceProvider.processRenderedPhotos( functionContext, exportContext )
	
	local exportSession = exportContext.exportSession

	-- Make a local reference to the export parameters.
	
	local exportSettings = assert( exportContext.propertyTable )
		
	-- Get the # of photos.
	
	local nPhotos = exportSession:countRenditions()
	
	-- Set progress title.
	
	local progressScope = exportContext:configureProgress {
						title = nPhotos > 1
									and LOC( "$$$/Flickr/Publish/Progress=Publishing ^1 photos to Flickr", nPhotos )
									or LOC "$$$/Flickr/Publish/Progress/One=Publishing one photo to Flickr",
					}

	-- Save off uploaded photo IDs so we can take user to those photos later.
	
	local uploadedPhotoIds = {}
	
	local publishedCollectionInfo = exportContext.publishedCollectionInfo

	local isDefaultCollection = publishedCollectionInfo.isDefaultCollection

	-- Look for a photoset id for this collection.

	local photosetId = publishedCollectionInfo.remoteId

	-- Get a list of photos already in this photoset so we know which ones we can replace and which have
	-- to be re-uploaded entirely.

	local photosetPhotoIds = photosetId and FlickrAPI.listPhotosFromPhotoset( exportSettings, { photosetId = photosetId } )
	
	local photosetPhotosSet = {}
	
	-- Turn it into a set for quicker access later.

	if photosetPhotoIds then
		for _, id in ipairs( photosetPhotoIds ) do	
			photosetPhotosSet[ id ] = true
		end
	end
	
	local couldNotPublishBecauseFreeAccount = {}
	local flickrPhotoIdsForRenditions = {}
	
	local cannotRepublishCount = 0
	
	-- Gather flickr photo IDs, and if we're on a free account, remember the renditions that
	-- had been previously published.

	for i, rendition in exportContext.exportSession:renditions() do
	
		local flickrPhotoId = rendition.publishedPhotoId
			
		if flickrPhotoId then
		
			-- Check to see if the photo is still on Flickr.

			if not photosetPhotosSet[ flickrPhotoId ] and not isDefaultCollection then
				flickrPhotoId = nil
			end
			
		end
		
		if flickrPhotoId and not exportSettings.isUserPro then
			couldNotPublishBecauseFreeAccount[ rendition ] = true
			cannotRepublishCount = cannotRepublishCount + 1
		end
			
		flickrPhotoIdsForRenditions[ rendition ] = flickrPhotoId
	
	end
	
	-- If we're on a free account, see which photos are being republished and give a warning.
	
	if cannotRepublishCount	> 0 then

		local message = ( cannotRepublishCount == 1 ) and 
							LOC( "$$$/Flickr/FreeAccountErr/Singular/ThereIsAPhotoToUpdateOnFlickr=There is one photo to update on Flickr" )
							or LOC( "$$$/Flickr/FreeAccountErr/Plural/ThereIsAPhotoToUpdateOnFlickr=There are ^1 photos to update on Flickr", cannotRepublishCount )

		local messageInfo = LOC( "$$$/Flickr/FreeAccountErr/Singular/CommentsAndRatingsWillBeLostWarning=With a free (non-Pro) Flickr account, all comments and ratings will be lost on updated photos. Are you sure you want to do this?" )
		
		local action = LrDialogs.promptForActionWithDoNotShow { 
									message = message,
									info = messageInfo, 
									actionPrefKey = "nonProRepublishWarning", 
									verbBtns = { 
										{ label = LOC( "$$$/Flickr/Dialog/Buttons/FreeAccountErr/Skip=Skip" ), verb = "skip", },
										{ label = LOC( "$$$/Flickr/Dialog/Buttons/FreeAccountErr/Replace=Replace" ), verb = "replace", },
									}
                                } 

		if action == "skip" then
			
			local skipRendition = next( couldNotPublishBecauseFreeAccount )
			
			while skipRendition ~= nil do
				skipRendition:skipRender()
				skipRendition = next( couldNotPublishBecauseFreeAccount, skipRendition )
			end
			
		elseif action == "replace" then

			-- We will publish as usual, replacing these photos.

			couldNotPublishBecauseFreeAccount = {}

		else

			-- User canceled

			progressScope:done()
			return

		end

	end
	
	-- Iterate through photo renditions.
	
	local photosetUrl

	for i, rendition in exportContext:renditions { stopIfCanceled = true } do
	
		-- Update progress scope.
		
		progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
		
		-- Get next photo.

		local photo = rendition.photo

		-- See if we previously uploaded this photo.

		local flickrPhotoId = flickrPhotoIdsForRenditions[ rendition ]
		
		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()
			
			-- Update progress scope again once we've got rendered photo.
			
			progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
			
			-- Check for cancellation again after photo has been rendered.
			
			if progressScope:isCanceled() then break end
			
			if success then
	
				-- Build up common metadata for this photo.
				
				local title = getFlickrTitle( photo, exportSettings, pathOrMessage )
		
				local description = photo:getFormattedMetadata( 'caption' )
				local keywordTags = photo:getFormattedMetadata( 'keywordTagsForExport' )
				
				local tags
				
				if keywordTags then

					tags = {}

					local keywordIter = string.gfind( keywordTags, "[^,]+" )

					for keyword in keywordIter do
					
						if string.sub( keyword, 1, 1 ) == ' ' then
							keyword = string.sub( keyword, 2, -1 )
						end
						
						if string.find( keyword, ' ' ) ~= nil then
							keyword = '"' .. keyword .. '"'
						end
						
						tags[ #tags + 1 ] = keyword

					end

				end
				
				-- Flickr will pick up LR keywords from XMP, so we don't need to merge them here.
				
				local is_public = privacyToNumber[ exportSettings.privacy ]
				local is_friend = booleanToNumber( exportSettings.privacy_friends )
				local is_family = booleanToNumber( exportSettings.privacy_family )
				local safety_level = safetyToNumber[ exportSettings.safety ]
				local content_type = contentTypeToNumber[ exportSettings.type ]
				local hidden = exportSettings.hideFromPublic and 2 or 1
				
				-- Because it is common for Flickr users (even viewers) to add additional tags via
				-- the Flickr web site, so we should not remove extra keywords that do not correspond
				-- to keywords in Lightroom. In order to do so, we record the tags that we uploaded
				-- this time. Next time, we will compare the previous tags with these current tags.
				-- We use the difference between tag sets to determine if we should remove a tag (i.e.
				-- it was one we uploaded and is no longer present in Lightroom) or not (i.e. it was
				-- added by user on Flickr and never was present in Lightroom).
				
				local previous_tags = photo:getPropertyForPlugin( _PLUGIN, 'previous_tags' ) 
	
				-- If on a free account and this photo already exists, delete it from Flickr.

				if flickrPhotoId and not exportSettings.isUserPro then

					FlickrAPI.deletePhoto( exportSettings, { photoId = flickrPhotoId, suppressError = true } )
					flickrPhotoId = nil

				end
				
				-- Upload or replace the photo.
				
				local didReplace = not not flickrPhotoId
				
				flickrPhotoId = FlickrAPI.uploadPhoto( exportSettings, {
										photo_id = flickrPhotoId,
										filePath = pathOrMessage,
										title = title or '',
										description = description,
										tags = table.concat( tags, ',' ),
										is_public = is_public,
										is_friend = is_friend,
										is_family = is_family,
										safety_level = safety_level,
										content_type = content_type,
										hidden = hidden,
									} )
				
				if didReplace then
				
					-- The replace call used by FlickrAPI.uploadPhoto ignores all of the metadata that is passed
					-- in above. We have to manually upload that info after the fact in this case.
					
					if exportSettings.titleRepublishBehavior == 'replace' then
						
						FlickrAPI.callRestMethod( exportSettings, {
												method = 'flickr.photos.setMeta',
												photo_id = flickrPhotoId,
												title = title or '',
												description = description or '',
											} )
											
					end
	
					FlickrAPI.callRestMethod( exportSettings, {
											method = 'flickr.photos.setPerms',
											photo_id = flickrPhotoId,
											is_public = is_public,
											is_friend = is_friend,
											is_family = is_family,
											perm_comment = 3, -- everybody
											perm_addmeta = 3, -- everybody
										} )
	
					FlickrAPI.callRestMethod( exportSettings, {
											method = 'flickr.photos.setSafetyLevel',
											photo_id = flickrPhotoId,
											safety_level = safety_level,
											hidden = hidden,
										} )
	
					FlickrAPI.callRestMethod( exportSettings, {
											method = 'flickr.photos.setContentType',
											photo_id = flickrPhotoId,
											content_type = content_type,
										} )
		
				end
	
				FlickrAPI.setImageTags( exportSettings, {
											photo_id = flickrPhotoId,
											tags = table.concat( tags, ',' ),
											previous_tags = previous_tags,
											is_public = is_public,
										} )
				
				-- When done with photo, delete temp file. There is a cleanup step that happens later,
				-- but this will help manage space in the event of a large upload.
					
				LrFileUtils.delete( pathOrMessage )
	
				-- Remember this in the list of photos we uploaded.
	
				uploadedPhotoIds[ #uploadedPhotoIds + 1 ] = flickrPhotoId
				
				-- If this isn't the Photostream, set up the photoset.
				
				if not photosetUrl then
	
					if not isDefaultCollection then
	
						-- Create or update this photoset.
	
						photosetId, photosetUrl = FlickrAPI.createOrUpdatePhotoset( exportSettings, {
													photosetId = photosetId,
													title = publishedCollectionInfo.name,
													--		description = ??,
													primary_photo_id = uploadedPhotoIds[ 1 ],
												} )
				
					else
	
						-- Photostream: find the URL.
	
						photosetUrl = FlickrAPI.constructPhotostreamURL( exportSettings )
	
					end
					
				end
				
				-- Record this Flickr ID with the photo so we know to replace instead of upload.
					
				rendition:recordPublishedPhotoId( flickrPhotoId )
				
				local photoUrl
							
				if ( not isDefaultCollection ) then
					
					photoUrl = FlickrAPI.constructPhotoURL( exportSettings, {	
											photo_id = flickrPhotoId,
											photosetId = photosetId,
											is_public = is_public,
										} )	
										
					-- Add the uploaded photos to the correct photoset.

					FlickrAPI.addPhotosToSet( exportSettings, {
									photoId = flickrPhotoId,
									photosetId = photosetId,
								} )
					
				else
					
					photoUrl = FlickrAPI.constructPhotoURL( exportSettings, {
											photo_id = flickrPhotoId,
											is_public = is_public,
										} )
										
				end
					
				rendition:recordPublishedPhotoUrl( photoUrl )
						
				-- Because it is common for Flickr users (even viewers) to add additional tags
				-- via the Flickr web site, so we can avoid removing those user-added tags that
				-- were never in Lightroom to begin with. See earlier comment.
				
				photo.catalog:withPrivateWriteAccessDo( function()
										photo:setPropertyForPlugin( _PLUGIN, 'previous_tags', table.concat( tags, ',' ) ) 
									end )
			
			end
			
		end

	end
	
	if #uploadedPhotoIds > 0 then
	
		if ( not isDefaultCollection ) then
			
			exportSession:recordRemoteCollectionId( photosetId )
					
		end
	
		-- Set up some additional metadata for this collection.

		exportSession:recordRemoteCollectionUrl( photosetUrl )
		
	end

	progressScope:done()
	
end

--------------------------------------------------------------------------------

return exportServiceProvider
