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
      (cb) -> cb(null, opts) # Pipe opts to first func in waterfall
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
    hit: (callback) -> Hit.findOne({_id: ObjectId(opts.hit_id)}, (err, results) ->
      if results is null
        callback("HIT not found", null)
      else
        callback(err, results)
    ),
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

  # Feedback condition needs to retrieval extra information, might as well do it now.
  # TODO Ideally we'd do it asynchronously with the next step in the waterfall, since
  # get MaxedItems doesn't depend on this step
  switch obj.condition
    when 'feedback'
      callback('Feedback condition not yet designed', obj)
      # Psuedo-code
      #
    else
      callback(null, obj)

  return

# 3. Sample items for worker to complete
# 3.1 Determine with items have already been done enough
getMaxedItems = (obj, callback) ->
  if obj.condition is 'teaching'
    ''' Don't need maxed conditions because teaching set is pre-determined '''
    callback(null, obj)
    return

  if obj.opts.user == 'PREVIEWUSER'
    console.log "Preview user, no maxed items"
    obj.maxed = []
    callback(null,obj)
    return

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
  # Load Item model
  ItemModel = require('./models/' + obj.hit.itemModel)

  if obj.condition is 'teaching'
    ''' TODO get teaching set '''
    callback("Teaching set not ready yet", bj)
  
  if obj.condition is 'fast'
    ''' TODO Prep larger set for fast completion '''
    callback("Fast set not ready yet", obj)

  if obj.condition is 'basic' or 'fast'
    if obj.opts.user == 'PREVIEWUSER'
      candidates = obj.hit.items
    else
      excludes = obj.maxed.concat (item._id for item in obj.userItemList)
      candidates = _.difference(obj.hit.items, excludes)

    # Fast condition shouldn't specific a max size
    if obj.condition is 'fast' and obj.hit.maxSetSize
      delete obj.hit.maxSetSize

    itemSampleIds = _.sample(candidates, if obj.hit.maxSetSize then obj.hit.maxSetSize else 200)

    # Query info for all the sampled items
    if obj.hit.itemModel is 'pin'
      projection = { url:1, description:1, title:1, image:1, likes:1, repins:1 }
    else
      projection = {}
    ItemModel.find({_id:$in:itemSampleIds},
      projection,
      (err, results) ->
        obj.sample = results
        if obj.sample.length is 0
          callback("No tasks available.", null)
        else
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

  # If taskset Id is "TEST", generate a unique one.
  if obj.opts.taskset_id is "TEST"
    obj.opts.taskset_id =  "TEST" + Math.floor(Math.random()*Math.pow(10,10))
    console.log "Generating unique taskset_id: " + obj.opts.taskset_id

  obj.taskset =
    _id: obj.opts.taskset_id
    lock: obj.opts.lock
    assignment_id: obj.opts.assignment_id,
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
  if obj.opts.lock is true and obj.opts.user isnt "PREVIEWUSER"
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
