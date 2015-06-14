# Return the proper information to angular
#
mongoose = require 'mongoose'
async = require 'async'
mongoose.connect 'mongodb://localhost/test'
db = mongoose.connection

taskSet = require './models/taskset'

user = "TEST"
hit = "Test HIT"
hit_id = "557a540429ffdf6c18cb91d5" # The mongo ID for the hit item


db.on('error', console.error.bind(console, 'connection error:'))
db.once('open', () ->
  # 1. Count how many taskSets this user has done in this condition
  async.parallel({
    allUserDone: ((callback) ->
      taskSet.count({user:user}, (err,results) ->
        if (err) then return callback(err)
        console.log 'allUserDone'
        callback(null, results)
      )
    ),
    allUserHIT:((callback) ->
      taskSet.count({user:user, hit_id:hit_id}, (err,results) ->
        if (err) then return callback(err)
        console.log 'allUserHIT'
        callback(null, results)
      )
    )
  },
  (err,results) ->
    console.log "Final results"
    console.log results
  )
  taskSet.count({user:user, hit_id:hit_id}, (err,results) ->
    if (err) then return console.error err
    console.log("User/Hit_id task count")
    console.log results
  )
)

