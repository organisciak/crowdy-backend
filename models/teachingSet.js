var mongoose = require('mongoose');

var teachingSetSchema = mongoose.Schema({
    type: String, //should be same as the HIT types
    tasks: [
        { 
            item: String, //Item id
            correct: String,
            valid: mongoose.Schema.Types.Mixed
        }
        ]
});
// TODO this needs more thought how to create a general purpose validator

var TeachingSet = mongoose.connection.model('teachingset', teachingSetSchema);

module.exports = TeachingSet;
