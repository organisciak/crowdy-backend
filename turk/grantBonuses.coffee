###
Grant Bonuses.

###

async = require 'async'
libxml = require 'libxmljs'
crowdy = require './crowdyturk'
_ = require 'lodash'
argv = require('yargs')
        .boolean('p').alias('p', 'production')
        .describe('production', 'Run on production.')
        .help('h').alias('h', 'help')
        .string('r').alias('r', 'reason')
        .describe('reason', "The message to send workers with the bonus. " +
        "This can be a lodash/underscore template, with access to the " +
        "following variables: assignmentId, bonus, taskLength")
        .default('reason', 'Thank you for completing this assignment!')
        .boolean('f').alias('f', 'force')
        .describe('Force approval even when a bonus is listed')
        .argv

mongoose = require 'mongoose'
config = require 'config'
db_server = 'mongodb://' + config.get('db.host') + '/' + config.get('db.name')
mongoose.connect db_server
db = mongoose.connection
Bonus = require '../models/bonus.js'
TaskSet = require '../models/taskset.js'

mturk = crowdy.mturk(argv.production)

main = () ->
  crowdy.getHITs(getSubmittedAssignments,
    {print:false, status:'all'},
    (err) ->
      if err then return console.error err
      console.log("Done reviewing HITs")
  )

getSubmittedAssignments = (hit, cb) ->
  mturk.GetAssignmentsForHIT({ "HITId": hit.HITId }, (err, result) ->
    if not result.Assignment then return cb(null)
    if err then return cb(err)

    assignments = crowdy.asArr(result.Assignment)
    #Filter to 'Submitted' Assignments
    assignments = assignments.filter((as) -> as.AssignmentStatus == 'Submitted')

    async.forEach(assignments, grantBonus, cb)
  )

grantBonus = (assignment, cb) ->
  assignment = crowdy.parseAssignment(assignment)
  
  if !assignment.Answer.bonus
    return cb("No bonus specified for assignment.WorkerId")

  console.log "#{assignment.Answer.bonus} bonus owed to #{assignment.WorkerId}"

  async.series([
    # Doublecheck that bonus hasn't already been payed
    ((callback) ->
      Bonus.find({
        _id:assignment.AssignmentId,
        user:assignment.WorkerId
      },
      (err, results) ->
        if results.length isnt 0
          return callback("There was already a bonus paid")
        else
          callback(err)
      )
    ),
    # Confirm that the Bonus is the same that we can saved in our DB
    ((callback) ->
      TaskSet.verifyBonus(assignment.AssignmentId, assignment.Answer.bonus,
        callback)
    ),
    # Pay bonus
    ((callback) ->
      console.log("Paying bonus to #{assignment.AssignmentId}")
      reasonTemplate = _.template(argv.reason)
      params = {
        WorkerId: assignment.WorkerId
        AssignmentId: assignment.AssignmentId
        BonusAmount:
          Amount: assignment.Answer.bonus
          CurrencyCode: "USD"
        Reason: reasonTemplate({
          assignmentId:assignment.AssignmentId
          bonus:assignment.Answer.bonus
          taskLength:assignment.Answer.tasks.length
        })
      }
      console.log(params)
      mturk.GrantBonus(params, callback)
    ),
    # Approve assignment
    ((callback)->
      console.log("Approving #{assignment.AssignmentId}")
      mturk.ApproveAssignment({
        AssignmentId: assignment.AssignmentId
      }, callback)
    )
    # Save a record of the bonus to MTurk
    ((callback)->
      bonus = new Bonus({
        _id: assignment.AssignmentId
        date: new Date()
        user: assignment.WorkerId
        bonus: assignment.Answer.bonus
      })
      bonus.save(callback)
    )
  ], (err, result) ->
    cb(err)
  )
  
main()
