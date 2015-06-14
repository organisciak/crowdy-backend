var mongoose = require('mongoose');

var taskSetSchema = mongoose.Schema({
    _id: String, // The HITId
    user: String, //Should be a hashed version of WorkerId
    hit_id: String, //My unique key for the HIT (Mongo HIT _id, not hitTypeID)
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
            type: {type: String},
            id:Number
        },
        timeSpent: Number,
        contribution:mongoose.Schema.Types.Mixed
    }]
});

var TaskSet = mongoose.model('TaskSet', taskSetSchema);

module.exports = TaskSet; 
