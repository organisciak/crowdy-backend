var mongoose = require('mongoose');

var hitSchema = mongoose.Schema({
    name: String,
    condition: { 
        firstTask: String, // i.e. basic, training, fast
        laterTasks:String  // i.e. basic, feedback, training, fast
    },
    type: String, // e.g. Image tagging
    items: [String],
    setsPerItem: Number,
    maxSetSize: Number,
    timer: { type: Number, default: null },
});

var Hit = mongoose.model('Hit', hitSchema);

module.exports = Hit; 
