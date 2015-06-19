mongoose = require 'mongoose'
db = mongoose.connection

TaskSet = require './models/taskset'


saveCompletedTaskset = (tasksetData, callback) ->
  taskset = new TaskSet(tasksetData)
  TaskSet.findByIdAndUpdate(tasksetData._id, tasksetData, {upsert:true}, (err, taskset) ->
    callback(err, taskset)
    )

db.close()

module.exports = saveCompletedTaskset
