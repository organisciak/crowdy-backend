mongoose = require 'mongoose'
db = mongoose.createConnection 'mongodb://localhost/test'

TaskSet = require './models/taskset'


saveCompletedTaskset = (tasksetData, callback) ->
  taskset = new TaskSet(tasksetData)
  TaskSet.findByIdAndUpdate(tasksetData._id, tasksetData, {upsert:true}, (err, taskset) ->
    callback(err, taskset)
    db.close()
    )

module.exports = saveCompletedTaskset
