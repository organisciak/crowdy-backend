###
GetReviewableHITs.

--autoapprove will approve relevant assignments, otherwise assignments are
simply printed.

###

async = require 'async'
libxml = require 'libxmljs'
crowdy = require './crowdyturk'
argv = require('yargs')
        .boolean('p').alias('p', 'production')
        .describe('production', 'Run on production.')
        .help('h').alias('h', 'help')
        .boolean('autoapprove').alias('auto', 'autoapprove')
        .describe('autoapprove', 'Approve assignments.')
        .boolean('f').alias('f', 'force')
        .describe('Force approval even when a bonus is listed')
        .argv

mturk = crowdy.mturk(argv.production)
asArr = crowdy.asArr

main = () ->
  crowdy.getReviewableHITs(getAssignments, {print:true}, (err) ->
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
 
  if argv.autoapprove and assignment.AssignmentStatus != 'Approved'
    # Approve Assignment
    if assignment.Answer.bonus > 0 and !argv.force
      console.log("There is a bonus specified for"
        "#{assignment.AssignmentId}. Make sure it is paid and run this"
        "script again with --force'")
      return cb(null)
    else
      console.log('Approving' + assignment.AssignmentId)
      mturk.ApproveAssignment({ AssignmentId: assignment.AssignmentId}, cb)
  else
    # Show Assignment
    if assignment.Answer.bonus
      console.log "#{assignment.Answer.bonus} bonus owed."
    delete assignment.Answer # Delete answer for easier inspection
    console.log assignment
    cb(null)

main()
