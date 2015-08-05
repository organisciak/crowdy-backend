mongoose = require 'mongoose'
config = require 'config'
db_server = 'mongodb://' + config.get('db.host') + '/' + config.get('db.name')
mongoose.connect db_server
db = mongoose.connection
loadHIT = require '../loadHIT'

query =
 assignment_id:'TEST'
 hit_id: '55c11bd005c98d590f1f2784'
 #hit_id: '55c12fc41346450225e92d35'
 lock: true
 taskset_id: 'TEST'
 turk_hit_id: 'NONE'
 user: 'TESTPETER'

db.once('open', (callback) ->
  loadHIT(query, (err, results) ->
    if (err) then console.error err
    console.log results
    db.close()
    return
  )
)
