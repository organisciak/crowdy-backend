// A simple log for noting bonuses paid

var mongoose = require('mongoose');

var bonusSchema = mongoose.Schema({
    date: Date,
    AssignmentId: String,
    User: String // WorkerId
});

var Bonus = mongoose.connection.model('Bonus', bonusSchema);

module.exports = Bonus; 
