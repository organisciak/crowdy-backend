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
hit_id = "557df4899b962f181de3da0c" # The mongo ID for the hit item

db.on('error', console.error.bind(console, 'connection error:'))
db.once('open', () ->
  async.waterfall([
    getBasicInfo,
    getCondition,
    getMaxedItems,
    sampleTaskItems
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
    countUserAll: (callback) -> TaskSet.count({user:user}).exec(callback)
    # Count of tasksets in the given condition done
    countUserHIT: (callback) -> TaskSet.count({user:user, hit_id:hit_id}).exec(callback)
    # List of user's past items completed (not specific to the current hit)
    userItemList: (callback) ->
      TaskSet.aggregate([{$match: {user:user}},
        {$project:{"tasks.item.id":1}},
        {$unwind : "$tasks"},
        {$group: {_id:"$tasks.item.id"}}]
      ).exec(callback)
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
  if obj.countUserHIT is 1
    obj.condition = obj.hit.condition.firstTask
  else
    obj.condition = obj.hit.condition.laterTasks

  switch obj.condition
    when 'feedback'
      '''TODO get user feedback and add to obj'''
      callback('Feedback condition not yet designed', obj)
    else
      callback(null, obj)

  return

# 3. Sample items for worker to complete
# 3.1 Determine with items have already been done enough
getMaxedItems = (obj, callback) ->
  if obj.condition is 'teaching'
    callback(obj, null)
  # Get a list of all currentHIT items completed
  TaskSet.aggregate({$match: {hit_id:hit_id}},
                  {$project:{"tasks.item.id":1}},
                  {$unwind : "$tasks"},
                  # Matching on task item id *after* unwinding
                  {$match: {'tasks.item.id':{$in: obj.hit.items }}},
                  {$group: {_id:"$tasks.item.id", count:{$sum:1}}},
                  # We want to know which tasks have already be done max times
                  {$match:{count:{$gte:obj.hit.setsPerItem}}}
  ).exec((err, results) ->
      obj.maxed = (result._id for result in results)
      callback(obj, null)
  )

sampleTaskItems = (obj, callback) ->
  switch obj.condition
    when 'teaching'
      ''' TODO get teaching set '''
      callback(obj, "Teaching set not ready yet")
    when 'fast'
      ''' TODO Prep larger set for fast completion '''
      callback(obj, "Fast set not ready yet")
    when 'basic'
      ''' doStuff '''
      console.log obj.hit.items
      callback(obj, null)
      # Lock in-progress files

      # If there are no tasks left,
      # doStuff()
      # Find items which are *not* is set of items completed by user and
      # in set where HIT(CompletedItems).item.Count is less than hit.setsPerItem
