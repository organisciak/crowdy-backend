express = require('express')
router = express.Router()

# GET home page.
router.get('/', (req, res, next) ->
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
  mongoose.connect 'mongodb://localhost/test'
  db = mongoose.connection
  loadHIT = require '../loadHIT'

  opts = {
    user : "TEST"
    taskset_id: "TEST"                  # What MTurk calls the HIT_id
    hit_id : "557df4899b962f181de3da0c" # The mongo ID for the hit item
    lock : true
    # Limit fields to return from item sample
    itemProjection: { url:1, description:1, title:1, image:1, likes:1, repins:1 }
  }

  db.on('error', console.error.bind(console, 'connection error:'))
  db.once('open', () ->
    loadHIT(opts, (err, results)->
      res.jsonp(results)
      mongoose.disconnect()
    )
  )
)

module.exports = router
