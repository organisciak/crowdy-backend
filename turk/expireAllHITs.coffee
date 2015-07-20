'''
Expire all your HITs at once.

This is the atomic approach, when you push something out accidentally and need
to fix it. Hopefully it's not needed!
'''
async = require 'async'
crowdy = require './crowdyturk'
argv = require('yargs')
        .boolean('p').alias('production','p')
        .describe('production', 'Run on production.')
        .help('h').alias('h', 'help')
        .argv

# Use credentials file from Boto
mturk = crowdy.mturk()

main = () ->
  # Wrapper for recursive function
  crowdy.getHITs(forceExpire,
    {
      status: 'all'
      print: true
      statusFilter:['Reviewable', 'Reviewing']
    },
    (err) ->
      if err then return console.error err
      console.log("All HITs Expired")
  )

forceExpire = (hit, cb) ->
  mturk.ForceExpireHIT({ HITId: hit.HITId }, (err, result) ->
    if not err then console.log("Expired HIT " + hit.HITId)
    return cb(err)
  )

main()
