var mongoose = require('mongoose');

// Define Model Schema
var taskSetSchema = mongoose.Schema({
    _id: String, // The HITId
    user: String, //Should be a hashed version of WorkerId
    hit_id:String, //My unique key for the HIT (Mongo HIT _id, not hitTypeID)
    time:{
        start: String, //AcceptTime
        submit: String, //SubmitTime
        workTime: Number //WorkTimeInSeconds
    },
    feedback:{ 
        form: String,
        satisfaction: String
    },
    tasks:[{
        //'type' is a reserved word, so when I want 'type'
        // to actually be in my schema, it needs to be defined
        // with { type: String }
        type: {type: String},
        item:{
            type: { type: String },
            id:Number
        },
        timeSpent: Number,
        contribution:mongoose.Schema.Types.Mixed
    }]
});

// Define Class Methods
taskSetSchema.statics.countUserAll = function(user, callback) {
    return this.count({user:user}).exec(callback);
};

taskSetSchema.statics.countUserHIT = function(user, hit_id, callback) {
    return this.count({user:user, hit_id:hit_id}).exec(callback);
};

// List of all items a user can completed
taskSetSchema.statics.userItemList = function(user, callback){
    return this.aggregate([
            {$match: {user:user}},
            {$project:{"tasks.item.id":1}},
            {$unwind : "$tasks"},
            {$group: {_id:"$tasks.item.id"}}
    ]).exec(callback);
};

// Define Instance Methods

// Create Model and Export

var TaskSet = mongoose.model('tasksets', taskSetSchema);

module.exports = TaskSet; 
