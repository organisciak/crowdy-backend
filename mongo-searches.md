
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
db.tasksets.aggregate({$match:{user:{$ne:"Peter"}}},{$unwind:'$tasks'}, {$project:{'tasks.timeSpent':1, user:1, 'hit_id':1}}, {$group:{_id:hit_id, avgTime:{$avg:'$tasks.timeSpent'}}})
```

# Determine completed and locked files

This is useful for tracking a task during completion

```
db.tasksets.aggregate({$match:{hit_id:/55a48ddcc/}}, {$unwind:'$tasks'}, {$project:{'tasks.item.id':1, numLocked:{$cond:['$lock', 1, 0]}}}, {$group:{_id:{task:'$tasks.item.id'}, count:{$sum:1}, locked:{$sum:'$numLocked'}}},{$sort:{count:-1, locked:-1}})
```

Also, a way to count number of locks, by first task/later task
```
db.tasksets.aggregate([{$match: {hit_id:"55cb008134b17c3926015c94"}}, {$project:{lock:{$cond:['$lock', 1, 0]}, firstTask: {$cond:[{$eq:['$meta.countUserHIT',0]}, 'firstTask', 'laterTasks']}}}, {$group:{_id:'$firstTask','locks':{$sum:'$lock'}}}])
```


# Count number of items completed in a set (like in fast condition, where item count is not constant)

```
db.tasksets.aggregate({$match:{hit_id:/55a48ddcc8f1/}}, {$unwind:'$tasks'}, {$group:{_id:'$_id', numCompleted:{$sum:1}}}, {$sort:{numCompleted:-1}})
```
