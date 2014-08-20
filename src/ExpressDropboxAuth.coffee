Dropbox = require 'dropbox'
helpers = require './helpers'
constants = require './constants'
ExpressDropboxAuthDriver = require './ExpressDropboxAuthDriver'

class ExpressDropboxAuth
  constructor: (credentials, @storage) ->
    @Dropbox = Dropbox
    @dropboxClient = new Dropbox.Client credentials

  checkAuth: (failCb) ->
    if !helpers.isFunction failCb
      failCb = (err, req, res, next) ->
        res.send constants.HTTP_CODE_UNAUTHORIZED

    return (req, res, next) =>
      fail = (err) -> failCb(err, req, res, next)

      @storage.get constants.STORAGE_KEY_TOKEN, (err, token) =>
        helpers.setDropboxCredentials @dropboxClient, token if !err and token.length

        if @dropboxClient.isAuthenticated()
          @dropboxClient.getUserInfo (err, user) ->
            if err then fail err else next()
        else
          fail new Error 'Client not authenticated.'

  doAuth: (failCb) ->
    if !helpers.isFunction failCb
      failCb = (err, req, res, next) ->
        res.send constants.HTTP_CODE_UNAUTHORIZED

    return (req, res, next) =>
      fail = (err) -> failCb(err, req, res, next)

      unauthCb = =>
        helpers.getStateParam req, @storage, (err, state) =>
          return fail err if err

          driver = new ExpressDropboxAuthDriver req, res, @storage, fail

          @dropboxClient.authDriver driver
          @dropboxClient.authenticate (error, client) =>
            @checkAuth(failCb)(req, res, next)


      @checkAuth(unauthCb)(req, res, next)

  logout: (failCb) ->
    if !helpers.isFunction failCb
      failCb = (err, req, res, next) ->
        res.send constants.HTTP_CODE_INTERNAL_SERVER_ERROR

    return (req, res, next) =>
      fail = (err) -> failCb(err, req, res, next)

      @dropboxClient.reset()

      helpers.deleteStateAndKey @storage, (errors) ->
        return fail new Error "" + errors if errors.length
        next()

module.exports = ExpressDropboxAuth
