'''
Get all approved assignments, save their info to Mongo, then remove from Amazon

This script doesn't approve or apply bonuses itself, it's sole purpose is
Amazon cleanup.
'''
async = require 'async'
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

# Use credentials file from Boto
PropertiesReader = require 'properties-reader'
boto = PropertiesReader('/home/ec2-user/.boto')

creds =
  accessKey: boto.get('Credentials.aws_access_key_id')
  secretKey: boto.get('Credentials.aws_secret_access_key')

mturk = require('mturk')({creds: creds, sandbox: !argv.production})

main = () ->
  getReviewableHITs()

asArr = (res) ->
  if not res then return []
  if (res instanceof Array) then res else [res]

# Wrapper for recursive function
getReviewableHITs = (page=1) ->
  pageSize = 10
  mturk.GetReviewableHITs(
    {PageSize:pageSize, PageNumber:page},
    (err, result) ->
      if err then return console.error err
      if result.NumResults is 0
        return db.close()
      console.log(result)
      hits = asArr(result.HIT)
      async.forEach(hits, saveAssignments, (err) ->
        if err
          console.error err
          db.close()
        # If there were more items left, run again
        if (result.TotalNumResults > (page * pageSize))
          page = page + 1
          setTimeout((()->getReviewableHITs(page)), 4000)
        else
          db.close()
      )
  )

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
