var mongoose = require('mongoose');
// Define Model Schema
var trainingSetSchema = mongoose.Schema({
    _id: String,
    items: [Number],
    meta:mongoose.Schema.Types.Mixed,
    answers:[{
        item:Number,
        answer:mongoose.Schema.Types.Mixed
    }]
});
// Create Model and Export

var TrainingSet = mongoose.connection.model('trainingset', trainingSetSchema);

module.exports = TrainingSet; 
