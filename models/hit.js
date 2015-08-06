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
        task:{type:Number, default:0},
        // Nth array value corresponds to Nth task item. Last value will
        // repeat if there are more items (so a constant bonus would be
        // an array of length 1
        items:[{type: Number, default: 0}]
    },
    type: String, // e.g. Image tagging
    // The name of the model for items, e.g. 'pin'.
    // Should correspond to a model in models/{{itemModel}}.js
    itemModel: String,
    // The items to choose from. 
    // If facets.length !== 0, the items will be sampled from
    // a facet in facets[]
    items: [Number],
    // A subsample. E.g. a query, which for meta has a name, 
    facets: [{
        meta:mongoose.Schema.Types.Mixed,
        items: [Number],
    }],
    // An explanation of what kind of facet is used, if any.
    // Optional, because this information should be gleamed
    // from the hit.type. If type === 'Relevance judgments", we
    // know that the faceting is queries. For now, facetType
    // is meant as a human-friendly annotation.
    facetType: String,
    setsPerItem: Number,
    maxSetSize: Number,
    // Used for estimating how long the task will take
    // Not used for the 'fast' condition, because the timer
    // time is the best estimate
    itemTimeEstimate: Number,
    // Specifies the task-completion timer in 'fast' condition
    timer: { type: Number, default: null },
    // Workers to exclude
    exclude: {
        // Workers that have done any tasks with this tasktype before
        pastInTaskType: Boolean,
        // All past workers (NOT IMPLEMENTED)
        pastAll: Boolean,
        // Array of hit_ids to exclude (NOT IMPLEMENTED)
        pastInHits: [String],
        // Array of userids to exclude (NOT IMPLEMENTED)
        users: [String]
    }
});

var Hit = mongoose.connection.model('Hit', hitSchema);

module.exports = Hit; 
