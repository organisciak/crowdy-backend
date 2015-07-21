'''
Get all approved assignments, save their info to Mongo, then remove from Amazon

This script doesn't approve or apply bonuses itself, it's sole purpose is
Amazon cleanup.
'''
async = require 'async'
crowdy = require './crowdyturk'
argv = require('yargs')
        .boolean('p').alias('production','p')
        .describe('production', 'Run on production.')
        .boolean('e').alias('empty-only', 'e')
        .describe('e', 'Only dispose reviewable HITs without any assignments.')
        .help('h').alias('h', 'help')
        .argv

mongoose = require 'mongoose'
config = require 'config'
db_server = 'mongodb://' + config.get('db.host') + '/' + config.get('db.name')
mongoose.connect db_server
db = mongoose.connection
TurkBackup = require '../models/turkBackup.js'

mturk = crowdy.mturk()
main = () ->
  crowdy.getReviewableHITs(saveAssignments, {}, (err) ->
    if (err) then return console.error(err)
    console.log "All assignments saved successfully"
    db.close()
  )

asArr = crowdy.asArr

saveAssignments = (hit, cb) ->
  mturk.GetAssignmentsForHIT({ HITId: hit.HITId, PageSize:100 },
  (err, result) ->
    if err then return cb(err)
    if not result.Assignment
      # HIT doesn't have completed assignments
      mturk.DisposeHIT({ HITId: hit.HITId}, (err, result) ->
        if not err then console.log "Empty HIT #{hit.HITId} was disposed."
        return cb(err)
      )
      return
    # Don't go any further if the emty-only flag is up
    if argv.e then return cb(null)
    assignments = asArr(result.Assignment)
    async.forEach(assignments, saveAssignment, (err) ->
      if err then return cb(err)
      # The assignments seem to have saved properly, so dispose of the HIT
      mturk.DisposeHIT({ HITId: hit.HITId}, (err, result) ->
        if not err then console.log "#{hit.HITId} saved and disposed."
        cb(err)
      )
    )
  )

# Save an Individual Assignment to Mongo
saveAssignment = (assignment, cb) ->
  if assignment.AssignmentStatus not in ['Approved', 'Rejected']
    console.log assignment
    return cb("#{assignment.AssignmentId} does not have an expected status.
    Don't run this script until all assignments are reviewed.")
  assignment._id = assignment.AssignmentId
  assignment.sandbox = true
  turkBackup = new TurkBackup(assignment)
  turkBackup.save((err, res) -> cb(err))

main()
