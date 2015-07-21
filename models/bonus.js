// A simple log for noting bonuses paid

var mongoose = require('mongoose');

var bonusSchema = mongoose.Schema({
    _id: String, // AssignmentId
    date: Date,
    user: String, // WorkerId
    bonus: Number
});

var Bonus = mongoose.connection.model('Bonus', bonusSchema);

module.exports = Bonus; 
