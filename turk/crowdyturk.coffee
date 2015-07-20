###
# Various reusable functions for interacting with the Turk API
###

libxml = require 'libxmljs'
async = require 'async'

###
# Utilities
###
asArr = (res) ->
  if not res then return []
  if (res instanceof Array) then res else [res]

parseAssignment = (assignment) ->
  # Parse Answer JSON
  answerXml = libxml.parseXml(assignment.Answer, {noblanks:true})
  answerText = answerXml.root().childNodes()[0].childNodes()[1].text()
  assignment.Answer = JSON.parse(answerText)
  assignment

###
# Main Functions
###

# A wrapper around mturk library to initialize with config from ~/boto
mturk = (production) ->
  # Use credentials file from Boto (for Python)
  PropertiesReader = require 'properties-reader'
  boto = PropertiesReader(process.env.HOME + '/.boto')

  creds =
    accessKey: boto.get('Credentials.aws_access_key_id')
    secretKey: boto.get('Credentials.aws_secret_access_key')

  mturk = require('mturk')({creds: creds, sandbox: !production})
  mturk

###
# Hit Functions
###

# Recursively get reviewable HITs and run HITFunc on them
# Pass a callback that takes callback(error)
# opts.page: The page of results
# opts.print: Print the HITresults
getReviewableHITs = (hitFunc, opts, callback) ->
  if !opts.page
    opts.page = 1
  pageSize = 10
  mturk.GetReviewableHITs(
    {PageSize:pageSize, PageNumber:opts.page},
    (err, result) ->
      if err then return console.error err
      if opts.print
        console.log(result)
      hits = asArr(result.HIT)
      async.forEach(hits, hitFunc, (err) ->
        if err then return callback(err)
        # If there were more items left, run again
        if (result.TotalNumResults > (opts.page * pageSize))
          opts.page = opts.page + 1
          getReviewableHITs(opts.page, opts)
        # When there are no more pages, run the callback
        callback(null)
      )
  )

###
# Assignment Functions
###

module.exports = {
  asArr: asArr
  mturk: mturk
  parseAssignment: parseAssignment
  getReviewableHITs: getReviewableHITs
}
