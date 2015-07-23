# Various reusable functions for interacting with the Turk API
# ============================================================

libxml = require 'libxmljs'
async = require 'async'
_ = require 'lodash'

# Utilities
# ---------

# ### asArr
# _Force response that can be string, array, or undefined to an array._
asArr = (res) ->
  if not res then return []
  if (res instanceof Array) then res else [res]

parseAssignment = (assignment) ->
  # Parse Answer JSON
  answerXml = libxml.parseXml(assignment.Answer, {noblanks:true})
  answerText = answerXml.root().childNodes()[0].childNodes()[1].text()
  assignment.Answer = JSON.parse(answerText)
  assignment

# Main Functions
# --------------

# ### mturk
# _A wrapper around mturk library to initialize with config from ~/boto._

# Initializing crowdy.lib (alias for mturklib) will set this local variable
# also.
mturk = null

mturklib = (production) ->
  # Use credentials file from Boto (for Python)
  PropertiesReader = require 'properties-reader'
  boto = PropertiesReader(process.env.HOME + '/.boto')

  creds =
    accessKey: boto.get('Credentials.aws_access_key_id')
    secretKey: boto.get('Credentials.aws_secret_access_key')

  mturk = require('mturk')({creds: creds, sandbox: !production})
  mturk

# Hit Functions
# -------------

# ### GetHITs
#
# Recursively get HITs and run HITFunc on them.
# - hitFunc : function that takes (hit, callback) args. Should send
#   callback(error) on completion
# - opts.page: The page of results
# - opts.print: Print the HITresults
# - opts.status: Which HITs to retrieve. Allowable are "reviewable" and "all"
# - opts.pageSize: How many HITs to retrieve *and process asynchronously* at a
#   time
# - opts.statusFilter: Array of hit statuses to exclude. Possible values are
#   "Assignable", "Unassignable", "Reviewable", or "Reviewing". See
#   http://mechanicalturk.typepad.com/blog/2011/04/overview-lifecycle-of-a-hit-.html
#   for details.
# - opts.filter: function or array of functions for filtering hits
#     e.g. Filter by # pending
#     ```
#     opts.filter = [function(hit){
#         return (hit.NumberOfAssignmentsPending === 0)
#     }]
getHITs = (hitFunc, opts, callback) ->
  defaults = {
    page: 1
    print: false
    pageSize: 10
    status: 'all'
    statusFilter: []
    filter: []
  }
  opts = _.extend(defaults, opts)

  if opts.status is 'reviewable'
    hitSearchFuncKey = 'GetReviewableHITs'
  else if opts.status is 'all'
    hitSearchFuncKey = 'SearchHITs'
  else
    return console.error "${opts.status} is not a supported value for
                          opts.status"
  # If there's no function to run over all hits, support a null hitFunc
  if !hitFunc or !_.isFunction(hitFunc)
    # Using a dummy function
    hitFunc = (hit, callback) -> return callback(null)

  # Wrap function filter args in array and type check while we're at it
  if _.isFunction(opts.filter)
    opts.filter = [opts.filter]
  else if not _.isArray(opts.filter)
    console.log "opts.filter has to be a function or array of functions"

  # Conver opts.statusFilter to opts.filter
  if opts.statusFilter.length > 0
    f = ((hit) -> return !(hit.HITStatus in opts.statusFilter))
    opts.filter.push f

  mturk[hitSearchFuncKey](
    {PageSize:opts.pageSize, PageNumber:opts.page},
    (err, result) ->
      if err then return console.error err
      if result.NumResults is 0 then return callback(null)

      if opts.print
        console.log(result)
      hits = asArr(result.HIT)
      # Filter HITs, if asked
      if opts.filter.length isnt 0
        for f in opts.filter
          if opts.print
            console.log "Filtering"
          hits = hits.filter f

      async.forEach(hits, hitFunc, (err) ->
        if err then return callback(err)

        # If there are more items left, run again
        if (result.TotalNumResults > (opts.page * opts.pageSize))
          opts.page = opts.page + 1
          # Wait a moment so Amazon doesn't lock us out
          return setTimeout((()->getHITs(hitFunc, opts, callback)), 4000)
        else
          # When there are no more pages, run the callback
          return callback(null)
      )
  )

# ### getReviewableHits
# Wrapper around getHITs
getReviewableHITs = (hitFunc, opts, callback) ->
  opts = _.extend(opts, {status: 'reviewable', statusFilter: []})
  getHITs(hitFunc, opts, callback)

# Assignment Functions
# --------------------


module.exports = {
  asArr: asArr
  mturk: mturklib
  parseAssignment: parseAssignment
  getHITs: getHITs
  getReviewableHITs: getReviewableHITs
}
