###
GetReviewableHITs.

--autoapprove will approve relevant assignments, otherwise assignments are
simply printed.

###

async = require 'async'
libxml = require 'libxmljs'
argv = require('yargs')
        .boolean('p').alias('p', 'production')
        .describe('production', 'Run on production.')
        .help('h').alias('h', 'help')
        .boolean('autoapprove').alias('auto', 'autoapprove')
        .describe('autoapprove', 'Approve assignments.')
        .boolean('f').alias('f', 'force')
        .describe('Force approval even when a bonus is listed')
        .argv

# Use credentials file from Boto (for Python)
PropertiesReader = require 'properties-reader'
boto = PropertiesReader('/home/ec2-user/.boto')

creds =
  accessKey: boto.get('Credentials.aws_access_key_id')
  secretKey: boto.get('Credentials.aws_secret_access_key')

mturk = require('mturk')({creds: creds, sandbox: !argv.production})

asArr = (res) ->
  if (res instanceof Array) then res else [res]

# Wrapper for recursive function
getReviewableHITs = (page=1) ->
  pageSize = 100
  mturk.GetReviewableHITs(
    {PageSize:pageSize, PageNumber:page},
    (err, result) ->
      if err then return console.error err
      console.log(result)
      hits = asArr(result.HIT)
      async.forEach(hits, getAssignments, (err) ->
        if err then return console.error err
        # If there were more items left, run again
        if (result.TotalNumResults > (page * pageSize))
          page = page + 1
          getReviewableHITs(page)
      )
  )

getReviewableHITs()

getAssignments = (hit, cb) ->
  mturk.GetAssignmentsForHIT({ "HITId": hit.HITId }, (err, result) ->
    if not result.Assignment then return cb(null)
    if err then return cb(err)

    assignments = asArr(result.Assignment)
    async.forEach(assignments, reviewAssignment, cb)
  )

reviewAssignment = (assignment, cb) ->
  # Parse Answer JSON
  answerXml = libxml.parseXml(assignment.Answer, {noblanks:true})
  answerText = answerXml.root().childNodes()[0].childNodes()[1].text()
  assignment.Answer = JSON.parse(answerText)
 
  if argv.autoapprove and assignment.AssignmentStatus != 'Approved'
    # Approve Assignment
    if assignment.Answer.bonus > 0 and !argv.force
      console.log("There is a bonus specified for "
        "#{assignment.AssignmentID}. Make sure it is paid and run this "
        "script again with --force'")
      return cb(null)
    console.log('Approving' + assignment.AssignmentId)
    mturk.ApproveAssignment({ AssignmentId: assignment.AssignmentId}, cb)
  else
    # Show Assignment
    delete assignment.Answer # Delete answer mostly for easier inspection
    console.log assignment
    
  cb(null)
