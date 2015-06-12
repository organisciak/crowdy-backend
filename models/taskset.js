var mongoose = require('mongoose');
//mongoose.connect('mongodb://localhost/test');

var taskSetSchema = mongoose.Schema({
    turk_id: String,
    user: String,
    time:{
        start: String,
        end: String,
        completion: String
    },
    feedback:{ 
        form: String,
        satisfaction: String
    },
    tasks:[

    ]
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
