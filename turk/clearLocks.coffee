# ClearLocks
# ===========
#
# Check which locked files are no longer unassignable
#
# The Turk API tells you if a HIT is unassignable (all assignments
# started or submitted), but doesn't tell you if the individual assignments
# are available. So, the best we can do is watch for assignment locks in our
# database when HIT.NumberofAssignmentsPending is 0. If it's >0 but <All,
# we don't know which assignment is improperly locked.
# The workaround for this would be to put up only 1 assignment HITs, though
# the trade-off there is that you may annoy hi-frequency workers by saying
# you have, say, 100 assignments when you only a few.

async = require 'async'
crowdy = require './crowdyturk'
argv = require('yargs')
        .boolean('p').alias('p', 'production')
        .describe('production', 'Run on production.')
        .help('h').alias('h', 'help')
        .argv

mturk = crowdy.mturk(argv.production)

mongoose = require 'mongoose'
config = require 'config'
db_server = 'mongodb://' + config.get('db.host') + '/' + config.get('db.name')
mongoose.connect db_server
db = mongoose.connection
TaskSet = require '../models/taskset.js'

main = () ->
  async.parallel({
    lockedInMongo:getLocked
    noPending:getNoPending
  }, (err, result)->
    if err then console.error(err)
    # Compare the two lists
    toClear = result.lockedInMongo.filter((doc) ->
      return (doc.turk_hit_id in result.noPending)
    )
    if toClear.length == 0
      console.log "No errant locks"
    else
      console.log "#{toClear.length} locks to be removed"

    toClearIds = toClear.map((item)->item._id)
    # Clear locks from thats where we know there shouldn't be any
    TaskSet.remove({_id:{$in: toClearIds}, lock:true})
      .exec((err, results) ->
        if (err) then console.error err
        db.close()
      )
  )

getLocked = (callback) ->
  TaskSet.find({lock:true}).select('turk_hit_id').exec(callback)

# Get HITs with 0 pending assignments.
getNoPending = (callback) ->
  matchingHITs = []
  crowdy.getHITs(
    ((hit, cb) ->
      matchingHITs.push hit.HITId
      cb(null)
    ),
    {
      print:false
      filter: (hit) -> return (parseInt(hit.NumberOfAssignmentsPending) is 0)
    },
    (err) ->
      callback(err, matchingHITs)
  )

main()
