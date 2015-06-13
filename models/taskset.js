var mongoose = require('mongoose');

var taskSetSchema = mongoose.Schema({
    _id: String, // The HITId
    user: String, //Should be a hashed version of WorkerId
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

/* EXAMPLE
// Adding a method to the schema
// Note that methods must be added to the schema before compiling into a model
kittySchema.methods.speak = function () {
    var greeting = this.name ? "Meow name is " + this.name : "I don't have a name";
    console.log(greeting);
};
*/

var TaskSet = mongoose.model('TaskSet', taskSetSchema);

module.exports = TaskSet; 
