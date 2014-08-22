describe 'NedbAdapter', ->
  Datastore = require 'nedb'
  NedbAdapter = require './../../src/storage/NedbAdapter'
  nedbAdapter = null
  db = null
  userId = null

  for hasUser in [false, true]
    describe (if hasUser then 'with user' else 'without user'), ->

      beforeEach ->
        userId = 1 if hasUser
        db = new Datastore
        if hasUser
          nedbAdapter = new NedbAdapter db, userId
        else
          nedbAdapter = new NedbAdapter db

      it 'should exist', ->
        nedbAdapter.should.exist

      describe 'set', ->
        it 'should save a value to the database', (done) ->
          key = 'foo'
          value = 'bar'
          nedbAdapter.set key, value, ->
            find = {}
            find[key] = value
            db.find find, (err, docs) ->
              if err then err.should.equal null
              docs.length.should.equal 1
              docs[0][key].should.equal value
              docs[0]['userId'].should.equal userId if hasUser
              done()

        it 'should update an existent value', (done) ->
          key = 'foo'
          value = 'bar'
          value2 = 'baz'
          nedbAdapter.set key, value, ->
            find = {}
            find[key] = value
            db.find find, (err, docs) ->
              if err then err.should.equal null
              docs[0][key].should.equal value
              docs[0]['userId'].should.equal userId if hasUser

              nedbAdapter.set key, value2, ->
                find = {}
                find[key] = value2
                db.find find, (err, docs) ->
                  if err then err.should.equal null
                  docs.length.should.equal 1
                  docs[0][key].should.equal value2
                  docs[0]['userId'].should.equal userId if hasUser
                  done()

        it 'should pass potential database errors to callback', (done) ->
          error = new Error 'myDbError'
          sinon.stub(db, 'update').callsArgWithAsync 3, error

          nedbAdapter.set 'foo', 'nar', (err) ->
            err.should.equal error
            done()

      describe 'get', ->
        savedKey = 'foo'
        savedValue = 'bar'

        it 'should get values', (done) ->
          nedbAdapter.set savedKey, savedValue, ->
            nedbAdapter.get savedKey, (err, value) ->
              if err then err.should.equal null
              value.should.equal.savedValue
              done()

        it 'should pass an error if key does not exist', (done) ->
          nedbAdapter.get savedKey, (err, value) ->
            err.should.be.instanceof Error
            err.message.should.match /foo/
            done()

        it 'should pass potential database errors to callback', (done) ->
          error = new Error 'myDbError'
          sinon.stub(db, 'find').callsArgWithAsync 1, error
          nedbAdapter.get savedKey, (err, value) ->
            err.should.equal error
            done()

        if hasUser
          it 'should not get values for another user', (done) ->
            nedbAdapter.set savedKey, savedValue, ->
              nedbAdapter.userId = 2
              nedbAdapter.get savedKey, (err, value) ->
                err.should.be.instanceof Error
                err.message.should.match /foo/
                err.message.should.match /user '2'/
                done()

      describe 'delete', ->
        it 'should delete values', (done) ->
          key = 'foo'
          nedbAdapter.set key, 'bar', ->
            nedbAdapter.delete key, ->
              find = {}
              find[key] = /.*/
              db.find find, (err, docs) ->
                if err then err.should.equal null
                docs.length.should.equal 0
                done()

        it 'should pass potential database errors to callback', (done) ->
          error = new Error 'myDbError'
          sinon.stub(db, 'remove').callsArgWithAsync 1, error
          nedbAdapter.delete 'foobar', (err) ->
            err.should.equal error
            done()

        if hasUser
          it 'should not delete values of another user', (done) ->
            key = 'foo'
            value = 'bar'
            nedbAdapter.set key, value, ->
              nedbAdapter.userId = 2
              nedbAdapter.delete key, ->
                find = {}
                find[key] = /.*/
                db.find find, (err, docs) ->
                  if err then err.should.equal null
                  docs.length.should.equal 1
                  docs[0].userId.should.equal 1
                  docs[0][key].should.equal value
                  done()
