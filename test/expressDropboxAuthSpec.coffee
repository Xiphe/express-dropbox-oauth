describe 'ExpressDropboxAuth', ->
  request = require 'supertest'
  appFactory = require './testApp'
  Dropbox = require 'dropbox'
  ExpressDropboxAuth = require './../src/index'
  constants = require './../src/constants'

  ENDPOINT_AUTH = '/auth'
  ENDPOINT_LOGOUT = '/logout'
  EMPTY_DB_ERROR = new Error 'Not Found'

  fakeStorageGetCalls =
    state: (done) -> done EMPTY_DB_ERROR
    token: (done) -> done EMPTY_DB_ERROR

  fakeStorage =
    set: (key, value, done) -> done()
    get: (key, done) ->
      if key == constants.STORAGE_KEY_STATE then fakeStorageGetCalls.state(done) else fakeStorageGetCalls.token(done)
    delete: (key, done) -> done()

  assumeStoredState = (state) ->
    sinon.stub(fakeStorageGetCalls, 'state').callsArgWithAsync 0, null, state

  assumeStoredToken = (token) ->
    sinon.stub(fakeStorageGetCalls, 'token').callsArgWithAsync 0, null, token

  app = null
  xhrStub = null
  expectXhr = false
  expressDropboxAuth = null
  beforeEach ->
    app = appFactory()
    xhrStub = sinon.stub Dropbox.Client.prototype, '_dispatchXhr'
    expectXhr = false
    expressDropboxAuth = new ExpressDropboxAuth key: 'myKey', secret: 'mySecret', fakeStorage

    xhrStub.callsArgWithAsync 1, new Dropbox.ApiError {status: 400}, 'POST', 'http://example.org'

  afterEach ->
    if !expectXhr
      xhrStub.should.not.have.been.called
    else
      xhrStub.should.have.been.called
      xhrStub.callCount.should.equal expectXhr

  it 'should expose Dropbox', ->
    expressDropboxAuth.Dropbox.should.equal Dropbox

  it 'should expose the dropboxClient', ->
    expressDropboxAuth.dropboxClient.should.be.an.instanceof Dropbox.Client

  describe 'checkAuth', ->
    someResponse = 'Hello Authenticated World'

    it 'should send Unauthorized response by default', (done) ->
      app.get ENDPOINT_AUTH, expressDropboxAuth.checkAuth()

      request app
        .get ENDPOINT_AUTH
        .expect 401, done

    it 'should do nothing if user is authenticated', (done) ->
      app.get ENDPOINT_AUTH, expressDropboxAuth.checkAuth(), (req, res) -> res.send someResponse
      sinon.stub(expressDropboxAuth.dropboxClient, 'isAuthenticated').returns true
      sinon.stub(expressDropboxAuth.dropboxClient, 'getUserInfo').callsArgAsync 0

      request app
        .get ENDPOINT_AUTH
        .expect someResponse
        .expect 200, done

    it 'should try to get the auth-token from storage', (done) ->
      sinon.spy fakeStorage, 'get'
      app.get ENDPOINT_AUTH, expressDropboxAuth.checkAuth()

      request app
        .get ENDPOINT_AUTH
        .end (err) ->
          fakeStorage.get.should.have.been.calledWith constants.STORAGE_KEY_TOKEN
          done err

    it 'should set the auth-token to client when found', (done) ->
      expectXhr = 1
      fakeToken = 'someFakeToken'
      assumeStoredToken fakeToken

      setCredentialsSpy = sinon.spy expressDropboxAuth.dropboxClient, 'setCredentials'

      app.get ENDPOINT_AUTH, expressDropboxAuth.checkAuth()

      request app
        .get ENDPOINT_AUTH
        .end (err) ->
          setCredentialsSpy.should.have.been.called
          setCredentialsSpy.getCall(0).args[0].token.should.equal fakeToken
          done err

    it 'should invoke a given callback on fail', (done) ->
      myCallback = sinon.spy (err, req, res) ->
        res.send someResponse
      app.get ENDPOINT_AUTH, expressDropboxAuth.checkAuth myCallback

      request app
        .get ENDPOINT_AUTH
        .expect someResponse
        .expect 200
        .end (err) ->
          myCallback.should.have.been.called
          done err

  describe 'doAuth', ->
    it 'should checkAuth at first', (done) ->
      sinon.spy expressDropboxAuth, 'checkAuth'

      app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

      request app
        .get ENDPOINT_AUTH
        .end (err) ->
          expressDropboxAuth.checkAuth.should.have.been.called
          done err

    describe 'state', ->
      it 'should create a state parameter', (done) ->
        sinon.spy expressDropboxAuth.Dropbox.Util.Oauth, 'randomAuthStateParam'

        app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .end (err) ->
            expressDropboxAuth.Dropbox.Util.Oauth.randomAuthStateParam.should.have.been.called
            done err

      it 'should tell the storage to set the state parameter', (done) ->
        fakeState = 'someState'
        sinon.stub(expressDropboxAuth.Dropbox.Util.Oauth, 'randomAuthStateParam').returns fakeState
        sinon.spy fakeStorage, 'set'

        app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .end (err) ->
            fakeStorage.set.should.have.been.calledWith constants.STORAGE_KEY_STATE, fakeState
            done err

      it 'should not create a state parameter when present in request nor set it', (done) ->
        fakeState = 'someState'
        sinon.spy expressDropboxAuth.Dropbox.Util.Oauth, 'randomAuthStateParam'
        sinon.spy fakeStorage, 'set'

        app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .query state: fakeState
          .end (err) ->
            expressDropboxAuth.Dropbox.Util.Oauth.randomAuthStateParam.should.not.have.been.called
            fakeStorage.set.should.not.have.been.called
            done err

      it 'should fail when the storage fails to set the state', (done) ->
        sinon.stub(fakeStorage, 'set').callsArgWithAsync 2, new Error 'something went wrong'

        app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

        request app
          .get ENDPOINT_AUTH
          .expect 401, done


    it 'should set a new authDriver to dropbox', (done) ->
      sinon.spy expressDropboxAuth.dropboxClient, 'authDriver'

      app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

      request app
        .get ENDPOINT_AUTH
        .end (err) ->
          expressDropboxAuth.dropboxClient.authDriver.should.have.been.called
          done err

    describe 'AuthDriver', ->
      getDriver = (callback) ->
        request app
          .get ENDPOINT_AUTH
          .end (err) ->
            expressDropboxAuth.dropboxClient.authDriver.should.have.been.called
            callback err, expressDropboxAuth.dropboxClient.authDriver.getCall(0).args[0]

      beforeEach ->
        sinon.spy expressDropboxAuth.dropboxClient, 'authDriver'
        app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

      it 'should be of type code', (done) ->
        getDriver (err, driver) ->
          driver.authType().should.equal 'code'
          done err

      it 'should use the current url', (done) ->
        getDriver (err, driver) ->
          driver.url().should.equal ENDPOINT_AUTH
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
      app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

      request app
        .get ENDPOINT_AUTH
        .expect 'location', /www\.dropbox\.com/
        .expect 302, done

    it 'should retry checkAuth', (done) ->
      expectXhr = 1
      assumeStoredState 'myState'
      app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()
      sinon.spy expressDropboxAuth, 'checkAuth'

      request app
        .get ENDPOINT_AUTH
        .query code: 'someCode'
        .end (err) ->
          expressDropboxAuth.checkAuth.should.have.been.calledTwice
          done err

    it 'should call through when code param exists in query', (done) ->
      expectXhr = 1
      assumeStoredState 'myState'
      response = 'Hello Authenticated User'
      app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth(), (req, res) ->
        res.send response

      sinon.stub(expressDropboxAuth.dropboxClient, 'getUserInfo').callsArgWithAsync 0, null, {}
      authenticatedUser = sinon.stub(expressDropboxAuth.dropboxClient, 'isAuthenticated')
      authenticatedUser.onFirstCall().returns false
      authenticatedUser.onSecondCall().returns true

      request app
        .get ENDPOINT_AUTH
        .query code: 'someCode'
        .expect response
        .expect 200, done

    it 'should save the received code in storage', (done) ->
      expectXhr = 1
      assumeStoredState 'myState'
      queryCode = 'someCode'
      sinon.spy fakeStorage, 'set'
      app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

      request app
        .get ENDPOINT_AUTH
        .query code: queryCode
        .end (err) ->
          fakeStorage.set.should.have.been.calledWith constants.STORAGE_KEY_TOKEN, queryCode
          done err

    it 'should fail when the storage failed to save the code', (done) ->
      queryCode = 'someCode'
      assumeStoredState 'myState'
      sinon.stub(fakeStorage, 'set').callsArgWithAsync 2, 'Error'
      app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth()

      request app
        .get ENDPOINT_AUTH
        .query code: queryCode, state: 'someState'
        .expect 401, done

    it 'should invoke a given callback on fail', (done) ->
      response = 'someResponse'
      error = new Error 'my message'
      sinon.stub(fakeStorage, 'set').callsArgWithAsync 2, error
      app.get ENDPOINT_AUTH, expressDropboxAuth.doAuth (err, req, res) ->
        err.should.equal error
        res.send response

      request app
        .get ENDPOINT_AUTH
        .expect response
        .expect 200, done

  describe 'logout', ->
    it 'should logout', (done) ->
      response = 'logged out'
      app.get ENDPOINT_LOGOUT, expressDropboxAuth.logout(), (req, res) ->
        res.send response

      request app
        .get ENDPOINT_LOGOUT
        .expect response
        .expect 200, done

    it 'should remove code and state from storage', (done) ->
      sinon.spy fakeStorage, 'delete'

      app.get ENDPOINT_LOGOUT, expressDropboxAuth.logout()

      request app
        .get ENDPOINT_LOGOUT
        .end (err) ->
          fakeStorage.delete.should.have.been.calledTwice
          fakeStorage.delete.should.have.been.calledWith constants.STORAGE_KEY_TOKEN
          fakeStorage.delete.should.have.been.calledWith constants.STORAGE_KEY_STATE
          done err

    it 'should reset the dropbox client', (done) ->
      resetSpy = sinon.spy Dropbox.Client.prototype, 'reset'

      app.get ENDPOINT_LOGOUT, expressDropboxAuth.logout()

      request app
        .get ENDPOINT_LOGOUT
        .end (err) ->
          resetSpy.should.have.been.calledOnce
          done err

    it 'should do a 500 on fail', (done) ->
      sinon.stub(fakeStorage, 'delete').callsArgWithAsync 1, 'myError'

      app.get ENDPOINT_LOGOUT, expressDropboxAuth.logout()

      request app
        .get ENDPOINT_LOGOUT
        .expect 500, done

    it 'should invoke a given callback on fail', (done) ->
      response = 'rescued somehow...'
      fakeError = 'myError'
      sinon.stub(fakeStorage, 'delete').callsArgWithAsync 1, fakeError

      app.get ENDPOINT_LOGOUT, expressDropboxAuth.logout (err, req, res) ->
        err.message.should.equal "" + [fakeError, fakeError]
        res.send response

      request app
        .get ENDPOINT_LOGOUT
        .expect response
        .expect 200, done
