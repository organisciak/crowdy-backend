# Return the proper information for Angular
# This module only runs the Mongo gathering
# logic
# Usage: loadHIT({user:..,hit_id:..,lock:..}, callback)
#
mongoose = require 'mongoose'
async = require 'async'
_ = require 'underscore'

TaskSet = require './models/taskset'
Hit = require './models/hit'
ObjectId = mongoose.Types.ObjectId

loadHIT = (opts, callback) ->
    async.waterfall([
      (cb) -> cb(null, opts) # Pipe opts to first func in waterfal
      getBasicInfo,
      getCondition,
      getMaxedItems,
      sampleTaskItems,
      prepareTaskSet,
      cleanForFrontEnd
    ],
    callback #Send back to the calling script
    )

# 1. Count how many taskSets this user has done in this condition
# Also fetch HIT info, since it can be done asynchronously
getBasicInfo = (opts, callback) ->
  async.parallel({
    opts: (callback) -> callback(null, opts)
    # Count of all taskSets done by the user
    countUserAll: (callback) -> TaskSet.countUserAll(opts.user, callback)
    # Count of tasksets in the given condition done
    countUserHIT: (callback) -> TaskSet.countUserHIT(opts.user, opts.hit_id, callback)
    # List of user's past items completed (not specific to the current hit)
    userItemList: (callback) -> TaskSet.userItemList(opts.user, callback)
    # Load HIT info
    hit: (callback) -> Hit.findOne({_id: ObjectId(opts.hit_id)}, callback)
    # Clear locks
    locksCleared: (callback) -> TaskSet.clearLocks(opts.user, callback)
  }, callback
  )

# 2. Determine the current condition
getCondition = (obj, callback) ->
  if obj.countUserHIT is 1
    obj.condition = obj.hit.condition.firstTask
  else
    obj.condition = obj.hit.condition.laterTasks

  switch obj.condition
    when 'feedback'
      callback('Feedback condition not yet designed', obj)
    else
      callback(null, obj)

  return

# 3. Sample items for worker to complete
# 3.1 Determine with items have already been done enough
getMaxedItems = (obj, callback) ->
  if obj.condition is 'teaching'
    callback(null, obj)
  # Get a list of all currentHIT items completed
  TaskSet#.find({hit_id:hit_id}
    .aggregate({$match:{hit_id:obj.opts.hit_id}},
                  {$project:{"tasks.item.id":1}},
                  {$unwind : "$tasks"},
                  # Matching on task item id *after* unwinding
                  {$match: {'tasks.item.id':{$in: obj.hit.items }}},
                  {$group: {_id:"$tasks.item.id", count:{$sum:1}}},
                  # We want to know which tasks have already be done max times
                  {$match:{count:{$gte:obj.hit.setsPerItem}}}
  ).exec((err, results) ->
      if (err) then return callback(err, obj)
      obj.maxed = (result._id for result in results)
      callback(null, obj)
  )
  return

sampleTaskItems = (obj, callback) ->
  switch obj.condition
    when 'teaching'
      ''' TODO get teaching set '''
      callback("Teaching set not ready yet", bj)
    when 'fast'
      ''' TODO Prep larger set for fast completion '''
      callback("Fast set not ready yet", obj)
    when 'basic'
      ''' doStuff '''
      excludes = obj.maxed.concat (item._id for item in obj.userItemList)
      candidates = _.difference(obj.hit.items, excludes)
      itemSampleIds = _.sample(candidates, if obj.hit.maxSetSize then obj.hit.maxSetSize else 200)
      # Load Item model
      ItemModel = require('./models/' + obj.hit.itemModel)
      # Query info for all the sampled items
      if obj.hit.itemModel is 'pin'
        projection = { url:1, description:1, title:1, image:1, likes:1, repins:1 }
      else
        projection = {}
      ItemModel.find({_id:$in:itemSampleIds},
        projection,
        (err, results) ->
          obj.sample = results
          callback(err, obj)
        )

prepareTaskSet = (obj, callback) ->

  tasks = _.map(obj.sample, (task) ->
    type: obj.hit.type
    item:
      type: obj.hit.itemModel
      id: task.id
    timeSpent: null
    contribution: null
  )

  obj.taskset =
    _id: obj.opts.taskset_id
    lock: if obj.opts.lock then true else false
    user: obj.opts.user
    hit_id: obj.opts.hit_id
    time:
      start:(new Date())
      submit: null
      workTime: null
    feedback:
      form: null
      satisfaction: null
    tasks:tasks
      
  # Lock in-progress files if locking was requested
  if obj.opts.lock
    taskset = new TaskSet(obj.taskset)
    taskset.save((err, res) ->
      callback(err, obj)
    )
  else
    callback(null, obj)

cleanForFrontEnd = (obj, callback) ->
   # Redundant
  delete obj.opts
  delete obj.maxed
  # Not needed by front end
  delete obj.userItemList
  delete obj.locksCleared
  delete obj.hit
  # Easier access on front-end
  # Add item information to taskSet.tasks[] as .meta field
  # This information shouldn't be saved to Mongo, since we already have it
  sampleRef = _.object(_.map(obj.sample, ((obj) -> obj._id)), obj.sample)
  tasks = obj.taskset.tasks
  tasks = tasks.map((task)->
    task.meta = sampleRef[task.item.id]
    task
  )
  delete obj.sample
  callback(null, obj)



# If there are no tasks left,
# doStuff()
# Find items which are *not* is set of items completed by user and
# in set where HIT(CompletedItems).item.Count is less than hit.setsPerItem

module.exports = loadHIT
