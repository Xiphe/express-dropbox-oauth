ANY = /.*/

class StorageNedbAdapter
  constructor: (@database, @userId = null) ->
  _obj: (key, value) ->
    obj = {}
    obj[key] = value
    obj['userId'] = @userId if @userId
    obj

  set: (key, value, callback) ->
    previous = @_obj key, ANY
    update = @_obj key, value
    options = upsert: true

    @database.update previous, update, options, (err) -> callback? err

  get: (key, callback) ->
    @database.find @_obj(key, ANY), (err, docs) =>
      return callback? err if err

      if !err and !docs.length or !docs[0][key]
        return callback? new Error "No entries of '#{key}' found" + if @userId then " for user '#{@userId}'." else ''

      callback? null, docs[0][key]

  delete: (key, callback) ->
    @database.remove @_obj(key, ANY), (err) -> callback? err

StorageNedbAdapter.ANY = ANY
module.exports = StorageNedbAdapter
