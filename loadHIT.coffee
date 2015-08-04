# Return the proper information for Angular
# This module only runs the Mongo gathering
# logic
# Usage: loadHIT({user:..,hit_id:..,lock:..}, callback)
#
mongoose = require 'mongoose'
async = require 'async'
_ = require 'lodash'

TaskSet = require './models/taskset'
Hit = require './models/hit'
ObjectId = mongoose.Types.ObjectId

loadHIT = (opts, callback) ->
  async.waterfall([
    (cb) -> cb(null, opts) # Pipe opts to first func in waterfall
    getBasicInfo,
    getCondition,
    sampleFacet,
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
    countUserHIT: (callback) ->
      TaskSet.countUserHIT(opts.user, opts.hit_id, callback)
    # List of user's past items completed (not specific to the current hit)
    userItemList: (callback) -> TaskSet.userItemList(opts.user, callback)
    # Load HIT info
    hit: (callback) -> Hit.findOne({_id: ObjectId(opts.hit_id)},
      (err, results) ->
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

  obj.payment =
    base: obj.hit.payment
    bonus: obj.hit.bonus

  switch obj.condition
    when 'feedback'
      # Feedback condition needs to retrieval extra information, might as well
      # do it now.
      # TODO Ideally we'd do it asynchronously with the next step in the
      # waterfall, since get MaxedItems doesn't depend on this step
      obj.feedback = true
      callback('Feedback condition not yet designed', obj)
      # Psuedo-code
      #
    when 'fast'
      obj.timer = obj.hit.timer
    when 'basic'
      obj.itemTimeEstimate = obj.hit.itemTimeEstimate
    else
      callback('Condition "' + obj.condition + '" not available."', obj)
      
  callback(null, obj)
  return

## 2.2 Sample a facet, if relevant
## Facets let us define subgroups of the data, like 'queries' for an IR hit
sampleFacet = (obj, callback) ->
  if obj.hit.facets and obj.hit.facets.length > 0
    obj.facet = _.sample(obj.hit.facets, 1)[0]
    obj.hit.items = obj.facet.items
    obj.userItemList = _.filter(obj.userItemList, (item) ->
      if not item._id.facet
        return false
      return item._id.facet.equals(obj.facet._id)
    )
  else
    # Easier to work with later if null rather than undefined
    obj.facet = null
  callback(null, obj)

# 3. Sample items for worker to complete
# 3.1 Determine which items have already been done enough
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

  facet_id = if obj.facet then obj.facet._id else null
  # Get a list of all currentHIT items completed
  TaskSet.aggregate([
    {$match:{
      hit_id:obj.opts.hit_id,
      facet_id:(if obj.facet then obj.facet._id else null)
    }},
    {$project:{"tasks.item.id":1}},
    {$unwind : "$tasks"},
    # Matching on task item id *after* unwinding
    {$match: {'tasks.item.id':{$in: obj.hit.items }}},
    {$group: { _id:"$tasks.item.id", count:{$sum:1} }},
    # We want to know which tasks have already be done max times
    {$match:{count:{$gte:obj.hit.setsPerItem}}}
  ]).exec((err, results) ->
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
  
  if obj.condition is 'basic' or 'fast'
    if obj.opts.user == 'PREVIEWUSER'
      candidates = obj.hit.items
    else
      # Create list of excludes
      excludes = obj.maxed.concat (item._id.item for item in obj.userItemList)
      candidates = _.difference(obj.hit.items, excludes)

    # Fast condition shouldn't specify a max size
    if obj.condition is 'fast' and obj.hit.maxSetSize
      # Ignore any max set size that may be specified, and return a large number
      # of items instead
      obj.hit.maxSetSize = 25

    itemSampleIds = _.sample(candidates,
      if obj.hit.maxSetSize then obj.hit.maxSetSize else 25)

    obj.locksCleared = null
    # Query info for all the sampled items
    if obj.hit.itemModel is 'pin'
      projection = { url:1, description:1, title:1, image:1, likes:1, repins:1 }
    else
      projection = {}
    ItemModel.find({_id:{$in:itemSampleIds}},
      projection,
      (err, results) ->
        if err then return callback(err)
        obj.sample = results
        if obj.sample.length is 0
          msg = "No tasks available. This may be because you've finished all "+
          "the tasks that we have ready, or other people are working on "+
          "everything on that's available (try again later), or we screwed "+
          "something up (sorry)."
          callback(msg, null)
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
    assignment_id: obj.opts.assignment_id
    user: obj.opts.user
    hit_id: obj.opts.hit_id
    facet: ( _.pick(obj.facet, ['meta', '_id']) || null)
    turk_hit_id: obj.opts.turk_hit_id
    time:
      start:(new Date())
      submit: null
      workTime: null
    feedback:
      form: null
      satisfaction: null
    tasks:tasks
      
  # Lock in-progress files if locking was requested
  if (obj.opts.lock is true) and (obj.opts.user isnt "PREVIEWUSER")
    taskset = new TaskSet(obj.taskset)
    taskset.save((err, res) ->
      callback(err, obj)
    )
  else
    callback(null, obj)

cleanForFrontEnd = (obj, callback) ->
  # Add item information to taskSet.tasks[] as .meta field
  # This information shouldn't be saved to Mongo, since we already have it
  sampleRef = _.object(_.map(obj.sample, ((obj) -> obj._id)), obj.sample)
  tasks = obj.taskset.tasks
  tasks = tasks.map((task)->
    task.meta = sampleRef[task.item.id]
    task
  )
  # Redundant
  delete obj.sample
  delete obj.opts
  delete obj.maxed
  # Not needed by front end
  delete obj.userItemList
  delete obj.locksCleared
  delete obj.hit
  delete obj.facet

  callback(null, obj)

module.exports = loadHIT
