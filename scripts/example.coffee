#* CONFIG
#********

argv = require('minimist')(process.argv.slice(2))

USER_ID = argv.userId || false
APP_KEY = argv.appKey
APP_SECRET = argv.appSecret
DATABASE_FILE = argv.databaseFile
SERVER_PORT = argv.port || 3000


#* BOOTSTRAP
#***********

ExpressDropboxOAuth = require './../src/index'
idkeyvalue = require 'idkeyvalue'
express = require 'express'
Datastore = require 'nedb'

credentials =
  key: APP_KEY
  secret: APP_SECRET


database = new Datastore filename: DATABASE_FILE, autoload: true
databaseAdapter = new idkeyvalue.NedbAdapter database, USER_ID
expressDropboxOAuth = new ExpressDropboxOAuth credentials, databaseAdapter
app = express()

#* ROUTES
#********

unauthRoute = (err, req, res) ->
  res.send """
    Not authenticated (#{err})
    <a href="/auth">click here to authenticate</a>
  """

app.get '/logout', expressDropboxOAuth.logout(), (req, res) ->
  res.redirect '/'

app.get '/auth', expressDropboxOAuth.doAuth(unauthRoute), (req, res) ->
  res.redirect '/'

authRoute = (req, res) ->
  expressDropboxOAuth.dropboxClient.getUserInfo (err, user) ->
    res.send """
      Hello #{user.name}, how are you? <a href='/logout'>logout</a>
    """
app.get '*', expressDropboxOAuth.checkAuth(unauthRoute), authRoute


#* SERVER
#********

server = app.listen SERVER_PORT, ->
  console.log 'Listening on port %d', server.address().port
