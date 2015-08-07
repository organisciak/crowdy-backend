mongoose = require 'mongoose'
async = require 'async'
_ = require 'lodash'

TaskSet = require './models/taskset'
Hit = require './models/hit'
ObjectId = mongoose.Types.ObjectId

getFeedback = (obj, callback) ->
  switch obj.hit.type
    when 'relevance judgments'
      return getRelevanceFeedback(obj, callback)
    when 'image tagging'
      return callback("No image tagging feedback yet")
    else
      return callback("No feedback logic for type: #{obj.hit.type}", null)
  callback("No Feedback yet", null)

getRelevanceFeedback = (obj, callback) ->
  # This part of the aggregation pipeline will return unwound rows of
  # _id/user/judgment/query/item_id
  unwindJudgments = [
    {$match:{hit_id:{$in:obj.allHitType}}},
    {$unwind:'$tasks'},
    {$project:{
      user:1,
      judgment:'$tasks.contribution.relevance',
      query:'$facet.meta.query'
      item_id:'$tasks.item.id'
    }},
    {$unwind: '$judgment'}]
  
  # This will return all the judgments per result
  # i.e. {_id:QUERY,ITEM_ID, judgments;['Not', 'Somewhat','Not', ...]}
  byItemQuery = unwindJudgments.concat([
    {$group:{
      _id:{query:'$query', item:'$item_id'},
      judgments:{$push:'$judgment'}
    }}
  ])

  ## This will return all the judgments by worker; i.e.
  # {"_id": USER, "judgments" :[{"doc":{"query","item"}, "judgment"},...]}
  byWorkerQuery = unwindJudgments.concat([
    {$group:{
      _id:'$user',
      judgments:{
        $push:{doc:{query:'$query', item:'$item_id'}, judgment:'$judgment'}
      }
    }}
  ])

  async.parallel({
    byWorker: (cb) -> TaskSet.aggregate(byWorkerQuery).exec(cb)
    byItem: (cb) -> TaskSet.aggregate(byItemQuery).exec(cb)
  }, (err, results) ->
    byItem = results.byItem.reduce(((map, doc)->
      id = "#{doc._id.query}-#{doc._id.item}"
      judgeCounts = _.countBy(doc.judgments)
      judgeProbs = _.mapValues(judgeCounts, (val)-> val/doc.judgments.length)
      map[id] = {counts:judgeCounts, probs:judgeProbs}
      map
    ),{})
    byWorker = _.map(results.byWorker, (worker) ->
      user = worker._id
      scores = _.map(worker.judgments,(tuple)->
        id = "#{tuple.doc.query}-#{tuple.doc.item}"
        score = byItem[id].probs[tuple.judgment]
        {id: id, score: score}
      )
      rawScores =_.map(scores, (v)->v.score)
      avgScore = _.sum(rawScores)/rawScores.length
      {user:user, scores: scores, avgScore:avgScore}
    )
    allScores = _.map(byWorker, (w) -> w.avgScore).sort((a,b)-> a-b)
    worker = _.find(byWorker, (w) -> w.user is "PETER")
    performanceFeedback =
      numWorkers: allScores.length
      min: _.min(allScores)
      max: _.max(allScores)
      worker:
        performance: worker.avgScore
        rank: allScores.indexOf(worker.avgScore)

    callback(null, performanceFeedback)
  )


module.exports = getFeedback
