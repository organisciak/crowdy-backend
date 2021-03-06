express = require('express')
router = express.Router()

# /index.html should defer to static folder

router.get('/test', (req, res, next) ->
  res.render('index', { title: 'Express' })
)


# Send JSON to /json
router.get('/json', (req, res) ->
  sampleObject = { "name": "P", 3:true }
  res.jsonp(sampleObject)
)

# Get HIT
router.get('/hit', (req, res) ->

  mongoose = require 'mongoose'
  db = mongoose.connection
  loadHIT = require '../loadHIT'

  # Expected query params:
  # USER: user_id
  # taskset_id: the HITid from MTurk
  # hit_id: the unique hit id assigned when the task is uploaded
  # lock: boolean value telling server to lock the returned items or not
  #
  # validate input
  for key in ['user', 'taskset_id', 'hit_id', 'lock']
    if not req.query.hasOwnProperty key
      res.jsonp({ status: 500, message: 'Missing parameter:'+key})
      return

  req.query.lock = if req.query.lock is 'true' then true else false
  loadHIT(req.query, (err, results)->
    if (err)
      res.jsonp({ status:500, message: err })
    else
      res.jsonp(results)
    return
  )
)

module.exports = router
