express = require 'express'
router = express.Router()
saveCompletedTaskset = require '../saveCompletedTaskset'

router.post('/hit', (req, res, next) ->
  saveCompletedTaskset(req.body, (err,results) ->
    if (err)
      res.send(err)
    else
      res.send(results)
  )
)

module.exports = router
