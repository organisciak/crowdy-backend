loadHIT = require '../loadHIT'

query =
 assignment_id:'TEST'
 hit_id: '55bc94fb887cb2a616d5b2b3'
 lock: true
 taskset_id: 'TEST'
 turk_hit_id: 'NONE'
 user: 'PREVIEWUSER'

loadHIT(query, (err, results)->
  if (err)
    console.error err
  else
    console.log results
  return
)
