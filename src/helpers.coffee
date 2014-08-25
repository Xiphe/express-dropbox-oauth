constants = require './constants'
Dropbox = require 'dropbox'

module.exports =
  isFunction: (token) ->
    return token instanceof Function

  setDropboxCredentials: (dropbox, token) =>
    credentials = dropbox.credentials()
    credentials.token = token
    dropbox.setCredentials credentials

    return token

  getStateParam: (req, storage, next) ->
    return next null, req.query.state if req.query.state

    state = Dropbox.Util.Oauth.randomAuthStateParam()
    storage.set constants.STORAGE_KEY_STATE, state, (err = null) ->
      next err, state

  deleteStateAndKey: (storage, next) ->
    cueue = 1
    errors = []

    step = ->
      return cueue -= 1 if cueue > 0
      next errors

    storage.remove constants.STORAGE_KEY_STATE, (err) ->
      errors.push err if err
      step()

    storage.remove constants.STORAGE_KEY_TOKEN, (err) ->
      errors.push err if err
      step()
