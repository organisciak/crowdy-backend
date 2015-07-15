mongoose = require 'mongoose'
db = mongoose.connection

TaskSet = require './models/taskset'


saveCompletedTaskset = (tasksetData, callback) ->
  tasksetData.lock = false
  tasksetData.status = 'reviewable'
  tasksetData.time.submit = new Date()
  tasksetData.time.workTime = (tasksetData.time.submit -
    new Date(tasksetData.time.start))
  
  taskset = new TaskSet(tasksetData)
  TaskSet.findByIdAndUpdate(tasksetData._id,
    tasksetData,
    {upsert:true},
    (err, taskset) ->
      callback(err, taskset)
  )

db.close()

module.exports = saveCompletedTaskset
