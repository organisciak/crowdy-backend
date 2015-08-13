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
    # Count of all taskSets done by the user
    countUserAll: (callback) -> TaskSet.countUserAll(opts.user, callback)

    # Count of tasksets in the given hit done
    countUserHIT: (callback) ->
      #if opts.taskset_id is "TEST"
      #  return callback(null,1)
      return TaskSet.countUserHIT(opts.user, opts.hit_id, callback)

    # Count locks, split by firstTimers and non-first-timers
    countLocks: [(callback,obj) ->
      TaskSet.aggregate([
        {$match:
          hit_id:opts.hit_id
        },
        {$project:
          lock:
            $cond:['$lock', 1, 0]
          firstTask:
            $cond:[{$eq:['$meta.countUserHIT',0]}, 'firstTask', 'laterTasks']
        },
        {$group:
          _id:'$firstTask'
          'locks':{$sum:'$lock'}
        }
      ]).exec((err, results)->
        if err then return console.log(err,null)
        countLocks = _.reduce(results, ((map, y) ->
          map[y._id] = y.locks
          return map
        ), {})
        return callback(null, countLocks)
      )
    ],
   
    # List of user's past items completed (not specific to the current hit)
    userItemList: (callback) -> TaskSet.userItemList(opts.user, callback)

    userFacetItemList: ['userItemList', 'facet', (callback, obj) ->
      if not obj.facet
        return callback(null, obj.userItemList)

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
      payment =
        base: obj.hit.payment
        bonus:obj.hit.bonus
      callback(null, payment)
    ]

    ## Exclude workers if relevant (returns either false or an err)
    excludeWorker: ['hit', 'countLocks', 'countUserHIT', 'allHitType',
    ((callback, obj) ->
      # If we have a enough people doing later tasks, or if
      # we have too many people doing their first task, stop taking new
      # users.
      if ((obj.countLocks.laterTasks > 5 or obj.countLocks.firstTask >= 7) and
      obj.countUserHIT is 0)
        #if opts.user == 'PREVIEWUSER'
        #  return callback(null, null)
        #else
        return callback("Sorry, for the moment we're not taking new users: "+
          "there are many people in the system right now and they take "+
          " priority. We'll open up more tasks when they are available! "+
        "Try again shortly. (If you've already done a task in this set, "+
        "we do have tasks for you.)", null)

      if not obj.hit.exclude.pastInTaskType
        return callback(null, false)
      if obj.hit.exclude.pastInTaskType
        # Find hits with the same type (excluding this one)
        hit_ids = _.filter(obj.allHitType, (id) ->
          id isnt obj.hit._id.toString()
        )
        TaskSet.findOne(
          {hit_id:{$in:hit_ids}, user:opts.user}
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

    training: ['condition', (callback, obj) ->
      if obj.condition isnt 'training'
        return callback(null, null)
      TrainingSet = require './models/trainingset'
      TrainingSet
        .findOne({_id:obj.hit.trainingset_id})
        .exec((err, result) ->
          if err then return callback(err, result)
          if not result
            return callback("Can't find training information", null)
          return callback(null, result)
        )
    ]

    # Set 'design' (basic, training, and fast are designs, but the 'feedback'
    # condition needs an underlying design of its own.
    design: ['condition', (callback, obj) ->
      if obj.condition is 'feedback'
        # This assumes that feedback is always a laterTasks condition
        design = obj.hit.condition.firstTask
      else if obj.condition is 'training'
        later = obj.hit.condition.laterTasks
        # Fallback on basic if in a training/feedback condition
        design = if later is 'feedback' then 'basic' else later
      else
        design = obj.condition
      callback(null, design)
    ]

    # Get Feedback, if required
    performanceFeedback: ['design', 'allHitType', (callback, obj) ->
      if opts.user == 'PREVIEWUSER'
        return callback(null, null)
      else if obj.condition is 'feedback'
        getFeedback = require './getFeedback'
        return getFeedback(obj, callback)
      else
        return callback(null, null)
    ]

    ## Sample a facet, if relevant
    ## Facets let us define subgroups of the data, like 'queries' for an IR hit
    facet: ['hit', 'condition', 'training', 'countFacetsCompleted',
    'userFacetCounts', (callback, obj) ->
      if not obj.hit.facets or (obj.hit.facets.length is 0)
        return callback(null, null)

      if obj.condition is 'training'
        facet =
          items: obj.training.items
          meta: obj.training.meta
        return callback(null, facet)
      
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

  samplePool: ['hit', 'facet', 'training', (callback, obj) ->
    if obj.condition is 'training'
      return callback(null, obj.training.items)
    else if obj.facet
      return callback(null, obj.facet.items)
    else
      return callback(null, obj.hit.items)
  ]

    # Determine which items have already been done enough
  maxed: ['hit', 'design', 'countUserHIT', 'samplePool', 'facet',
  (callback, obj) ->
    if obj.condition is 'training'
      ''' Don't need maxed info because training set is pre-determined '''
      return callback(null, null)

    if opts.user == 'PREVIEWUSER'
      console.log "Preview user, no maxed items"
      return callback(null, [])

    # Get a list of all currentHIT items completed
    agg = [
      {$match:
        hit_id:opts.hit_id
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
    if obj.condition is 'training' then return callback(null, null)
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
  'training', (callback, obj) ->
    # Load Item model
    ItemModel = require('./models/' + obj.hit.itemModel)

    if obj.condition is 'training'
      itemSampleIds = obj.training.items
    else if obj.design is 'basic' or 'fast'
      if opts.user == 'PREVIEWUSER'
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
      return callback(null)
  ]

  itemTimeEstimate: ['design', (callback, obj) ->
    if obj.design is 'basic'
      return callback(null, obj.hit.itemTimeEstimate)
    else
      return callback(null, null)
  ]


  taskset: ['sample', 'hit', 'facet', 'performanceFeedback',
  'condition', 'design', 'countUserHIT', (callback, obj) ->
    tasks = _.map(obj.sample, (task) ->
      type: obj.hit.type
      item:
        type: obj.hit.itemModel
        id: task.id
      timeSpent: null
      contribution: null
    )

    # If taskset Id is "TEST", generate a unique one.
    if opts.taskset_id is "TEST"
      opts.taskset_id =  "TEST" + Math.floor(Math.random()*Math.pow(10,10))
      console.log "Generating unique taskset_id: " + opts.taskset_id

    if obj.performanceFeedback
      pf = obj.performanceFeedback
      percentile = (pf.worker.rank/pf.numWorkers)

    taskset =
      _id: opts.taskset_id
      lock: opts.lock
      assignment_id: opts.assignment_id
      user: opts.user
      hit_id: opts.hit_id
      facet: ( _.pick(obj.facet, ['meta', '_id']) || null)
      turk_hit_id: opts.turk_hit_id
      # This is extra information meant for easier archiving. The front-end
      # doesn't use anything in meta
      meta:
        design: obj.design
        training: (obj.hit.trainingset_id || null)
        condition: obj.condition
        countUserHIT: obj.countUserHIT
        percentile: (percentile || null)
      time:
        start:(new Date())
        submit: null
        workTime: null
      feedback:
        form: null
        satisfaction: null
      tasks:tasks
        
    # Lock in-progress files if locking was requested
    if (opts.lock is true) and (opts.user isnt "PREVIEWUSER")
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
    'timer', 'training', 'performanceFeedback', 'payment', 'maxSetSize'])

  callback(null, response)

module.exports = loadHIT
