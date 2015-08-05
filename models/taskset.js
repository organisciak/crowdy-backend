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
    status:{type:String},
    user: String, //Should be a hashed version of WorkerId
    hit_id:String, //My unique key for the HIT (Mongo HIT _id, not hitTypeID)
    // Information about the facet, if used (corresponds to embedded doc in
    // hit.facets
    facet: {
        _id: mongoose.Schema.Types.ObjectId,
        meta: mongoose.Schema.Types.Mixed,
    },
    turk_hit_id: String, // Amazon's key for the HIT
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
    payment: {type:Number, default: 0},
    // Total Bonus (for task, + per item bonuses)
    bonus: {type:Number, default: 0},
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
        bonus: {type:Number, default: null},
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

taskSetSchema.statics.countFacetsCompleted = function(hit_id, callback) {
    // Return a sorted list of items completed for all the facets, started with the lowest
    var count_by_facets = [
        {$match:{
                    hit_id: hit_id,
                    facet:{$exists:true},
                    'facet._id':{$exists:true},
                    $or:[ {lock:true}, {status:'reviewable'} ]
                }},
        {$project:{'facet':'$facet._id', 'tasks':1}},
        {$unwind:'$tasks'},
        {$group:{_id:'$facet', count:{$sum:1}}},
        {$sort:{count:1}}
    ];
    return this.aggregate(count_by_facets, callback);
};

taskSetSchema.statics.clearLocks = function(user, callback) {
    // Remove tasksets with expired locks 
    var find_outdated_locks = {
        lock:true,
        $or:[
            // If the user already has a lock on something else on, unlock it
            {user:user},
            // If the start time is older than (Now-30m), it's a stale lock
            {'time.start':{$lte:new Date(new Date()-30*60*1000)}}
        ]
    };
    return this.remove(find_outdated_locks, callback);
};

// List of all items a user has completed
taskSetSchema.statics.userItemList = function(user, callback){
    return this.aggregate([
            {$match: {user:user, lock:{$ne:true}}},
            {$project:{"facet._id":1, "tasks.item.id":1}},
            {$unwind : "$tasks"},
            {$group: {_id:{facet:"$facet._id", item:"$tasks.item.id"}}}
    ]).exec(callback);
};

// Verify a bonus amount
taskSetSchema.statics.verifyBonus = function(_id, bonus, callback){
    this.findOne({_id:_id, bonus:bonus}, function(error, results) {
        if (error) { return callback(error); }
        if (!results || results.length === 0) {
            return callback("Didn't find assignment " + _id +
                "with a bonus of " + bonus);
        } else {
            // First test passed, no verify that the bonus *amount* was correct
            // based on HIT.payment.bonus.items
            // TODO
            return callback(null);
        }
    });
};

// Define Instance Methods

// Create Model and Export

var TaskSet = mongoose.connection.model('tasksets', taskSetSchema);

module.exports = TaskSet; 
