var mongoose = require('mongoose');

// Define Model Schema
var taskSetSchema = mongoose.Schema({
    _id: String, // What MTurk refers to as a HITId
    // The lock let's us save a "placeholder" task set
    // One that is not yet completed, but it in-progress
    // This allows us to lock in-progress items.
    lock:Boolean,
    // Status to mimic the MTurk status
    // see http://mechanicalturk.typepad.com/blog/2011/04/overview-lifecycle-of-a-hit-.html
    status:String,
    user: String, //Should be a hashed version of WorkerId
    hit_id:String, //My unique key for the HIT (Mongo HIT _id, not hitTypeID)
    assignment_id:String,
    time:{
        start: Date, //AcceptTime
        submit: Date, //SubmitTime
        workTime: Number //WorkTimeInSeconds
    },
    feedback:{ 
        form: String,
        satisfaction: String,
        pay:String
    },
    tasks:[{
        //'type' is a reserved word, so when I want 'type'
        // to actually be in my schema, it needs to be defined
        // with { type: String }
        type: {type: String}, //Match hit.type e.g. 'Image tagging', 
        item:{
            type: { type: String }, //e.g. 'pin'; should reference model
            id:Number
        },
        timeSpent: Number,
        contribution:mongoose.Schema.Types.Mixed
    }]
});

// Define Class Methods
taskSetSchema.statics.countUserAll = function(user, callback) {
    return this.count({user:user, lock:{$ne:true}}).exec(callback);
};

taskSetSchema.statics.countUserHIT = function(user, hit_id, callback) {
    return this.count({user:user, hit_id:hit_id, lock:{$ne:true}}).exec(callback);
};

taskSetSchema.statics.clearLocks = function(user, callback) {
    // Remove tasksets with expired locks 
    find_outdated_locks = {
        lock:true,
        $or:[
            // If the user already has a lock on something else on, unlock it
            {user:user},
            // If the start time is older than (Now-1h), it's a stale lock
            {'time.start':{$lte:new Date(new Date()-60*60*1000)}}
        ]
    };
    return this.remove(find_outdated_locks, callback);
};

// List of all items a user can completed
taskSetSchema.statics.userItemList = function(user, callback){
    return this.aggregate([
            {$match: {user:user, lock:{$ne:true}}},
            {$project:{"tasks.item.id":1}},
            {$unwind : "$tasks"},
            {$group: {_id:"$tasks.item.id"}}
    ]).exec(callback);
};

// Define Instance Methods

// Create Model and Export

var TaskSet = mongoose.connection.model('tasksets', taskSetSchema);

module.exports = TaskSet; 
