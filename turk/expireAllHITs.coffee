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
PropertiesReader = require 'properties-reader'
boto = PropertiesReader('/home/ec2-user/.boto')

creds =
  accessKey: boto.get('Credentials.aws_access_key_id')
  secretKey: boto.get('Credentials.aws_secret_access_key')

mturk = require('mturk')({creds: creds, sandbox: !argv.production})

main = () ->
  expireAllHITs()

asArr = crowdy.asArr

# Wrapper for recursive function
expireAllHITs = (page=1) ->
  pageSize = 10
  mturk.SearchHITs(
    {PageSize:pageSize, PageNumber:page},
    (err, result) ->
      if err then return console.error err
      if result.NumResults is 0
        return db.close()
      hits = asArr(result.HIT)
      expireableHITs = hits.filter((hit) ->
        return (hit.HITStatus not in ['Reviewable', 'Reviewing'])
      )
      async.forEach(hits, forceExpire, (err) ->
        if err then return console.error err
        # If there were more items left, run again
        if (result.TotalNumResults > (page * pageSize))
          page = page + 1
          setTimeout((()->expireAllHITs(page)), 4000)
        else
          console.log("All HITs Expired")
      )
    )

forceExpire = (hit, cb) ->
  mturk.ForceExpireHIT({ HITId: hit.HITId }, (err, result) ->
    if not err then console.log("Expired HIT " + hit.HITId)
    return cb(err)
  )

main()
