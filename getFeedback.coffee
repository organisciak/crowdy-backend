mongoose = require 'mongoose'
async = require 'async'
_ = require 'lodash'

TaskSet = require './models/taskset'
Hit = require './models/hit'
ObjectId = mongoose.Types.ObjectId

getFeedback = (obj, callback) ->
  # Call type-specific method
  switch obj.hit.type
    when 'relevance judgments'
      return getRelevanceFeedback(obj, callback)
    when 'image tagging'
      return getTaggingFeedback(obj, callback)
    else
      return callback("No feedback logic for type: #{obj.hit.type}", null)
  callback("No Feedback yet", null)

# Get feedback for Image-Tagging
# Relies on manual annotations saved to db.tagqualities
getTaggingFeedback = (obj, callback) ->
  TagQuality = require './models/tagquality'

  async.parallel({
    qJudgments: (cb) -> TagQuality.find().exec(cb)
    # Get a list with user:user, tags:[{item,tag}] per row
    byUser: (cb) -> TaskSet.aggregate(
      {$match:{hit_id:{$in:obj.allHitType}}},
      {$unwind: '$tasks'}, {$unwind:'$tasks.contribution.tags'},
      {$project:{
        item:'$tasks.item.id',
        user:1,
        tag: $toLower: '$tasks.contribution.tags'
      }},
      {$group:{_id:{user:'$user'}, tags:{$push:{item:'$item', tag:'$tag'}}}}
    ).exec(cb)
    # REMOVING FOR A HARDCODED VALUE
    #singleCountTags: (cb) -> TaskSet.aggregate(
    #  {$match:{hit_id:{$in:obj.allHitType}}},
    #  {$unwind: '$tasks'},
    #  {$unwind:'$tasks.contribution.tags'},
    #  {$project:{
    #    item:'$tasks.item.id',
    #    tag:{$toLower:'$tasks.contribution.tags'}}},
    #  {$group:{_id:{item:'$item', tag:'$tag'}, count:{$sum:1}}},
    #  {$match:{count:1}},
    #  {$group:{_id:null, tags:{$push:'$_id'}}}
    #).exec(cb)
  }, (err, results) ->
    if (err)
      return console.error err
    # Make quality judgements into an associative array for quick lookup
    qual = results.qJudgments.reduce(((map, doc)->
      item = String(doc.item_id)
      if not map[item]
        map[item] = {}
      map[item][doc.tag] = doc.quality
      return map
    ),{})

    # REMOVING FOR A HARDCODED VALUE
    # For unseen items, set a default score based on the average rating of
    # items that have only been seen once
    #singleItemJudgments = _.map(results.singleCountTags[0].tags, (tag) ->
    #  return qual[tag.item][tag.tag]
    #)
    #unseenScore = _.sum(singleItemJudgments)/singleItemJudgments.length

    # Hardcoded. The average for once tagged items is 2.5, so round down
    unseenScore = 2

    byWorker = _.map(results.byUser, (user) ->
      scores =_.map(user.tags, (row) ->
        quality = parseInt(qual[String(row.item)][row.tag])
        if quality not in [0,1,2,3,4]
          quality = unseenScore
        quality
      )
      avgScore = _.sum(scores)/scores.length
      {user:user._id.user, avgScore:avgScore}
    )
    
    allScores = _.map(byWorker, (w) -> w.avgScore).sort((a,b)-> a-b)
    worker = _.find(byWorker, (w) -> w.user is obj.opts.user)
    performanceFeedback =
      numWorkers: allScores.length
      min: _.min(allScores)
      max: _.max(allScores)
      worker:
        performance: worker.avgScore
        rank: 1+allScores.indexOf(worker.avgScore)

    return callback(null, performanceFeedback)
  )

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
    worker = _.find(byWorker, (w) -> w.user is obj.opts.user)
    performanceFeedback =
      numWorkers: allScores.length
      min: _.min(allScores)
      max: _.max(allScores)
      worker:
        performance: worker.avgScore
        rank: 1+allScores.indexOf(worker.avgScore)

    callback(null, performanceFeedback)
  )


module.exports = getFeedback
