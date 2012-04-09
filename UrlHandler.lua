return {
   URLHandler = function(url)
       -- The url string sometimes actually have a double quote as
       -- the first and last byte, so strip just in case.
       url = url:gsub('^"(.*)"$', "%1")

       -- Work with url here...
       StashUser.urlHandler(url)
   end
}
