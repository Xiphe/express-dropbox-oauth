express-dropbox-oauth
=====================

[![Build Status](https://travis-ci.org/Xiphe/express-dropbox-oauth.svg)](https://travis-ci.org/Xiphe/express-dropbox-oauth)
[![Coverage Status](https://coveralls.io/repos/Xiphe/express-dropbox-oauth/badge.png?branch=master)](https://coveralls.io/r/Xiphe/express-dropbox-oauth?branch=master)
[![Dependency Status](https://david-dm.org/Xiphe/express-dropbox-oauth.svg)](https://david-dm.org/Xiphe/express-dropbox-oauth)

Dropbox OAuth Middleware for [express](http://expressjs.com/)

  - [Install](#install)
  - [Dropbox App](#dropbox-app)
  - [Init](#init)
  - [Use](#use)
  - [Database](#database)
  - [Database Adapters](#database-adapters)
  - [Example InMemory Database](#example-inmemory-database)
  - [Example App](#example-app)
  - [License](#license)



Install
-------

```sh
npm install express-dropbox-oauth --save
```



Dropbox App
-----------

Create and Manage your Dropbox App here: [Dropbox App Console](https://www.dropbox.com/developers/apps).



Init
----

```js
// var app = [initiate app...]
// var database = [initiate database...] see Database

var ExpressDropboxOAuth = require('express-dropbox-oauth');
var credentials = {
  key: 'myAppKey',
  secret: 'myAppSecret'
};
var expressDropboxAuth = new ExpressDropboxOAuth(credentials, database);
```



Use
---

See [Example App](#example-app)


### Authenticate

Try to create Auth-Token in Database.

```js
function errorRoute(err, req, res, next) {
  res.send('Authentication failed with error: ' + err);
}
app.get('/authenticate', expressDropboxAuth.doAuth(errorRoute), function(req, res) {
  res.send('Authentication succeeded!');
});
```

### Check Auth

Check if Auth-Token exists and is working.

```js
function errorRoute(err, req, res, next) {
  res.send('Restricted Area!');
}
app.get('/onlyAuthenticated', expressDropboxAuth.checkAuth(errorRoute), function(req, res) {
  res.send('Hey Mate!');
});
```

### Log Out

Remove Auth-Token from Database and reset client.

```js
function errorRoute(err, req, res, next) {
  res.send('Logout failed, please retry.');
}
app.get('/logout', expressDropboxAuth.logout(errorRoute), function(req, res) {
  res.send('Bye...');
});
```

### Dropbox Client

Use [dropbox-js](https://github.com/dropbox/dropbox-js) for something fancy.

```js
app.get('/profile', expressDropboxAuth.checkAuth(), function(req, res) {
  expressDropboxAuth.dropboxClient.getUserInfo(function(err, user) {
    res.send('Hello ' + user.name);
  });
});
```



Database
--------

We can use any Database adapter from [idkeyvalue](https://github.com/Xiphe/idkeyvalue).

For example [NeDB](https://github.com/louischatriot/nedb)

```js
// var userId = [initiate userId if needed. Leave empty for single user stuff]
var Datastore = require('nedb');
var NedbAdapter = require('idkeyvalue').NedbAdapter

// See nedb documentation for In-Memory databases etc.
var database = new Datastore(filename: 'myDatabase.nedb', autoload: true);
var databaseAdapter = new NedbAdapter(database, userId);
var expressDropboxAuth = new ExpressDropboxAuth(credentials, databaseAdapter);

// Do crazy stuff now! (see Use)
```



Example App
-----------

Run `coffee scripts/example.coffee --appKey=myAppKey --appSecret=myAppSecret`

This starts up an example server [http://localhost:3000]() with an in-memory database.

Options:

```
  --appKey        Required: The Key of our App
  --appSecret     Required: The Secret of our App
  --databaseFile  Use (and create) the given database file instead of just memory
  --userId        Fake another user (requires --databaseFile)
  --port          Use another port (Default: 3000)
```



License
-------

> The MIT License
> 
> Copyright (c) 2014 Hannes Diercks
> 
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
> 
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.
