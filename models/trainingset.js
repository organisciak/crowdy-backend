var mongoose = require('mongoose');

// Define Model Schema
var trainingSetSchema = mongoose.Schema({
    hit_id:String, //My unique key for the HIT (Mongo HIT _id, not hitTypeID)
    tasks:[{
        //'type' is a reserved word, so when I want 'type'
        // to actually be in my schema, it needs to be defined
        // with { type: String }
        // i.e. image tagging, same as taskSet.tasks.type and hit.type 
        type: {type: String}, 
        item:{
            type: { type: String }, //e.g. 'pin'; should reference model
            id:Number
        },
        training:{
            contribution:{
                great:[String], //List of great contributions (i.e. great tags)
                good:[String],
                okay:[String],
                poor:[String]
            },
            annotation: {
                general: String, //Text to accompany the item in training
                great: String,
                good: String,
                okay: String,
                poor: String
            }
        }
    }]
});

// Create Model and Export

var TrainingSet = mongoose.connection.model('trainingset', trainingSetSchema);

module.exports = TrainingSet; 
