constants = require './constants'

class DropboxAuthDriver
  constructor: (@req, @res, @storage, @fail) ->
    @redirected = false

  authType: -> "code"

  url: => @req.protocol + '://' + @req.get('host') + @req.path

  doAuthorize: (authUrl, stateParam, client, callback) =>
    if !@req.query.error && !@req.query.code
      @res.redirect authUrl if !@redirected
      @redirected = true
      return

    callback @req.query

  getStateParam: (callback) =>
    @storage.get constants.STORAGE_KEY_STATE, (err, state) =>
      return @fail err if err
      callback state

module.exports = DropboxAuthDriver
