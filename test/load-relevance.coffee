mongoose = require 'mongoose'
config = require 'config'
db_server = 'mongodb://' + config.get('db.host') + '/' + config.get('db.name')
mongoose.connect db_server
db = mongoose.connection
loadHIT = require '../loadHIT'

query =
 assignment_id:'TEST'
 hit_id: '55bf1b2acf34cc913bd742a0'
 lock: true
 taskset_id: 'TEST'
 turk_hit_id: 'NONE'
 user: 'PREVIEWUSER'

db.once('open', (callback) ->
  loadHIT(query, (err, results) ->
    if (err) then console.error err
    console.log results
    db.close()
    return
  )
)
