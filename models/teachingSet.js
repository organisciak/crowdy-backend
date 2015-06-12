var mongoose = require('mongoose');

var teachingSetSchema = mongoose.Schema({
    type: String, //should be same as the HIT types
    tasks: [
        { 
            item: String, //Item id
            correct: String,
            valid: mixed
        }
        ]
});

// TODO this needs more thought how to create a general purpose validator
