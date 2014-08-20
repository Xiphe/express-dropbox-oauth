constants = require './constants'

class ExpressDropboxAuthDriver
  constructor: (@req, @res, @storage, @fail) ->
    @redirected = false

  authType: -> "code"

  url: => @req.url

  doAuthorize: (authUrl, stateParam, client, callback) =>
    if !@req.query.error && !@req.query.code
      @res.redirect authUrl if !@redirected
      @redirected = true
      return
    if @req.query.code
      @storage.set constants.STORAGE_KEY_TOKEN, @req.query.code, (err = null) =>
        return @fail err if err
        callback @req.query
    else
      callback @req.query

  getStateParam: (callback) =>
    @storage.get constants.STORAGE_KEY_STATE, (err, state) =>
      return @fail err if err
      callback state

module.exports = ExpressDropboxAuthDriver
