mongoose = require 'mongoose'
_ = require 'lodash'

TaskSet = require './models/taskset'
Hit = require './models/hit'
ObjectId = mongoose.Types.ObjectId

getFeedback = (obj, callback) ->
  switch obj.hit.type
    when 'relevance judgments'
      console.log "Should be here"
    when 'image tagging'
      return callback("No image tagging feedback yet")
    else
      return callback("No feedback logic for type: #{obj.hit.type}", null)
  console.log obj.hit.type
  callback("No Feedback yet", null)

module.exports = getFeedback
