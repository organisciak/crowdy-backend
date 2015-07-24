###
View all available assignments for all HITs in account

###

async = require 'async'
libxml = require 'libxmljs'
crowdy = require './crowdyturk'
argv = require('yargs')
        .boolean('p').alias('p', 'production')
        .describe('production', 'Run on production.')
        .help('h').alias('h', 'help')
        .argv

mturk = crowdy.mturk(argv.production)
asArr = crowdy.asArr

main = () ->
  crowdy.getHITs(getAssignments, {print:true, status:'all'}, (err) ->
    if err then return console.error err
    console.log("Done reviewing HITs")
  )

getAssignments = (hit, cb) ->
  mturk.GetAssignmentsForHIT({ "HITId": hit.HITId }, (err, result) ->
    if not result.Assignment then return cb(null)
    if err then return cb(err)

    assignments = asArr(result.Assignment)
    async.forEach(assignments, reviewAssignment, cb)
  )

reviewAssignment = (assignment, cb) ->
  assignment = crowdy.parseAssignment(assignment)
  # Show Assignment
  delete assignment.Answer # Delete answer for easier inspection
  console.log assignment
    
  cb(null)

main()
