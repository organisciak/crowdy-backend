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
    getBasicInfo,
    getCondition
  ], (err, results) ->
    if (err) then return console.error err
    console.log "Waterfall done"
    console.log results
  )
)

# 1. Count how many taskSets this user has done in this condition
# Also fetch HIT info, since it can be done asynchronously
getBasicInfo = (callback) ->
  async.parallel({
    # Count of all taskSets done by the user
    countUserAll: (callback) -> TaskSet.count({user:user}, callback),
    # Count of tasksets in the given condition done
    countUserHIT: (callback) -> TaskSet.count({user:user, hit_id:hit_id}, callback)
    # Load HIT info
    hit: (callback) ->
      Hit.find({_id: ObjectId(hit_id)}, (err, result) ->
        if result.length is 0 then return callback("No matching hit", result)
        callback(err, result[0])
      )
  },
  # Pass (err, results) directly to the callback, which
  # will send it down the waterfall
  callback
  )

# 2. Determine the current condition
getCondition = (obj, callback) ->
  if obj.countUserHIT == 1
    obj.condition = obj.hit.condition.firstTask
  else
    obj.condition = obj.hit.condition.laterTasks
  callback(null, obj)
  return
