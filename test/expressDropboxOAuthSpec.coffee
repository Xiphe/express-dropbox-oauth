describe 'ExpressDropboxOAuth', ->
  request = require 'supertest'
  appFactory = require './testApp'
  Dropbox = require 'dropbox'
  ExpressDropboxOAuth = require './../src/index'
  constants = require './../src/constants'

  ENDPOINT_AUTH = '/auth'
  ENDPOINT_LOGOUT = '/logout'
  EMPTY_DB_ERROR = new Error 'Not Found'

  fakeStorageGetCalls =
    state: (done) -> done? EMPTY_DB_ERROR
    token: (done) -> done? EMPTY_DB_ERROR

  fakeStorageSetCalls =
    state: (value, done) -> done?()
    token: (value, done) -> done?()

  fakeStorage =
    set: (key, value, done) ->
      if key == constants.STORAGE_KEY_STATE
        fakeStorageSetCalls.state(value, done)
      else
        fakeStorageSetCalls.token(value, done)
    get: (key, done) ->
      if key == constants.STORAGE_KEY_STATE then fakeStorageGetCalls.state(done) else fakeStorageGetCalls.token(done)
    remove: (key, done) -> done?()

  assumeStoredState = (state) ->
    sinon.stub(fakeStorageGetCalls, 'state').callsArgWithAsync 0, null, state

  assumeStoredToken = (token) ->
    sinon.stub(fakeStorageGetCalls, 'token').callsArgWithAsync 0, null, token

  assumeSuccessfullAuth = (code) ->
    sinon.stub(expressDropboxOAuth.dropboxClient, 'credentials').returns {token: code}
    sinon.stub(expressDropboxOAuth.dropboxClient, 'authenticate')
      .callsArgWithAsync 0, null, expressDropboxOAuth.dropboxClient

  app = null
  xhrStub = null
  expectXhr = false
  expressDropboxOAuth = null
  beforeEach ->
    app = appFactory()
    xhrStub = sinon.stub Dropbox.Client.prototype, '_dispatchXhr'
    expectXhr = false
    expressDropboxOAuth = new ExpressDropboxOAuth key: 'myKey', secret: 'mySecret', fakeStorage

    xhrStub.callsArgWithAsync 1, new Dropbox.ApiError {status: 400}, 'POST', 'http://example.org'

  afterEach ->
    if !expectXhr
      xhrStub.should.not.have.been.called
    else
      xhrStub.should.have.been.called
      xhrStub.callCount.should.equal expectXhr

  it 'should expose Dropbox', ->
    expressDropboxOAuth.Dropbox.should.equal Dropbox

  it 'should expose the dropboxClient', ->
    expressDropboxOAuth.dropboxClient.should.be.an.instanceof Dropbox.Client

  describe 'checkAuth', ->
    someResponse = 'Hello Authenticated World'

    it 'should send Unauthorized response by default', (done) ->
      app.get ENDPOINT_AUTH, expressDropboxOAuth.checkAuth()

      request app
        .get ENDPOINT_AUTH
        .expect 401, done

    it 'should do nothing if user is authenticated', (done) ->
      app.get ENDPOINT_AUTH, expressDropboxOAuth.checkAuth(), (req, res) -> res.send someResponse
      sinon.stub(expressDropboxOAuth.dropboxClient, 'isAuthenticated').returns true
      sinon.stub(expressDropboxOAuth.dropboxClient, 'getUserInfo').callsArgAsync 0

      request app
        .get ENDPOINT_AUTH
        .expect someResponse
        .expect 200, done

    it 'should try to get the auth-token from storage', (done) ->
      sinon.spy fakeStorage, 'get'
      app.get ENDPOINT_AUTH, expressDropboxOAuth.checkAuth()

      request app
        .get ENDPOINT_AUTH
        .end (err) ->
          fakeStorage.get.should.have.been.calledWith constants.STORAGE_KEY_TOKEN
          done err

    it 'should set the auth-token to client when found', (done) ->
      expectXhr = 1
      fakeToken = 'someFakeToken'
      assumeStoredToken fakeToken

      setCredentialsSpy = sinon.spy expressDropboxOAuth.dropboxClient, 'setCredentials'

      app.get ENDPOINT_AUTH, expressDropboxOAuth.checkAuth()

      request app
        .get ENDPOINT_AUTH
        .end (err) ->
          setCredentialsSpy.should.have.been.called
          setCredentialsSpy.getCall(0).args[0].token.should.equal fakeToken
          done err

    it 'should invoke a given callback on fail', (done) ->
      myCallback = sinon.spy (err, req, res) ->
        res.send someResponse
      app.get ENDPOINT_AUTH, expressDropboxOAuth.checkAuth myCallback

      request app
        .get ENDPOINT_AUTH
        .expect someResponse
        .expect 200
        .end (err) ->
          myCallback.should.have.been.called
          done err

  describe 'doAuth', ->
    it 'should checkAuth at first', (done) ->
      sinon.spy expressDropboxOAuth, 'checkAuth'

      app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

      request app
        .get ENDPOINT_AUTH
        .end (err) ->
          expressDropboxOAuth.checkAuth.should.have.been.called
          done err

    describe 'state', ->
      it 'should create a state parameter', (done) ->
        sinon.spy expressDropboxOAuth.Dropbox.Util.Oauth, 'randomAuthStateParam'

        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .end (err) ->
            expressDropboxOAuth.Dropbox.Util.Oauth.randomAuthStateParam.should.have.been.called
            done err

      it 'should tell the storage to set the state parameter', (done) ->
        fakeState = 'someState'
        sinon.stub(expressDropboxOAuth.Dropbox.Util.Oauth, 'randomAuthStateParam').returns fakeState
        sinon.spy fakeStorage, 'set'

        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .end (err) ->
            fakeStorage.set.should.have.been.calledWith constants.STORAGE_KEY_STATE, fakeState
            done err

      it 'should not create a state parameter when present in request nor set it', (done) ->
        fakeState = 'someState'
        sinon.spy expressDropboxOAuth.Dropbox.Util.Oauth, 'randomAuthStateParam'
        sinon.spy fakeStorage, 'set'

        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .query state: fakeState
          .end (err) ->
            expressDropboxOAuth.Dropbox.Util.Oauth.randomAuthStateParam.should.not.have.been.called
            fakeStorage.set.should.not.have.been.called
            done err

      it 'should fail when the storage fails to set the state', (done) ->
        sinon.stub(fakeStorage, 'set').callsArgWithAsync 2, new Error 'something went wrong'

        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .expect 401, done


    it 'should set a new authDriver to dropbox', (done) ->
      sinon.spy expressDropboxOAuth.dropboxClient, 'authDriver'

      app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

      request app
        .get ENDPOINT_AUTH
        .end (err) ->
          expressDropboxOAuth.dropboxClient.authDriver.should.have.been.called
          done err

    describe 'AuthDriver', ->
      req = null
      res = null

      getDriver = (callback) ->
        request app
          .get ENDPOINT_AUTH
          .end (err) ->
            expressDropboxOAuth.dropboxClient.authDriver.should.have.been.called
            callback err, expressDropboxOAuth.dropboxClient.authDriver.getCall(0).args[0]

      beforeEach ->
        req = null
        res = null
        setReqRes = (rq, rs, next) ->
          req = rq
          res = rs
          next()

        sinon.spy expressDropboxOAuth.dropboxClient, 'authDriver'
        app.get ENDPOINT_AUTH, setReqRes, expressDropboxOAuth.doAuth()

      it 'should be of type code', (done) ->
        getDriver (err, driver) ->
          driver.authType().should.equal 'code'
          done err

      it 'should use the current url', (done) ->
        getDriver (err, driver) ->
          driver.url().should.equal  req.protocol + '://' + req.get('host') + ENDPOINT_AUTH
          done err

      it 'should use the storage to get the state parameter', (done) ->
        fakeState = 'someState'
        assumeStoredState fakeState

        getDriver (err, driver) ->
          driver.getStateParam (param) ->
            param.should.equal fakeState
            done err

    it 'should redirect to dropbox when authorizing without a code param', (done) ->
      assumeStoredState 'myState'
      app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

      request app
        .get ENDPOINT_AUTH
        .expect 'location', /www\.dropbox\.com/
        .expect 302, done

    it 'should fail when authenticate fails', (done) ->
      someError = new Error 'hello'
      response = 'failed'
      sinon.stub(expressDropboxOAuth.dropboxClient, 'authenticate')
        .callsArgWithAsync 0, someError

      app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth (err, res, req) ->
        err.should.equal someError
        req.send response

      request app
        .get ENDPOINT_AUTH
        .query code: 'someCode'
        .expect response
        .expect 200, done

    it 'should fail when dropbox response contains an error', (done) ->
      assumeStoredState 'someState'
      response = 'failed again'
      error = 'some very special error string'

      app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth (err, req, res) ->
        err.should.match new RegExp error
        res.send response

      request app
        .get ENDPOINT_AUTH
        .query error: error
        .expect response
        .expect 200, done


    describe 'with successful authentication', ->
      queryCode = null
      beforeEach ->
        queryCode = 'someCode'
        assumeSuccessfullAuth(queryCode)

      it 'should retry checkAuth after successful authentication', (done) ->
        assumeStoredState 'myState'
        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()
        sinon.spy expressDropboxOAuth, 'checkAuth'

        request app
          .get ENDPOINT_AUTH
          .query code: 'someCode'
          .end (err) ->
            expressDropboxOAuth.checkAuth.should.have.been.calledTwice
            done err

      it 'should call through when code param exists in query', (done) ->
        assumeStoredState 'myState'
        response = 'Hello Authenticated User'
        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth(), (req, res) ->
          res.send response

        sinon.stub(expressDropboxOAuth.dropboxClient, 'getUserInfo').callsArgWithAsync 0, null, {}
        authenticatedUser = sinon.stub(expressDropboxOAuth.dropboxClient, 'isAuthenticated')
        authenticatedUser.onFirstCall().returns false
        authenticatedUser.onSecondCall().returns true

        request app
          .get ENDPOINT_AUTH
          .query code: 'someCode'
          .expect response
          .expect 200, done

      it 'should save the received code in storage', (done) ->
        assumeStoredState 'myState'
        sinon.spy fakeStorageSetCalls, 'token'
        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .query code: queryCode
          .end (err) ->
            fakeStorageSetCalls.token.should.have.been.calledWith queryCode
            done err

      it 'should fail when the storage failed to save the token', (done) ->
        queryCode = 'someCode'
        assumeStoredState 'myState'
        sinon.stub(fakeStorageSetCalls, 'token').callsArgWithAsync 1, 'Error'
        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .query code: queryCode, state: 'someState'
          .expect 401, done

      it 'should invoke a given callback on fail', (done) ->
        response = 'someResponse'
        error = new Error 'my message'
        sinon.stub(fakeStorageSetCalls, 'token').callsArgWithAsync 1, error
        app.get ENDPOINT_AUTH, expressDropboxOAuth.doAuth (err, req, res) ->
          err.should.equal error
          res.send response

        request app
          .get ENDPOINT_AUTH
          .expect response
          .expect 200, done

  describe 'logout', ->
    it 'should logout', (done) ->
      response = 'logged out'
      app.get ENDPOINT_LOGOUT, expressDropboxOAuth.logout(), (req, res) ->
        res.send response

      request app
        .get ENDPOINT_LOGOUT
        .expect response
        .expect 200, done

    it 'should remove code and state from storage', (done) ->
      sinon.spy fakeStorage, 'remove'

      app.get ENDPOINT_LOGOUT, expressDropboxOAuth.logout()

      request app
        .get ENDPOINT_LOGOUT
        .end (err) ->
          fakeStorage.remove.should.have.been.calledTwice
          fakeStorage.remove.should.have.been.calledWith constants.STORAGE_KEY_TOKEN
          fakeStorage.remove.should.have.been.calledWith constants.STORAGE_KEY_STATE
          done err

    it 'should reset the dropbox client', (done) ->
      resetSpy = sinon.spy Dropbox.Client.prototype, 'reset'

      app.get ENDPOINT_LOGOUT, expressDropboxOAuth.logout()

      request app
        .get ENDPOINT_LOGOUT
        .end (err) ->
          resetSpy.should.have.been.calledOnce
          done err

    it 'should do a 500 on fail', (done) ->
      sinon.stub(fakeStorage, 'remove').callsArgWithAsync 1, 'myError'

      app.get ENDPOINT_LOGOUT, expressDropboxOAuth.logout()

      request app
        .get ENDPOINT_LOGOUT
        .expect 500, done

    it 'should invoke a given callback on fail', (done) ->
      response = 'rescued somehow...'
      fakeError = 'myError'
      sinon.stub(fakeStorage, 'remove').callsArgWithAsync 1, fakeError

      app.get ENDPOINT_LOGOUT, expressDropboxOAuth.logout (err, req, res) ->
        err.message.should.equal "" + [fakeError, fakeError]
        res.send response

      request app
        .get ENDPOINT_LOGOUT
        .expect response
        .expect 200, done
