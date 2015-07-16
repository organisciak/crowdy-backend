var mongoose = require('mongoose');

var hitSchema = mongoose.Schema({
    name: String,
    condition: { 
        // i.e. basic, training, fast
        firstTask: String,
        // Note that 'feedback' is extra decoration on top of 
        // a task, so specifying this condition will pair it based on
        // the firstTask. If firstTask is 'fast', the feedback will be
        // paired with the fast design; otherwise, it is paired with
        // the basic design 
        laterTasks:String  // i.e. basic, feedback, training, fast
    },
    // Base payment
    payment: {type: Number, default: 0},
    // Bonus, in dollars
    bonus: {
        task:Number,
        // Nth array value corresponds to Nth task item. Last value will
        // repeat if there are more items (so a constant bonus would be
        // an array of length 1
        item:[{type: Number, default: 0}]
    },
    type: String, // e.g. Image tagging
    items: [Number],
    // The name of the model for items, e.g. 'pin'.
    // Should correspond to a mondel in models/{{itemModel}}.js
    itemModel: String,
    setsPerItem: Number,
    maxSetSize: Number,
    // Used for estimating how long the task will take
    // Not used for the 'fast' condition, because the timer
    // time is the best estimate
    itemTimeEstimate: Number,
    // Specifies the task-completion timer in 'fast' condition
    timer: { type: Number, default: null }
});

var Hit = mongoose.connection.model('Hit', hitSchema);

module.exports = Hit; 
