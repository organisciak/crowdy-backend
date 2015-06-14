# Return the proper information to angular
#
mongoose = require 'mongoose'
async = require 'async'
mongoose.connect 'mongodb://localhost/test'
db = mongoose.connection

TaskSet = require './models/taskset'
Hit = require './models/hit'
ObjectId = mongoose.Types.ObjectId

user = "TEST"
hit = "Test HIT"
hit_id = "557a540429ffdf6c18cb91d5" # The mongo ID for the hit item

db.on('error', console.error.bind(console, 'connection error:'))
db.once('open', () ->
  async.waterfall([
    getUserInfo,
    getHitInfo
  ], (err, results) ->
    if (err) then return console.error err
    console.log "Waterfall done"
    console.log results
  )
)

# 1. Count how many taskSets this user has done in this condition
getUserInfo = (callback) ->
  async.parallel({
    # Count of all taskSets done by the user
    countUserAll: (callback) -> TaskSet.count({user:user}, callback),
    # Count of tasksets in the given condition done
    countUserHIT: (callback) -> TaskSet.count({user:user, hit_id:hit_id}, callback)
  },
  # Pass (err, results) directly to the callback, which
  # will send it down the waterfall
  callback
  )

# 2. Get HIT info and determine the current condition
getHitInfo = (obj, callback) ->
  Hit.find({_id: ObjectId(hit_id)}, (err, result) ->
    if err or result.length is 0 then return callback(err, null)
    obj.hit = result
    console.log result
    callback(err, result)
    return
  )
