var mongoose = require('mongoose');

var hitSchema = mongoose.Schema({
    name: String,
    condition: { 
        firstTask: String, // i.e. basic, training, fast
        laterTasks:String  // i.e. basic, feedback, training, fast
    },
    type: String, // e.g. Image tagging
    items: [Number],
    // The name of the model for items, e.g. 'pin'.
    // Should correspond to a mondel in models/{{itemModel}}.js
    itemModel: String,
    setsPerItem: Number,
    maxSetSize: Number,
    timer: { type: Number, default: null },
});

var Hit = mongoose.connection.model('Hit', hitSchema);

module.exports = Hit; 
