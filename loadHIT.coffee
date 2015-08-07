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
    prepareTaskset,
    cleanForFrontEnd
  ],
  callback #Send back to the calling script
  )

#1. Get as much info asynchronously as we can
prepareTaskset = (opts, callback) ->
  async.auto({
    opts: (callback) -> callback(null, opts)
    
    # Count of all taskSets done by the user
    countUserAll: (callback) -> TaskSet.countUserAll(opts.user, callback)

    # Count of tasksets in the given hit done
    countUserHIT: (callback) ->
      TaskSet.countUserHIT(opts.user, opts.hit_id, callback)
    
    # List of user's past items completed (not specific to the current hit)
    userItemList: (callback) -> TaskSet.userItemList(opts.user, callback)

    userFacetItemList: ['userItemList', 'facet', (callback, obj) ->
      if not obj.facet
        return callback(null, obj.userItemList.userItemList)

      list = _.filter(obj.userItemList, (item) ->
        if not item._id.facet
          return false
        return item._id.facet.equals(obj.facet._id)
      )
      callback(null, list)
    ]

    
    # Counts of all the facet that have been completed for the task, if any
    countFacetsCompleted: (callback) ->
      TaskSet.countFacetsCompleted(opts.hit_id, callback)

    # Count how much of each facet the user has completed
    userFacetCounts: ['userItemList',  ((callback, obj) ->
      counts = _.countBy(obj.userItemList, (item) ->
        if item._id.facet
          return item._id.facet.toString()
        else
          return null
        )
      callback(null, counts)
    )]
    
    # Load HIT info
    hit: (callback) ->
      Hit
        .findOne({_id: ObjectId(opts.hit_id)})
        .exec((err, results) ->
          if results is null then return callback("HIT not found", null)
          callback(err, results)
        )
    
    # Clear locks
    locksCleared: (callback) ->
      TaskSet
        .clearLocks(opts.user)
        .exec((err, results)->callback(err, !!results))
    
    # Get all hits with the same hit type as obj.hit
    allHitType: ['hit', ((callback, obj) ->
      Hit.listAllByType(obj.hit.type, callback)
    )]

    payment: ['hit', (callback, obj) ->
      callback(null, {base: obj.hit.payment, bonus:obj.hit.bonus})
    ]

    ## Exclude workers if relevant (returns either false or an err)
    excludeWorker: ['hit', 'opts', 'allHitType', ((callback, obj) ->
      if not obj.hit.exclude.pastInTaskType
        return callback(null, false)
      if obj.hit.exclude.pastInTaskType
        # Find hits with the same type (excluding this one)
        hit_ids = _.filter(obj.allHitType, (id) -> id isnt obj.hit._id)
        TaskSet.findOne(
          {hit_id:{$in:hit_ids}, user:obj.opts.user}
        ).exec((err, results) ->
          if (err) then console.error err
          if results
            return callback("It looks like you've done a very similar " +
              "task to this one, so it wouldn't be fun to do it again. " +
              "Sorry to let you know after accepting, but we don't have " +
              "information about you during the preview.", true)
          else
            return callback(null, false)
        )
    )],

    condition: ['hit', 'countUserHIT', (callback, obj) ->
      if obj.countUserHIT is 0
        return callback(null, obj.hit.condition.firstTask)
      else
        return callback(null, obj.hit.condition.laterTasks)
    ]

    # Set 'design' (basic, teaching, and fast are designs, but the 'feedback'
    # condition needs an underlying design of its own.
    design: ['condition', (callback, obj) ->
      if obj.condition is 'feedback'
        # This assumes that feedback is always a laterTasks condition
        design = obj.hit.condition.firstTask
      else
        design = obj.condition
      callback(null, design)
    ]

    # Get Feedback, if required
    performanceFeedback: ['design', 'allHitType', (callback, obj) ->
      if obj.condition is 'feedback'
        getFeedback = require './getFeedback'
        return getFeedback(obj, callback)
      else
        return callback(null, null)
    ]

    ## Sample a facet, if relevant
    ## Facets let us define subgroups of the data, like 'queries' for an IR hit
    facet: ['hit', 'countFacetsCompleted', 'userFacetCounts',
    (callback, obj) ->
      if not (obj.hit.facets and obj.hit.facets.length > 0)
        callback(null, null)
      
      # Rather than randomly sampling a facet, let's sample the one with the
      # least completed or locked items
      facets = _.map(obj.hit.facets, (item) -> item._id.toString())
      flist = _.map(obj.countFacetsCompleted, (item)-> item._id.toString())
      
      # Prepend any facets that haven't been started
      flist = _.difference(facets, flist).concat(flist)
       
      facetItemCounts = _.map(obj.hit.facets, (facet) ->
        {_id:facet._id.toString(), count:facet.items.length}
      )
      invalidFacets = []
      for item in facetItemCounts
        c = obj.userFacetCounts
        if c[item._id] and (c[item._id] >= item.count)
          invalidFacets.push item._id
      flist = _.difference(flist, invalidFacets)
      
      # If there are no valid facets, we know that there's nothing for the user
      if flist.length is 0
        msg = "No tasks available. This may be because you've finished all "+
        "the tasks that we have ready, or other people are working on "+
        "everything on that's available (try again later), or we screwed "+
        "something up (sorry)."
        return callback(msg, null)

      # Sample Facet
      f_id_str = flist[0]
      sampled_facet = _.find(obj.hit.facets, (facet) ->
        (facet._id.toString() == f_id_str)
      )
      callback(null, sampled_facet)
    ]

  samplePool: ['hit', 'facet', (callback, obj) ->
    items = if obj.facet then obj.facet.items else obj.hit.items
    callback(null, items)
  ]

    # Determine which items have already been done enough
  maxed: ['opts', 'hit', 'design', 'facet', (callback, obj) ->
    if obj.design is 'teaching'
      ''' Don't need maxed info because teaching set is pre-determined '''
      return callback(null, null)

    if obj.opts.user == 'PREVIEWUSER'
      console.log "Preview user, no maxed items"
      return callback(null, [])

    # Get a list of all currentHIT items completed
    agg = [
      {$match:
        hit_id:obj.opts.hit_id
        'facet._id': (if obj.facet then ObjectId(obj.facet._id) else null)
      },
      {$project: "tasks.item.id":1 },
      {$unwind : "$tasks"},
      # Matching on task item id *after* unwinding
      {$match: 'tasks.item.id': $in: obj.samplePool },
      {$group:
        _id: "$tasks.item.id",
        count: $sum:1
      },
      # We want to know which tasks have already be done max times
      {$match:
        count:
          $gte:obj.hit.setsPerItem
      }
    ]
    TaskSet.aggregate(agg).exec((err, results) ->
      if (err) then return callback(err, null)
      maxed = (result._id for result in results)
      callback(null, maxed)
    )
    return
  ]

  # An input hit might have errors, so we're doublechecking maxSetSize,
  # setting our own by the rules
  maxSetSize: ['hit', 'design', (callback, obj) ->
    # Fast design shouldn't specify a max size
    if obj.design is 'fast' and obj.hit.maxSetSize
      # Ignore any max set size that may be specified, and return a large
      # number of items instead
      console.info "Ignoring Fast design's maxSetSize"
      return callback(null, 30)
    else if obj.hit.maxSetSize
      return callback(null, obj.hit.maxSetSize)
    else
      console.warn("No max set size set, forcing to 15")
      return callback(null, 15)
  ]
  # Sample task items
  sample : ['hit', 'maxed', 'design', 'samplePool', 'userFacetItemList',
  (callback, obj) ->
    # Load Item model
    ItemModel = require('./models/' + obj.hit.itemModel)

    if obj.design is 'teaching'
      callback("Teaching set not ready yet", null)
    
    if obj.design is 'basic' or 'fast'
      if obj.opts.user == 'PREVIEWUSER'
        candidates = obj.samplePool
      else
        # Create list of excludes
        excludes = obj.maxed.concat(
          item._id.item for item in obj.userFacetItemList
        )
        candidates = _.difference(obj.samplePool, excludes)

      itemSampleIds = _.sample(candidates, obj.maxSetSize)

      # Query info for all the sampled items
      if obj.hit.itemModel is 'pin'
        projection = { url:1, description:1, title:1,
        image:1, likes:1, repins:1 }
      else
        projection = {}
      ItemModel.find({_id:{$in:itemSampleIds}},
        projection,
        (err, results) ->
          if err then return callback(err)
          sample = results
          if sample.length is 0
            msg = "No tasks available. This may be because you've finished "+
            "all the tasks that we have ready, or other people are working "+
            "on everything on that's available (try again later), or we "+
            "screwed something up (sorry)."
            callback(msg, null)
          else
            callback(err, sample)
        )
  ]

  timer: ['design', 'hit', (callback, obj) ->
    if obj.design is 'fast'
      return callback(null, obj.hit.timer)
    else
      return callback()
  ]

  itemTimeEstimate: ['design', (callback, obj) ->
    if obj.design is 'basic'
      return callback(null, obj.hit.itemTimeEstimate)
    else
      return callback()
  ]


  taskset: ['opts', 'sample', 'hit', 'facet',
  (callback, obj) ->
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

    taskset =
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
      tasksetInstance = new TaskSet(taskset)
      tasksetInstance.save((err, res) ->
        callback(err, taskset)
      )
    else
      callback(null, taskset)
  ]

  },
  callback
  )

cleanForFrontEnd = (obj, callback) ->
  # Add item information to taskSet.tasks[] as .meta field

  # This information shouldn't be saved to Mongo, since we already have it
  sampleRef = _.object(_.map(obj.sample, ((obj) -> obj._id)), obj.sample)
  tasks = obj.taskset.tasks
  tasks = tasks.map((task)->
    task.meta = sampleRef[task.item.id]
    task
  )
  response = _.pick(obj, ['taskset', 'condition', 'design', 'itemTimeEstimate',
    'timer', 'performanceFeedback', 'payment', 'maxSetSize'])

  callback(null, response)

module.exports = loadHIT
