Dropbox = require 'dropbox'
helpers = require './helpers'
constants = require './constants'
DropboxAuthDriver = require './DropboxAuthDriver'
StorageNedbAdapter = require './storage/NedbAdapter'

class ExpressDropboxOAuth
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

      step2 = =>
        if !req.query.code and !req.query.error
          @logout()(req, res, step3)
        else
          step3()

      step3 = =>
        helpers.getStateParam req, @storage, (err, state) =>
          return fail err if err

          driver = new DropboxAuthDriver req, res, @storage, fail

          @dropboxClient.authDriver driver
          @dropboxClient.authenticate (err, client) =>
            @storage.delete constants.STORAGE_KEY_STATE
            return fail err if err
            @storage.set constants.STORAGE_KEY_TOKEN, client.credentials().token, (err) =>
              return fail err if err
              @checkAuth(failCb)(req, res, next)

      @checkAuth(step2)(req, res, next)

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

ExpressDropboxOAuth.StorageNedbAdapter = StorageNedbAdapter
module.exports = ExpressDropboxOAuth
