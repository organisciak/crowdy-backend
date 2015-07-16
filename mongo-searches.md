
# Count all tags

```
db.tasksets.aggregate({$unwind:'$tasks'}, {$unwind:'$tasks.contribution.tags'}, {$group:{_id:null, count:{$sum:1}}})
```

# Show tag counts per item

```
 db.tasksets.aggregate({$unwind:'$tasks'}, {$unwind:'$tasks.contribution.tags'}, {$group:{_id:{item:'$tasks.item.id'}, count:{$sum:1}}},{$sort:{count:-1}})
```

# Show all unique tags per item (sorted by count)

```
db.tasksets.aggregate({$unwind:'$tasks'}, {$unwind:'$tasks.contribution.tags'}, {$group:{_id:{item:'$tasks.item.id'}, list:{$push:'$tasks.contribution.tags'}, count:{$sum:1}}},{$sort:{count:-1, 'list':1}}).pretty()
```

# Count popularity of each tag

```
db.tasksets.aggregate({$unwind:'$tasks'}, {$unwind:'$tasks.contribution.tags'},{$group:{_id:{item:'$tasks.item.id'}, tags:{$push:'$tasks.contribution.tags'}}}, {$unwind:'$tags'}, {$group:{_id:{item:'$_id.item', tag:'$tags'}, count:{$sum:1}}}, {$sort:{count:-1}})
```

# Collect counts of popular tags by item

```
db.tasksets.aggregate({$unwind:'$tasks'}, {$unwind:'$tasks.contribution.tags'},{$group:{_id:{item:'$tasks.item.id'}, tags:{$push:'$tasks.contribution.tags'}}}, {$unwind:'$tags'}, {$group:{_id:{item:'$_id.item', tag:'$tags'}, count:{$sum:1}}},{$sort:{count:-1}},{$group:{_id:{item:'$_id.item'}, tagcounts:{$push:{tag:'$_id.tag', count:'$count'}}}})
```

# Determine average time spent

```
db.tasksets.aggregate({$match:{user:{$ne:"Peter"}}}, {$unwind:'$tasks'}, {$project:{'tasks.timeSpent':1, user:1}}, {$group:{_id:null, avgTime:{$avg:'$tasks.timeSpent'}}})
```

